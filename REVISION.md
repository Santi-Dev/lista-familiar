# Revisión de código — Lista Familiar

Backend NestJS + Prisma (`nodejs_space`) e iOS SwiftUI (`swift_space`). Revisado leyendo el código; no se pudo compilar ni ejecutar (sin Xcode, sin base de datos).

## Crítico / seguridad
1. **Secretos en el zip**: `nodejs_space/.env` (JWT_SECRET, DATABASE_URL) y `prisma/seed.ts` con contraseña de usuario fija. Excluidos del repo (`.env` ignorado, `.env.example` agregado). **Rota el JWT_SECRET y la contraseña de la BD** y cambia la del usuario seed.
2. **`jwt.strategy.ts`**: `secretOrKey: process.env.JWT_SECRET ?? 'fallback-secret'`. Si falta la variable, los tokens se firman/validan con un secreto público. Debe fallar al arrancar si no existe. Además `AuthModule` lee `process.env` al importar el módulo (antes de que `ConfigModule` cargue `.env`); usar `JwtModule.registerAsync` con `ConfigService`.
3. **Sin rate limiting** en `/api/signup` y `/api/auth/login` (fuerza bruta). Añadir `@nestjs/throttler`.
4. **Sin CORS/helmet configurados** en `main.ts` (`APP_ORIGIN` existe en `.env` pero no se usa). Swagger (`/api-docs`) queda público en producción.
5. **Códigos de invitación con `Math.random()`** (6 caracteres): predecibles y adivinables por fuerza bruta, y `join` no tiene límite de intentos ni expiración. Usar `crypto.randomInt` + throttling.

## Bugs / correctitud
6. **iOS no maneja 401** aunque `.project_instructions.md` lo exige ("On any 401: clear token → login"). `APIClient.send` solo lanza `APIError.http`; con un token vencido (7 días) el usuario ve errores genéricos hasta reiniciar la app. Limpiar token y poner `session.user = nil` en 401.
7. **`family-groups.service.ts` `create`**: el bucle de código único termina tras 10 intentos y usa el último código aunque exista → viola `@unique` y da 500. Además `join`/`create` comprueban "ya está en grupo" y luego actualizan sin transacción (condición de carrera).
8. **`leave`**: no es transaccional; al irse el último miembro se borra el grupo y sus listas en cascada sin confirmación. Dos miembros saliendo a la vez pueden dejar un grupo vacío huérfano.
9. **`items.service.ts getListItems`**: devuelve `createdBy: null` siempre en el resumen de la lista (no hace `include`), inconsistente con el DTO.
10. **`lists.service.ts getLists`**: N+1 (un `count` por lista). Resolver con `groupBy` o `_count` con filtro.
11. **`UpdateItemDto.quantity`** sin `@MaxLength(30)` (en create sí). Se puede guardar texto arbitrariamente largo.
12. **`@Param('id')` sin `ParseUUIDPipe`**: un id inválido llega a Prisma y devuelve 500 en vez de 400/404.
13. **`schema.prisma`**: `output` apunta a `/home/ubuntu/...` (ruta del entorno de Abacus). Rompe `prisma generate` en cualquier otra máquina; eliminar la línea. `binaryTargets` también es específico (musl-arm64).
14. `auth.service.ts`: la comprobación de email existente y el `create` no son atómicas; capturar el error P2002 de Prisma en lugar de solo el `findUnique` previo.
15. `app.controller.spec.ts` y `test/app.e2e-spec.ts` son del esqueleto de Nest; `AppController`/`AppService` no están registrados en `AppModule`, así que esos tests probablemente fallan. No hay tests reales de la lógica.

## iOS (Swift)
16. **Polling cada 3 s/5 s** con `Task.sleep`: cada ciclo recarga todo y sobreescribe el estado local; un toggle optimista o una edición en curso puede "parpadear". Considerar ETag/`updatedAt` desde el servidor o SSE/WebSocket.
17. `ListDetailView.deleteItem/toggleArchive/doRename/doDelete` usan `try?` y tragan errores sin avisar al usuario; `doDelete` hace `dismiss()` aunque falle.
18. `showToast` usa `DispatchQueue.asyncAfter` sin cancelar: dos toasts seguidos se pisan.
19. `loadItems` hace `dismiss()` ante 403/404 durante el polling: un fallo transitorio de permisos expulsa al usuario de la pantalla.
20. `project.yml`/`Config.xcconfig`: `API_BASE_URL` apunta a un preview de abacusai.app (efímero) y el bundle id es `com.abacusai.…`. Cambiar a tu dominio/bundle antes de publicar. `KeychainHelper` usa service `ai.abacus.app.auth`.
21. `Sources/API/Generated/*` se regenera desde `swagger.json`; no editar a mano (el 401 de arriba debe ir en `APIClient`, que también está en ese directorio → moverlo fuera de `Generated` o parchear el generador).
22. `AppConfig` conserva un comentario sobre SwiftData que no aplica.

## Prioridad sugerida
1. Rotar secretos (1) y arreglar fallback JWT (2).
2. Manejo de 401 en iOS (6).
3. Throttling + CSPRNG para códigos (3, 5).
4. Quitar `output` de Prisma (13) para poder compilar en otras máquinas.
5. Transacciones/unicidad en grupos (7, 8, 14).

---
## Estado de correcciones (rama `fix/prioridad-alta`)
Corregidos: 1 (seed lee `SEED_PASSWORD`; `.env` fuera del repo), 2 (`JWT_SECRET` obligatorio vía `ConfigService.getOrThrow`, sin fallback), 3 (`@nestjs/throttler`: signup 5/min, login 10/min, join 10/min, 120/min global), 4 (CORS restringido a `APP_ORIGIN`; Swagger solo si `NODE_ENV != production`), 5 (`crypto.randomInt`), 6 (401 con token → borra token y vuelve al login), 7, 8, 14 (unión/creación/salida de grupo atómicas, reintento ante P2002), 11, 12 (`ParseUUIDPipe`), 13 (sin `output`/`binaryTargets` de Abacus).
Verificación: `prisma generate` y `tsc --noEmit` pasan. **No verificado**: ejecución contra una base real, y el cambio de Swift (no hay compilador Swift en este entorno).
Pendiente: 9, 10, 15–22. Tras desplegar, rotar JWT_SECRET y la contraseña de la BD, y definir `SEED_PASSWORD` si usas el seed.
