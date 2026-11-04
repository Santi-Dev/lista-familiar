# Tests

## Snapshots de pantallas (`swift_space/Tests`)
`ScreenSnapshotTests` renderiza cada pantalla en **claro y oscuro** con los datos de `PreviewBackend` (sin red) y
compara con las imágenes de referencia de `Tests/__Snapshots__`, usando
[swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).

Incluye casos de regresión con **nombres largos** (grupo y lista) en un iPhone SE, para detectar títulos cortados.

### Cómo se ejecutan (sin Mac)
Workflow `snapshots` (GitHub Actions, `macos-26`):
- Se lanza solo en cada push o PR que toque `swift_space/`.
- **Si no hay referencias** (o se lanza a mano con `record = true`), graba las imágenes y las sube a la rama con un commit
  del bot. Revisa esas imágenes: son la nueva "verdad" visual.
- **En cualquier otro caso** compara. Si hay diferencias, el job falla y el artefacto `snapshots` trae las imágenes de fallo.

### Cuando cambias la UI a propósito
1. Haz el cambio y súbelo.
2. Actions → `snapshots` → Run workflow → `record = true` (sobre tu rama).
3. Revisa el commit del bot (las imágenes nuevas) y confirma que son lo esperado.

### Escribir un test nuevo
Añade un método en `ScreenSnapshotTests` que llame a `assertScreen(MiVista(), config: iPhone)`.
Los ViewModels leen `APIClient.shared`, que los tests sustituyen por `PreviewBackend` (se puede configurar,
por ejemplo `PreviewBackend(groupName: "…")`).

### Cómo se captura
Cada pantalla se muestra en una `UIWindow` real, se espera a que terminen las cargas (`.task`) hasta que la imagen sea estable y se captura con
`drawHierarchy`, así que el **Liquid Glass se renderiza de verdad**. Las pantallas de título largo se prueban con un
ancho de 375 pt (el iPhone más estrecho soportado).

### Limitaciones
- La comparación admite un 2 % de diferencia (`precision` 0.98) para tolerar cambios de renderizado entre imágenes del runner.
- Si cambia la versión de Xcode o del simulador del runner, puede que haya que regenerar las referencias.

### Regenerar todas las referencias
Si prefieres no usar el botón, borra `swift_space/Tests/__Snapshots__` y sube el cambio: sin referencias, el workflow las vuelve a grabar.
