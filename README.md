# Lista Familiar

App iOS de listas de la compra compartidas para una familia. Todos los miembros de un grupo ven y editan
las mismas listas en tiempo real.

- **iOS 18+**, SwiftUI, arquitectura **MVVM** (`@Observable`)
- **Supabase** como backend: Auth, Postgres con RLS y Realtime. No hay servidor propio
- Todos los textos de la interfaz están en **español**
- Se desarrolla sin Mac: GitHub Actions compila, captura pantallas y sube a TestFlight

## Estructura del repositorio

```
.
├── swift_space/              App iOS (proyecto generado con XcodeGen)
│   ├── project.yml           Definición del proyecto, dependencias y versión
│   ├── Assets.xcassets
│   └── Sources/
│       ├── App/              Punto de entrada, RootView, configuración
│       ├── Core/             Código compartido por todas las pantallas
│       │   ├── Data/         Backend (protocolo) y SupabaseBackend
│       │   ├── Models/       DTOs y tipos de dominio
│       │   ├── Session/      SessionModel (usuario autenticado)
│       │   ├── DesignSystem/ Theme y componentes reutilizables
│       │   └── Support/      Utilidades (formato de fechas, mensajes de error)
│       ├── Features/         Una carpeta por pantalla: View + ViewModel
│       │   ├── Auth/  FamilyGroup/  Lists/  ListDetail/  Settings/  Main/
│       └── Preview/          Modo de capturas para CI (datos de ejemplo)
├── supabase/migrations/      Esquema SQL, RLS, funciones RPC y Realtime
├── scripts/preview.sh        Lanza el CI y descarga las capturas
├── .github/workflows/        ios-preview.yml, testflight.yml
├── mock/index.html           Maqueta HTML de referencia
└── docs/                     ARCHITECTURE.md, TESTFLIGHT.md, UX_DESIGN.md
```

## Arquitectura (MVVM)

```
 View (SwiftUI)  ──acciones──▶  ViewModel (@Observable)  ──▶  Backend (protocolo)  ──▶  Supabase
      ▲                               │                              ▲
      └────────── estado observado ───┘                    SupabaseBackend / PreviewBackend
```

| Capa | Responsabilidad | Reglas |
|---|---|---|
| **View** | Dibujar el estado y reenviar acciones del usuario | Sin llamadas de red ni lógica de negocio. Solo estado de presentación (hojas, diálogos, navegación) |
| **ViewModel** | Estado de la pantalla, validación y casos de uso | `@Observable @MainActor final class`. No importa SwiftUI. Recibe el `Backend` por inicializador |
| **Backend** | Contrato de acceso a datos (`Core/Data/Backend.swift`) | Dos implementaciones: `SupabaseBackend` y `PreviewBackend` |
| **Model** | DTOs (`Core/Models`) | Structs `Codable` sin lógica de UI |

Detalles y ejemplos en [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Flujo de la app

`RootView` decide la pantalla según `SessionModel`:
`SplashView` → `AuthFlowView` (login / registro) → `FamilyGroupSetupView` → `MainTabView` (Listas, Ajustes).

## Backend: Supabase

- **Auth**: registro e inicio de sesión por correo y contraseña. La sesión se guarda en el Keychain.
- **Base de datos**: `profiles`, `family_groups`, `shopping_lists`, `list_items`
  (ver [supabase/migrations/001_init.sql](supabase/migrations/001_init.sql)).
- **Seguridad (RLS)**: cada usuario solo accede a los datos de su grupo familiar. Crear grupo, unirse con código y
  salir se hacen con funciones RPC (`create_family_group`, `join_family_group`, `leave_family_group`).
- **Realtime**: las pantallas de listas y detalle se actualizan al instante, con un refresco de respaldo cada 30 s.
- La URL del proyecto y la clave `anon` están en `Sources/App/AppConfig.swift`. Son públicas por diseño. **Nunca**
  pongas la clave `service_role` en la app ni en el repositorio.

### Preparar un proyecto Supabase nuevo
1. Crea el proyecto en supabase.com.
2. Authentication → Providers → Email: desactiva *Confirm email* (o gestiona la confirmación en la app).
3. SQL Editor: ejecuta el contenido de `supabase/migrations/001_init.sql`.
4. Actualiza `AppConfig.swift` con la *Project URL* y la clave `anon`.

Los cambios de esquema van en un archivo nuevo `supabase/migrations/00N_descripcion.sql`, nunca editando los anteriores.

## Desarrollo sin Mac

El proyecto Xcode se genera con XcodeGen y se compila en un runner macOS de GitHub Actions.

```bash
bash scripts/preview.sh              # todas las pantallas
bash scripts/preview.sh lists detail # solo algunas
```

El script sube la rama, lanza `ios-preview`, espera y descarga los PNG (claro y oscuro) en
`previews/run-<id>/ios-preview/`. Si la compilación falla, deja `errors.txt`.

Pantallas disponibles: `welcome login register family-setup lists detail settings create-list item-form`.
Se renderizan con `PreviewBackend` (datos de ejemplo, sin red) mediante el argumento `-PREVIEW_SCREEN <nombre>`.
Al añadir una pantalla nueva, regístrala en `Preview/PreviewMode.swift` y en el workflow.

## Publicar en TestFlight

Workflow `testflight.yml` (manual). Requiere cuenta de Apple Developer y 4 secrets de GitHub.
Pasos completos en [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).

## Convenciones

- Una pantalla nueva = `Features/<Nombre>/<Nombre>View.swift` + `<Nombre>ViewModel.swift`.
- Los ViewModels dependen del protocolo `Backend`, nunca de `SupabaseClient` ni de `URLSession`.
- Colores, espaciados y radios salen de `Theme`; los colores se adaptan solos al modo oscuro.
- Textos de interfaz en español. Los nombres de código en inglés.
- Cambios de UI: actualizar `mock/index.html`, correr `scripts/preview.sh` y revisar las capturas.
- No lanzar builds por cambios que solo tocan el mock o archivos `.md`.
