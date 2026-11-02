# API Spec — NestJS, base path /api

## Conventions
- Auth uses `Authorization: Bearer <jwt>` (JWT, 7-day expiry, payload `{sub: userId}`). Passwords are hashed with bcrypt.
- JSON field names use camelCase. Timestamps are ISO8601.
- Errors: `{statusCode: integer, message: string, code: string}`. `message` is in Spanish and `code` is a stable value the client maps.
- **Category enum** (`ItemCategory`): `FRUTAS_VERDURAS | LACTEOS_HUEVOS | CARNES_PESCADO | PANADERIA | LIMPIEZA | BEBIDAS | DESPENSA | OTROS`. The client maps these to the labels "Frutas y Verduras", "Lácteos y Huevos", "Carnes y Pescado", "Panadería", "Limpieza", "Bebidas", "Despensa", "Otros".
- **Group access rule**: for every `/api/lists*` and `/api/items*` endpoint, the requester must have a non-null `familyGroupId`, otherwise return 403 `NO_FAMILY_GROUP`. The target list's `familyGroupId` must equal the requester's, otherwise return 404 `NOT_FOUND`.

## Shared shapes
- `UserPublic`: `{id: UUID, name: string}`
- `AuthUser`: `{id: UUID, email: string, name: string, familyGroupId: UUID | null}`
- `FamilyGroup`: `{id: UUID, name: string, inviteCode: string, createdById: UUID | null, members: UserPublic[], createdAt: ISO8601}`
  - `members` are sorted by name.
- `ShoppingListSummary`: `{id: UUID, name: string, isArchived: boolean, createdBy: UserPublic | null, itemCount: integer, purchasedCount: integer, createdAt: ISO8601, updatedAt: ISO8601}`
  - `itemCount` and `purchasedCount` are computed via a Prisma `_count` query.
  - The list's `updatedAt` is bumped on any item create, update or delete.
- `ListItem`: `{id: UUID, shoppingListId: UUID, name: string, quantity: string | null, category: ItemCategory, isPurchased: boolean, purchasedBy: UserPublic | null, purchasedAt: ISO8601 | null, addedBy: UserPublic | null, createdAt: ISO8601, updatedAt: ISO8601}`

## Auth (predetermined)
| Method | Path | Request Body | Response Body | Auth |
|---|---|---|---|---|
| POST | /api/signup | {email: email (required), password: string (required, min 8), name: string (required, 1-60)} | {token: string, user: AuthUser} | No |
| POST | /api/auth/login | {email: email (required), password: string (required)} | {token: string, user: AuthUser} | No |
| GET | /api/auth/me | — | {user: AuthUser} | Bearer |

- Signup:
  - Email is lowercased and trimmed.
  - 409 `EMAIL_TAKEN` "Este correo ya está registrado".
  - The user is created with `familyGroupId = null`; the client then shows group setup.
- Login: 401 `INVALID_CREDENTIALS` "Correo o contraseña incorrectos".
- `AuthUser` extends the predetermined user shape with `familyGroupId`.

## Family groups
| Method | Path | Request Body | Response Body | Auth |
|---|---|---|---|---|
| POST | /api/family-groups | {name: string (required, 1-60)} | FamilyGroup | Yes |
| POST | /api/family-groups/join | {inviteCode: string (required, 6 chars)} | FamilyGroup | Yes |
| GET | /api/family-groups/me | — | FamilyGroup | Yes |
| POST | /api/family-groups/leave | — | {success: boolean} | Yes |

- **Create**:
  - 409 `ALREADY_IN_GROUP` if the requester already has a group.
  - Generates a unique 6-character uppercase code from the alphabet `ABCDEFGHJKLMNPQRSTUVWXYZ23456789`, retrying on collision.
  - Sets `createdById` to the requester and sets the requester's `familyGroupId` to the new group, in one transaction.
- **Join**:
  - The code is trimmed and uppercased before lookup.
  - 404 `INVALID_CODE` "Código no válido".
  - 409 `ALREADY_IN_GROUP` if the requester already has a group.
  - Sets the requester's `familyGroupId`.
- **Me**: 403 `NO_FAMILY_GROUP` if the requester has no group.
- **Leave**:
  - 403 `NO_FAMILY_GROUP` if the requester has no group.
  - Sets the requester's `familyGroupId = null`.
  - If no members remain, deletes the group, which cascades to its lists and items.

## Shopping lists
| Method | Path | Request Body | Response Body | Auth |
|---|---|---|---|---|
| GET | /api/lists | query: ?archived=boolean (default false) | {items: ShoppingListSummary[]} | Yes |
| POST | /api/lists | {name: string (required, 1-80)} | ShoppingListSummary | Yes |
| PATCH | /api/lists/:id | {name: string (optional, 1-80), isArchived: boolean (optional)} | ShoppingListSummary | Yes |
| DELETE | /api/lists/:id | — | {success: boolean} | Yes |

- GET returns the requester's group lists filtered by `isArchived`, ordered by `updatedAt` desc. It is polled every 5 s by ListsHomeView.
- POST sets `familyGroupId` from the requester and `createdById` to the requester.
- DELETE cascades to the list's items.

## Items
| Method | Path | Request Body | Response Body | Auth |
|---|---|---|---|---|
| GET | /api/lists/:id/items | — | {list: ShoppingListSummary, items: ListItem[]} | Yes |
| POST | /api/lists/:id/items | {name: string (required, 1-80), quantity: string (optional, max 30), category: ItemCategory (required)} | ListItem | Yes |
| PATCH | /api/items/:id | {name: string (optional), quantity: string \| null (optional), category: ItemCategory (optional), isPurchased: boolean (optional)} | ListItem | Yes |
| DELETE | /api/items/:id | — | {success: boolean} | Yes |

- GET:
  - Items are ordered by category enum order, then `isPurchased` asc, then `createdAt` asc.
  - Polled every 3 s by ListDetailView.
  - 404 if the list was deleted, or is not in the requester's group.
- POST:
  - `addedById` is set to the requester and `isPurchased` defaults to false.
  - An empty-string quantity is stored as null.
- PATCH `isPurchased`:
  - true → set `purchasedById` to the requester and `purchasedAt` to now.
  - false → set both to null.
- PATCH, DELETE and POST all bump the parent list's `updatedAt`.
- For `/api/items/:id`, access is checked through `item.shoppingList.familyGroupId`.

## Client APIClient notes
- On 401: clear the token and set the session user to nil.
- On 403 `NO_FAMILY_GROUP`: call `session.refreshMe()`.
- Polling uses `Task` loops cancelled in `.onDisappear` and when the scenePhase is not active.
- Items with a pending mutation keep their optimistic local value until the mutation response arrives.