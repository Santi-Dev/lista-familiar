# Generated API client reference

All methods live on `APIClient.shared` (Sources/API/Generated — regenerated from the
backend; NEVER edit generated files by hand). Auth: `APIClient.shared.authToken = token`
after login (persisted in the Keychain); requests attach `Authorization: Bearer` automatically.

| Method | HTTP | Path | Returns |
|---|---|---|---|
| `login` | `POST` | `/api/auth/login` | `AuthResponseDto` |
| `me` | `GET` | `/api/auth/me` | `MeResponseDto` |
| `create` | `POST` | `/api/family-groups` | `FamilyGroupDto` |
| `join` | `POST` | `/api/family-groups/join` | `FamilyGroupDto` |
| `leave` | `POST` | `/api/family-groups/leave` | `SuccessDto` |
| `me` | `GET` | `/api/family-groups/me` | `FamilyGroupDto` |
| `updateItem` | `PATCH` | `/api/items/{id}` | `ListItemDto` |
| `deleteItem` | `DELETE` | `/api/items/{id}` | `SuccessDto` |
| `getLists` | `GET` | `/api/lists` | `ListsResponseDto` |
| `create` | `POST` | `/api/lists` | `ShoppingListSummaryDto` |
| `update` | `PATCH` | `/api/lists/{id}` | `ShoppingListSummaryDto` |
| `delete` | `DELETE` | `/api/lists/{id}` | `SuccessResponseDto` |
| `getListItems` | `GET` | `/api/lists/{id}/items` | `ListItemsResponseDto` |
| `createItem` | `POST` | `/api/lists/{id}/items` | `ListItemDto` |
| `signup` | `POST` | `/api/signup` | `AuthResponseDto` |

## Models

- `AuthResponseDto`
- `AuthUserDto`
- `CreateGroupDto`
- `CreateItemDto`
- `CreateListDto`
- `FamilyGroupDto`
- `JoinGroupDto`
- `ListItemDto`
- `ListItemsResponseDto`
- `ListsResponseDto`
- `LoginDto`
- `MeResponseDto`
- `ShoppingListSummaryDto`
- `SignupDto`
- `SuccessDto`
- `SuccessResponseDto`
- `UpdateItemDto`
- `UpdateListDto`
- `UserPublicDto`
