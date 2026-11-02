# Arquitectura MVVM

## Principios
1. La **View** solo dibuja y reenvía acciones. No llama al backend.
2. El **ViewModel** concentra el estado y la lógica de una pantalla. Es testeable sin SwiftUI.
3. El acceso a datos pasa siempre por el protocolo **`Backend`**. Así se puede sustituir (`PreviewBackend`, mocks de test).
4. La sesión (`SessionModel`) es el único estado global y llega por `@Environment`.

## Anatomía de una pantalla

```swift
// Features/Foo/FooViewModel.swift
@Observable @MainActor
final class FooViewModel {
    private(set) var items: [ItemDto] = []   // estado de solo lectura para la vista
    private(set) var isLoading = true
    var query = ""                           // estado editable (la vista lo enlaza con $vm.query)

    private let backend: any Backend
    init(backend: any Backend = APIClient.shared) { self.backend = backend }

    func load() async { /* llama a backend, actualiza estado */ }
}

// Features/Foo/FooView.swift
struct FooView: View {
    @State private var vm = FooViewModel()
    var body: some View {
        List(vm.items) { Text($0.name) }
            .task { await vm.load() }
    }
}
```

- Estado que modifica la vista → `var`. Estado que solo cambia el ViewModel → `private(set) var`.
- Estado puramente visual (hoja abierta, diálogo, ruta de navegación) puede vivir en la View con `@State`.
- Si el ViewModel necesita datos de la sesión, la View se los pasa como parámetro del método
  (por ejemplo `vm.submit(session: session)`), para no acoplar el ViewModel al entorno de SwiftUI.
- Las acciones asíncronas se lanzan desde la vista con `Task { await vm.accion() }` o `.task`.
- Los errores se traducen a texto para el usuario en el ViewModel (`userMessage(for:)`).

## Capa de datos

```
Backend (protocolo)
├── SupabaseBackend   Auth + PostgREST (RLS) + RPC + Realtime
└── PreviewBackend    Datos de ejemplo para capturas de CI
```

`APIClient.shared` devuelve el backend activo: `PreviewBackend` si la app se lanzó con `-PREVIEW_SCREEN`,
`SupabaseBackend` en cualquier otro caso.

Los DTOs (`Core/Models/Models.swift`) mantienen el formato que usa la interfaz. `SupabaseBackend` traduce
las filas de Postgres (snake_case, relaciones embebidas) a esos DTOs.

### Tiempo real
`Backend.changes(tables:)` devuelve un `AsyncStream<Void>` que emite cuando cambia alguna tabla.
Los ViewModels de listas y detalle lo observan y recargan. Además hacen un refresco cada 30 s por si se cae la conexión.

## Seguridad
- La app solo conoce la clave pública `anon`. El control de acceso real está en las políticas RLS
  de `supabase/migrations/001_init.sql`.
- Las operaciones que cambian la pertenencia a un grupo (crear, unirse, salir) son funciones `security definer`
  que validan el estado antes de escribir; no hay `insert`/`update` directo sobre `family_groups` ni sobre
  `profiles.family_group_id`.

## Cómo añadir una pantalla
1. Crea `Features/<Nombre>/` con `<Nombre>View.swift` y `<Nombre>ViewModel.swift`.
2. Si necesita datos nuevos: añade el método a `Backend`, impleméntalo en `SupabaseBackend` y en `PreviewBackend`.
   Si hace falta una tabla, columna o regla, crea una migración nueva en `supabase/migrations/`.
3. Regístrala en `Preview/PreviewMode.swift` y en la lista de pantallas de `.github/workflows/ios-preview.yml`.
4. Refleja el diseño en `mock/index.html` y verifica con `bash scripts/preview.sh <pantalla>`.

## Pruebas (pendiente)
Los ViewModels reciben el `Backend` por inicializador, por lo que se pueden probar con un backend falso sin red.
Aún no hay target de tests; el siguiente paso natural es añadir un `FamilyShoppingListsTests` con un
`FakeBackend` y pruebas de `ListDetailViewModel` (agrupación por categoría) y `FamilyGroupSetupViewModel`.
