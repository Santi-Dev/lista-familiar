# Lista Familiar

App iOS de listas de la compra compartidas para una familia. Todos los miembros de un grupo ven y editan
las mismas listas en tiempo real.

- **iOS 18+**, solo **SwiftUI** (sin UIKit en la app), Swift 6 con concurrencia estricta
- Arquitectura **SwiftUI nativa**: stores `@Observable` compartidos por el entorno, sin un ViewModel por pantalla
- **Supabase** como backend: Auth, Postgres con RLS y Realtime. No hay servidor propio
- Todos los textos de la interfaz están en **español**
- Proyecto Xcode nativo (`ios/ListaFamiliar.xcodeproj`): se abre directamente, sin generadores

## Estructura del repositorio

```
.
├── ios/
│   ├── ListaFamiliar.xcodeproj   Proyecto Xcode (carpetas sincronizadas: los archivos nuevos entran solos)
│   ├── ListaFamiliar/            App
│   │   ├── App/                  Punto de entrada, RootView, AppModel (composición), modo de arranque
│   │   ├── Models/               Modelos de dominio (UUID, Date, enums) y reglas de formularios
│   │   ├── Data/                 Backend (protocolo), SupabaseBackend, InMemoryBackend y datos de ejemplo
│   │   ├── Stores/               SessionStore, GroupStore, ListsStore (@Observable @MainActor)
│   │   ├── DesignSystem/         Theme, superficies Liquid Glass, estilos de botón, componentes
│   │   ├── Features/             Una carpeta por área: Auth, FamilyGroup, Lists, ListDetail, Settings, Main
│   │   ├── Preview/              Pantallas sueltas para capturas y entorno de los #Preview
│   │   └── Resources/            Assets (icono y colores claro/oscuro) y manifiesto de privacidad
│   ├── ListaFamiliarTests/       Swift Testing (modelos y stores) + snapshots de pantallas (XCTest)
│   └── Snapshots/                Imágenes de referencia de los snapshots (las graba el CI)
├── supabase/migrations/          Esquema SQL, RLS, funciones RPC y Realtime
├── scripts/preview.sh            Lanza el CI y descarga las capturas
├── .github/workflows/            ios-preview, snapshots, testflight, build-ipa, backend-tests, pages
├── mock/index.html               Maqueta HTML de referencia
└── docs/                         ARCHITECTURE.md, TESTS.md, TESTFLIGHT.md, APPSTORE.md
```

## Arquitectura

```
 View (SwiftUI) ──acciones──▶ Store (@Observable, en el Environment) ──▶ Backend (protocolo) ──▶ Supabase
      ▲                              │                                       ▲
      └──────── estado observado ────┘                       SupabaseBackend / InMemoryBackend
```

| Capa | Responsabilidad | Reglas |
|---|---|---|
| **View** | Dibujar el estado, estado local del formulario y navegación | Lee los stores con `@Environment(XStore.self)`. Nunca toca el backend |
| **Store** | Estado compartido y casos de uso (sesión, grupo, listas) | `@Observable @MainActor final class`. Cambios optimistas con vuelta atrás si el servidor falla |
| **Backend** | Contrato de datos (`Data/Backend.swift`) | `SupabaseBackend` (real) e `InMemoryBackend` (previews, capturas, demo y tests). Solo lanza `AppError` |
| **Model** | Tipos de dominio (`Models/`) | Structs `Sendable` con `UUID`/`Date`; las filas de Postgres se traducen en `Data/SupabaseRows.swift` |

Detalles y ejemplos en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Flujo de la app

`RootView` decide la pantalla según `SessionStore.phase`:
`SplashView` → `AuthFlowView` (bienvenida, iniciar sesión, crear cuenta) → `FamilyGroupSetupView` → `MainTabView` (Listas, Ajustes).

## Desarrollo en Mac

1. Abre `ios/ListaFamiliar.xcodeproj` en Xcode 26 o posterior.
2. Elige el esquema **ListaFamiliar** y un simulador, y ejecuta (⌘R).
3. Para dispositivo real, elige tu equipo en *Signing & Capabilities*.

Argumentos de arranque útiles (Product → Scheme → Edit Scheme → Arguments, ya creados y desactivados):
- `-DEMO`: la app completa con datos de ejemplo en memoria, sin red (cuenta `lucia@example.com` / `contraseña123`).
- `-PREVIEW_SCREEN <nombre>`: muestra una pantalla suelta con datos de ejemplo.

Cada vista tiene `#Preview` con datos de ejemplo (`.previewEnvironment()`).

Tests: ⌘U, o `xcodebuild test -project ios/ListaFamiliar.xcodeproj -scheme ListaFamiliar -destination 'platform=iOS Simulator,name=iPhone 17'`.
Ver [docs/TESTS.md](docs/TESTS.md).

## Backend: Supabase

- **Auth**: registro e inicio de sesión por correo y contraseña. La sesión se guarda en el llavero.
- **Base de datos**: `profiles`, `family_groups`, `shopping_lists`, `list_items`
  (ver [supabase/migrations/001_init.sql](supabase/migrations/001_init.sql)).
- **Seguridad (RLS)**: cada usuario solo accede a los datos de su grupo familiar. Crear grupo, unirse con código y
  salir se hacen con funciones RPC (`create_family_group`, `join_family_group`, `leave_family_group`).
- **Realtime**: una única suscripción (en `MainTabView`) mantiene al día listas y detalle, con un refresco de respaldo cada 30 s
  y al volver a la app.
- La URL del proyecto y la clave `anon` están en `ios/ListaFamiliar/App/AppConfig.swift`. Son públicas por diseño. **Nunca**
  pongas la clave `service_role` en la app ni en el repositorio.

### Preparar un proyecto Supabase nuevo
1. Crea el proyecto en supabase.com.
2. Authentication → Providers → Email: desactiva *Confirm email* (o gestiona la confirmación en la app).
3. SQL Editor: ejecuta las migraciones de `supabase/migrations/` en orden.
4. Actualiza `AppConfig.swift` con la *Project URL* y la clave `anon`.

Los cambios de esquema van en un archivo nuevo `supabase/migrations/00N_descripcion.sql`, nunca editando los anteriores.

## Capturas desde CI

```bash
bash scripts/preview.sh              # todas las pantallas
bash scripts/preview.sh lists detail # solo algunas
```

El script sube la rama, lanza `ios-preview`, espera y descarga los PNG (claro y oscuro) en
`previews/run-<id>/ios-preview/`. Si la compilación falla, deja `errors.txt`.

Pantallas disponibles: `welcome login register family-setup lists detail settings create-list item-form`.
Se renderizan con `InMemoryBackend` (datos de ejemplo, sin red) mediante `-PREVIEW_SCREEN <nombre>`.
Al añadir una pantalla nueva, regístrala en `Preview/PreviewScreen.swift` y en el workflow.

## Publicar en TestFlight

Workflow `testflight.yml` (manual). Requiere cuenta de Apple Developer y 4 secrets de GitHub.
Pasos completos en [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).

## Convenciones

- Una pantalla = `Features/<Área>/<Nombre>View.swift` (o `Sheet`). El estado local del formulario vive en la vista con `@State`;
  el estado compartido y las llamadas al backend, en los stores.
- Datos nuevos: método en `Backend` + `SupabaseBackend` + `InMemoryBackend`, y el caso de uso en el store que corresponda.
- Colores del catálogo de assets (`Color.brand`, `.highlight`, `.surface`…), espaciados y radios de `Theme`.
  La tipografía (Plus Jakarta Sans para titulares e Inter para el cuerpo, de `Resources/Fonts`) se registra al arrancar y se aplica una vez en la raíz.
- Textos de interfaz en español, en tono de «tú». Los nombres de código en inglés.
- Cambios de UI: actualizar `mock/index.html`, revisar los `#Preview` o las capturas del CI.
