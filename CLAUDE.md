# Lista Familiar — reglas de sesión

Ver `.project_instructions.md` (arquitectura, tema, textos en español).

## Verificación de UI (sin Mac)
- El Swift está en `swift_space/` (XcodeGen). Se compila y se capturan pantallas en GitHub Actions
  (`.github/workflows/ios-preview.yml`, runner macOS).
- `bash scripts/preview.sh [pantallas]` empuja la rama, lanza el workflow y baja los PNG a
  `previews/run-<id>/ios-preview/` (`<pantalla>-light.png`, `<pantalla>-dark.png`; `errors.txt` si falla).
- Pantallas: welcome login register family-setup lists detail settings create-list item-form.
- Las capturas usan `Sources/Preview/PreviewMode.swift` (arg `-PREVIEW_SCREEN`) con datos falsos; no toca el uso normal.
- Al añadir una pantalla nueva, registrarla en `PreviewMode.root` y en el workflow.

## Flujo para cambios de UI
1. Editar el Swift y reflejar el cambio en `mock/index.html`.
2. Commit, correr `scripts/preview.sh` (solo pantallas afectadas), revisar los PNG con Read.
3. Reportar en 3-5 líneas: compiló o no, qué cambió, qué difiere del mock.
- No lanzar builds por cambios que solo tocan el mock o archivos .md.
- Máximo 3 intentos ante fallos de CI antes de explicar el problema.
