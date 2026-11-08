# Lista Familiar — reglas de sesión

Lee `README.md` (visión general) y `docs/ARCHITECTURE.md` (SwiftUI nativa con stores) antes de tocar código.

## Proyecto
- App iOS 18+, solo **SwiftUI**, Swift 6. Proyecto Xcode nativo en `ios/ListaFamiliar.xcodeproj` (sin XcodeGen). Backend: **Supabase** (Auth, Postgres+RLS, Realtime). Sin servidor propio.
- **Todos los textos de la interfaz en español, en tono de «tú»** (cercano y personal: «tus compras», «añade», «invita a tu familia»; nunca «vosotros»: «haced», «vuestra», «necesitáis»). Código y nombres en inglés.
- Tema verde de supermercado (diseño de Stitch): marca #256A42, acento #D97706, tipografía Plus Jakarta Sans (titulares) e Inter (cuerpo), empaquetadas en `Resources/Fonts` y registradas por `FontRegistry`. Colores del catálogo de assets (`Color.brand`, `.highlight`, `.surface`…, con modo oscuro) y medidas de `Theme`.
- Categorías: FRUTAS_VERDURAS, LACTEOS_HUEVOS, CARNES_PESCADO, PANADERIA, LIMPIEZA, BEBIDAS, DESPENSA, OTROS.

## Reglas de arquitectura
- Sin ViewModels por pantalla: el estado compartido vive en los stores `@Observable @MainActor` (`SessionStore`, `GroupStore`,
  `ListsStore`), que llegan por `@Environment`. El estado local del formulario vive en la vista con `@State`.
- Las vistas nunca llaman al backend; los stores sí, a través del protocolo `Backend` (solo lanza `AppError`).
- Sin UIKit en la app (solo en los tests de snapshots).
- Datos nuevos: método en `Backend` + `SupabaseBackend` + `InMemoryBackend` + caso de uso en el store, con su test en `StoreTests`. Cambios de esquema: migración nueva en `supabase/migrations/`, nunca editar las anteriores.
- Nunca poner la clave `service_role` ni secretos (`.p8`) en el repo. La clave `anon` es pública y está en `AppConfig.swift`.

## Verificación de UI (sin Mac)
- Tests de snapshots: ver `docs/TESTS.md` (workflow `snapshots`).
- `bash scripts/preview.sh [pantallas]` empuja la rama, lanza `ios-preview` (runner macOS, build para simulador iOS) y baja los PNG a
  `previews/run-<id>/ios-preview/` (`<pantalla>-light.png`, `<pantalla>-dark.png`; `errors.txt` si falla).
- Pantallas: welcome login register family-setup lists detail settings create-list item-form.
- Las capturas usan `InMemoryBackend` con `SampleData` (`-PREVIEW_SCREEN`), sin red. No prueban la conexión real a Supabase.
- Al añadir una pantalla, registrarla en `Preview/PreviewScreen.swift`, en `ScreenSnapshotTests` y en el workflow.
- Si hay Mac: compilar y probar en local (`xcodebuild test … -scheme ListaFamiliar`). En un Mac Intel el simulador no dibuja Liquid Glass.

## Flujo para cambios de UI
1. Editar el Swift y reflejar el cambio en `mock/index.html`.
2. Commit, correr `scripts/preview.sh` (solo pantallas afectadas), revisar los PNG con Read.
3. Reportar en 3-5 líneas: compiló o no, qué cambió, qué difiere del mock.
- No lanzar builds por cambios que solo tocan el mock o archivos .md.
- Máximo 3 intentos ante fallos de CI antes de explicar el problema.

## App Store
Ver `docs/APPSTORE.md` (paquete de subida, ficha y estado de los requisitos).

## TestFlight
Ver `docs/TESTFLIGHT.md`. El workflow `testflight.yml` es manual y necesita 4 secrets de GitHub.
