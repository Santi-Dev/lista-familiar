# DB Schema — Prisma / PostgreSQL

## enum ItemCategory
`FRUTAS_VERDURAS, LACTEOS_HUEVOS, CARNES_PESCADO, PANADERIA, LIMPIEZA, BEBIDAS, DESPENSA, OTROS`

The declaration order defines the display order. The API sorts by this order (Prisma enum ordering follows declaration).

## User (predetermined + familyGroupId)
| Field | Type | Constraints |
|---|---|---|
| id | UUID | PK, default uuid() |
| email | String | Unique, required, stored lowercase |
| password | String | bcrypt hash |
| name | String | required |
| familyGroupId | UUID? | FK → FamilyGroup.id, ON DELETE SET NULL; index |
| createdAt | DateTime | default now() |
| updatedAt | DateTime | @updatedAt |

## FamilyGroup
| Field | Type | Constraints |
|---|---|---|
| id | UUID | PK, default uuid() |
| name | String | required |
| inviteCode | String | Unique, 6 chars uppercase |
| createdById | UUID? | FK → User.id, ON DELETE SET NULL (relation name "GroupCreator") |
| createdAt | DateTime | default now() |
| updatedAt | DateTime | @updatedAt |

Relations:
- `members User[]` (relation "GroupMembers" via `User.familyGroupId`)
- `lists ShoppingList[]`

## ShoppingList
| Field | Type | Constraints |
|---|---|---|
| id | UUID | PK, default uuid() |
| name | String | required |
| familyGroupId | UUID | FK → FamilyGroup.id, ON DELETE CASCADE |
| createdById | UUID? | FK → User.id, ON DELETE SET NULL |
| isArchived | Boolean | default false |
| createdAt | DateTime | default now() |
| updatedAt | DateTime | @updatedAt; also explicitly bumped on item changes |

- Index: (familyGroupId, isArchived, updatedAt).
- Relation: `items ListItem[]`.

## ListItem
| Field | Type | Constraints |
|---|---|---|
| id | UUID | PK, default uuid() |
| shoppingListId | UUID | FK → ShoppingList.id, ON DELETE CASCADE |
| name | String | required |
| quantity | String? | free text, e.g. "2 kg" |
| category | ItemCategory | default OTROS |
| isPurchased | Boolean | default false |
| purchasedById | UUID? | FK → User.id, ON DELETE SET NULL (relation "ItemPurchaser") |
| purchasedAt | DateTime? | set when purchased |
| addedById | UUID? | FK → User.id, ON DELETE SET NULL (relation "ItemAdder") |
| createdAt | DateTime | default now() |
| updatedAt | DateTime | @updatedAt |

- Index: (shoppingListId, category, isPurchased, createdAt).

## Relationships summary
- FamilyGroup 1—N User (members). A user belongs to 0 or 1 groups.
- FamilyGroup 1—N ShoppingList (cascade).
- ShoppingList 1—N ListItem (cascade).
- User 1—N ShoppingList (createdBy, set null).
- User 1—N ListItem (addedBy and purchasedBy, both set null).
- Deleting the last member's group (on leave) cascades to its lists and items.