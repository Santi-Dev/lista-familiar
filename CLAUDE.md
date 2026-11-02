# Lista Familiar — reglas de sesión

Lee `README.md` (visión general) y `docs/ARCHITECTURE.md` (MVVM) antes de tocar código.

## Proyecto
- App iOS 18+, SwiftUI, **MVVM** con `@Observable`. Backend: **Supabase** (Auth, Postgres+RLS, Realtime). Sin servidor propio.
- **Todos los textos de la interfaz en español.** Código y nombres en inglés.
- Tema verde de supermercado: marca #2E7D4F, acento #E07A2E, tipografía SF Pro Rounded. Usar siempre `Theme` (se adapta a modo oscuro).
- Categorías: FRUTAS_VERDURAS, LACTEOS_HUEVOS, CARNES_PESCADO, PANADERIA, LIMPIEZA, BEBIDAS, DESPENSA, OTROS.

## Reglas de arquitectura
- Una pantalla = `Features/<Nombre>/<Nombre>View.swift` + `<Nombre>ViewModel.swift`.
- Las Views no llaman al backend; los ViewModels (`@Observable @MainActor`) sí, a través del protocolo `Backend`.
- Datos nuevos: método en `Backend` + `SupabaseBackend` + `PreviewBackend`. Cambios de esquema: migración nueva en `supabase/migrations/`, nunca editar las anteriores.
- Nunca poner la clave `service_role` ni secretos (`.p8`) en el repo. La clave `anon` es pública y está en `AppConfig.swift`.

## Verificación de UI (sin Mac)
- `bash scripts/preview.sh [pantallas]` empuja la rama, lanza `ios-preview` (runner macOS, build para simulador iOS) y baja los PNG a
  `previews/run-<id>/ios-preview/` (`<pantalla>-light.png`, `<pantalla>-dark.png`; `errors.txt` si falla).
- Pantallas: welcome login register family-setup lists detail settings create-list item-form.
- Las capturas usan `PreviewBackend` (`-PREVIEW_SCREEN`), sin red. No prueban la conexión real a Supabase.
- Al añadir una pantalla, registrarla en `Preview/PreviewMode.swift` y en el workflow.

## Flujo para cambios de UI
1. Editar el Swift y reflejar el cambio en `mock/index.html`.
2. Commit, correr `scripts/preview.sh` (solo pantallas afectadas), revisar los PNG con Read.
3. Reportar en 3-5 líneas: compiló o no, qué cambió, qué difiere del mock.
- No lanzar builds por cambios que solo tocan el mock o archivos .md.
- Máximo 3 intentos ante fallos de CI antes de explicar el problema.

## TestFlight
Ver `docs/TESTFLIGHT.md`. El workflow `testflight.yml` es manual y necesita 4 secrets de GitHub.
