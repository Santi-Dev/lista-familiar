# Tests

Todo vive en el target `ListaFamiliarTests` de `ios/ListaFamiliar.xcodeproj`. En Xcode: ⌘U.

```bash
xcodebuild test -project ios/ListaFamiliar.xcodeproj -scheme ListaFamiliar \
  -destination 'platform=iOS Simulator,name=iPhone 17'
```

## Tests unitarios (Swift Testing)
- `ModelTests.swift`: código de invitación, borradores de artículo, agrupación por categoría, validación de credenciales
  y fechas de PostgREST.
- `StoreTests.swift`: `SessionStore`, `GroupStore` y `ListsStore` contra `InMemoryBackend` (sin red). Incluye la vuelta
  atrás de los cambios optimistas cuando el servidor falla (`backend.failNextCall(with:)`).

## Snapshots de pantallas (`ScreenSnapshotTests.swift`)
Renderiza cada pantalla de `PreviewScreen` en **claro y oscuro** con los datos de `SampleData` y compara con las
imágenes de `ios/Snapshots/`, usando [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing).
Incluye casos de regresión con **nombres largos** (grupo y lista) a 375 pt de ancho, para detectar títulos cortados.

### En CI
Workflow `snapshots` (GitHub Actions, `macos-26`), en cada push o PR que toque `ios/`:
- **Si no hay referencias** (o se lanza a mano con `record = true`), las graba y las sube a la rama con un commit
  del bot. Revisa esas imágenes: son la nueva "verdad" visual.
- **En cualquier otro caso** compara. Si hay diferencias, el job falla y el artefacto `snapshots` trae las imágenes de fallo.

### Cuando cambias la UI a propósito
1. Haz el cambio y súbelo.
2. Actions → `snapshots` → Run workflow → `record = true` (sobre tu rama).
3. Revisa el commit del bot (las imágenes nuevas) y confirma que son lo esperado.

### En local
- Con `SNAPSHOT_TESTING_RECORD=all` en el entorno del esquema de tests, se regraban todas las referencias.
- Las referencias oficiales son las del runner de CI (Mac con Apple Silicon). En un Mac Intel el simulador no dibuja
  Liquid Glass, así que las capturas locales no coinciden con las de CI: no subas referencias grabadas en un Mac Intel.

### Cómo se captura
Cada pantalla se muestra en una `UIWindow` real, se espera a que la imagen sea estable y se captura con `drawHierarchy`,
así que el Liquid Glass se renderiza de verdad. La comparación admite un 2 % de diferencia (`precision` 0.98).
Si cambia la versión de Xcode o del simulador del runner, puede que haya que regenerar las referencias.

### Escribir un test nuevo
Añade el caso a `PreviewScreen` y un método `func testX() async { await assertScreen(.x) }`.
Para datos distintos, pasa un backend: `assertScreen(.lists, backend: SampleData.backend(groupName: "…"))`.
