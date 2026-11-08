# Arquitectura (SwiftUI nativa)

## Principios
1. **Solo SwiftUI** en la app. UIKit solo aparece en los tests de snapshots (para capturar una ventana real).
2. **Los stores son la fuente de verdad.** `SessionStore`, `GroupStore` y `ListsStore` son `@Observable @MainActor`,
   se crean una vez en `AppModel` y llegan a las vistas por el entorno (`@Environment(ListsStore.self)`).
   «Mis listas» y el detalle comparten los mismos datos: marcar un artículo actualiza al momento el contador de la tarjeta.
3. **Las vistas no tienen ViewModel.** El estado local (texto de un campo, hoja abierta, diálogo, ruta) vive en la vista
   con `@State`. Las reglas que merece la pena probar están en tipos puros (`ItemDraft`, `InviteCode`, `Credentials`, `NameInput`).
4. **El acceso a datos pasa por el protocolo `Backend`**, que solo lanza `AppError`. Las vistas muestran `error.userMessage`.
5. **Swift 6 con concurrencia estricta.** Modelos `Sendable`, stores en el hilo principal y backends `Sendable`.

## Anatomía de una pantalla

```swift
// Features/Foo/FooView.swift
struct FooView: View {
    @Environment(ListsStore.self) private var lists   // estado compartido
    @State private var name = ""                       // estado local del formulario
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("Nombre", text: $name)
            FormErrorText(message: errorMessage)
            Button("Guardar") { save() }.disabled(!NameInput.isValid(name))
        }
        .task { await lists.load(archived: false) }
    }

    private func save() {
        Task {
            do { try await lists.rename(id, to: name) }
            catch { errorMessage = error.userMessage }
        }
    }
}

#Preview { FooView().previewEnvironment() }
```

- Las cargas se lanzan con `.task` / `.task(id:)`, que se cancelan solas al salir de la pantalla.
- Alertas y diálogos ligados a un opcional: `isPresented: $item.isPresent()` + `presenting: item`.
- Avisos breves: `@State var toast: String?` + `.toast($toast)`.
- Navegación por valor: `NavigationStack(path:)` con rutas `Hashable` (`AuthRoute`, `UUID` de lista).

## Stores

| Store | Estado | Notas |
|---|---|---|
| `SessionStore` | `phase`: `launching`, `unavailable`, `signedOut`, `signedIn(User)` | Sin conexión al abrir, muestra «Reintentar» en vez de cerrar la sesión |
| `GroupStore` | Grupo familiar y su `LoadState` | Crear, unirse con código y salir |
| `ListsStore` | Listas (activas y archivadas) y artículos por lista | Cambios optimistas: se aplican en local y se deshacen si el servidor falla |

`RootView` vacía `GroupStore` y `ListsStore` cuando cambia el usuario o su grupo.

## Capa de datos

```
Backend (protocolo, lanza AppError)
├── SupabaseBackend   Auth + PostgREST (RLS) + RPC + Realtime. Traduce filas (Data/SupabaseRows.swift) a modelos
└── InMemoryBackend   actor con datos de ejemplo (Data/SampleData.swift): previews, capturas, modo -DEMO y tests
```

`LaunchMode` decide el backend al arrancar: Supabase en uso normal, `InMemoryBackend` con `-DEMO`, con
`-PREVIEW_SCREEN <nombre>` o cuando la app es el anfitrión de los tests.

### Tiempo real
`Backend.changes()` devuelve un `AsyncStream<Void>` que emite cuando cambian `shopping_lists` o `list_items`.
`MainTabView` lo observa una sola vez y llama a `ListsStore.refresh()`, que recarga lo que ya estaba cargado.
Además refresca cada 30 s en primer plano y al volver a la app, por si se cae la conexión.

## Sistema de diseño
- Colores en `Resources/Assets.xcassets` con variante oscura; Xcode genera `Color.brand`, `.highlight`, `.appBackground`,
  `.surface`, `.textPrimary`, `.textSecondary` y `.hairline`.
- Tipografía: Plus Jakarta Sans (titulares) e Inter (cuerpo y etiquetas), empaquetadas en `Resources/Fonts` y registradas al
  arrancar con `FontRegistry` (sin tocar el Info.plist). `Font.displayLarge`, `.headlineSmall`, `.bodyMedium`, `.labelMedium`… en `Theme.swift`
  escalan con Dynamic Type. `appStyle()` fija Inter como fuente por defecto, el tinte de marca y el formato de fechas en español.
- Componentes comunes en `DesignSystem/`: avatares, iconos, etiquetas y barra de progreso (`Identity.swift`), campos con icono,
  contraseña con ojo y código en casillas (`Components.swift`, `Fields.swift`) y los colores por categoría, icono de lista y rol
  (`CategoryStyle.swift`).
- Liquid Glass en iOS 26+ (`brandSurface`, `neutralSurface`, `chipSurface`, `floatingSurface`) con alternativa sólida
  para iOS 18-25. Bajo el cristal tintado hay un relleno sólido para que el texto mantenga el contraste siempre.

## Roles de miembro
`OWNER` (crea el grupo), `ADMIN`, `EDITOR` (quien se une) y `VIEWER` (solo lectura). El rol vive en `profiles.role` y solo cambia con
la función `set_member_role` (el propietario no cambia; un administrador solo gestiona editores y lectores). Las políticas RLS impiden
escribir a los lectores y la app lo refleja con `GroupStore.role(of:)` y `MemberRole.canEdit`. Si se va el propietario, hereda el grupo
un administrador o, si no hay, quien lleva más tiempo (`leave_family_group`).

## Seguridad
- La app solo conoce la clave pública `anon`. El control de acceso real está en las políticas RLS de `supabase/migrations/`.
- Las operaciones que cambian la pertenencia a un grupo (crear, unirse, salir) son funciones `security definer`.
- `added_by_id`, `purchased_by_id`, `purchased_at` y `updated_at` los rellenan triggers de la base de datos.

## Cómo añadir una pantalla
1. Crea la vista en `Features/<Área>/` (Xcode la añade al target solo, por las carpetas sincronizadas) con su `#Preview`.
2. Si necesita datos nuevos: añade el método a `Backend`, impleméntalo en `SupabaseBackend` y en `InMemoryBackend`,
   y expón el caso de uso en el store. Si hace falta una tabla, columna o regla, crea una migración nueva.
3. Añade tests del store en `ListaFamiliarTests/StoreTests.swift`.
4. Regístrala en `Preview/PreviewScreen.swift`, en `ScreenSnapshotTests` y en `.github/workflows/ios-preview.yml`.
