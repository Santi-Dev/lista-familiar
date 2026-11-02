# Lista Familiar — UX Spec (iOS 18, SwiftUI)

> **Nota:** documento de diseño original (escrito para el backend NestJS). La arquitectura vigente (MVVM + Supabase) está en `README.md` y `docs/ARCHITECTURE.md`; donde difieran, mandan esos.

ALL user-facing strings are Spanish. Use the exact strings given in quotes below. Put them in `Sources/Localization/Strings.swift` as static constants; the dev language is `es`.

## Global state
- `SessionModel` (@Observable, injected via `.environment`), exposing:
  - `user: User?` with `id, email, name, familyGroupId: UUID?`
  - `isLoading`, `isAuthenticated`, `hasFamilyGroup` (computed: `user?.familyGroupId != nil`)
  - `login`, `signup`, `logout`, `refreshMe`, `setFamilyGroup(id: UUID?)`
- These methods only mutate state and never navigate.
- The JWT is stored in the Keychain.
- On any 401 response, the APIClient clears the token and sets `user = nil`.
- SwiftData is not used: all data is shared and server-backed. Only the token is persisted locally.

## Root switch (`Sources/Views/RootView.swift`)
```swift
if session.isLoading { SplashView() }
else if !session.isAuthenticated { AuthFlowView() }
else if !session.hasFamilyGroup { FamilyGroupSetupView() }
else { MainTabView() }
```

<screens>

### 1. SplashView
- Purpose: shown while the stored token is validated via `GET /api/auth/me`.
- UI: brand-green background, `cart.fill` symbol in a white rounded square, title "Lista Familiar", small ProgressView.
- No actions.

### 2. WelcomeView (root of AuthFlowView's NavigationStack)
- Layout, top to bottom:
  - Large illustration: a grid of SF Symbols in a soft circle (`carrot.fill`, `cart.fill`, `basket.fill`), tinted brand and accent.
  - Display title "Lista Familiar".
  - Body text "Haced la compra juntos. Una lista compartida para toda la familia, siempre al día."
- Buttons at the bottom:
  - Primary "Crear cuenta" → push RegisterView.
  - Secondary "Ya tengo cuenta · Iniciar sesión" → push LoginView.

### 3. RegisterView
- Title "Crear cuenta".
- Fields:
  - "Nombre" (textContentType .name)
  - "Correo electrónico" (.emailAddress, keyboard .emailAddress, no autocaps)
  - "Contraseña" (SecureField, .newPassword, hint "Mínimo 8 caracteres")
- Primary button "Registrarme".
  - Disabled until: name is non-empty, email contains @, and password is 8 or more characters.
  - Shows a spinner in the button while loading.
- Inline error banner below the fields:
  - 409 → "Este correo ya está registrado"
  - Network error → "No se pudo conectar. Inténtalo de nuevo."
- Link "¿Ya tienes cuenta? Inicia sesión" → push LoginView, replacing Register on the path.
- On success, `session.signup` sets the user. The user has `familyGroupId == nil`, so the root view switches to FamilyGroupSetupView.

### 4. LoginView
- Title "Iniciar sesión".
- Fields "Correo electrónico" and "Contraseña".
- Primary button "Entrar".
- Error messages:
  - 401 → "Correo o contraseña incorrectos"
- Link "¿No tienes cuenta? Regístrate" → push RegisterView.
- On success, the session updates and the root switches to:
  - MainTabView if the user has a group
  - FamilyGroupSetupView otherwise

### 5. FamilyGroupSetupView (own NavigationStack)
Shown whenever the user is authenticated but has no group.
- Header: "Hola, {nombre}" and subtitle "Para empezar, crea tu grupo familiar o únete al de tu familia."
- Segmented Picker: "Crear grupo" | "Unirme con código".
- **Crear grupo** mode:
  - Field "Nombre del grupo" (placeholder "Familia García").
  - Primary "Crear grupo" → `POST /api/family-groups`.
  - On success, show a success card in place:
    - "¡Grupo creado!"
    - The invite code in large monospaced digits (display size, letter-spaced), e.g. "K7Q2MX"
    - Buttons "Copiar código" (UIPasteboard; haptic success; toast "Código copiado") and ShareLink "Compartir código" with text "Únete a nuestra lista de la compra en Lista Familiar con el código: {code}"
    - Primary "Continuar" → calls `session.setFamilyGroup(id)`, and the root switches to MainTabView.
- **Unirme con código** mode:
  - Field "Código de invitación" with 6 characters, autocapitalization .characters, monospaced, auto-uppercased.
  - Primary "Unirme" → `POST /api/family-groups/join`.
  - Errors:
    - 404 → "Código no válido. Revisa e inténtalo de nuevo."
    - 409 → "Ya perteneces a un grupo"
  - On success → `session.setFamilyGroup(id)`, and the root switches.
- Toolbar trailing: "Cerrar sesión" → `session.logout()`.

### 6. MainTabView
TabView with two tabs, each with its own NavigationStack:
- "Listas" (`list.bullet.clipboard`) → ListsHomeView
- "Ajustes" (`gearshape`) → SettingsView

### 7. ListsHomeView
- Large title: the family group name (from `GET /api/family-groups/me`), with subtitle caption "{n} miembros".
- Segmented Picker: "Activas" | "Archivadas" (maps to `?archived=false|true`).
- List cards (LazyVStack). Each card shows:
  - List name (headline)
  - Progress text "{purchasedCount} de {itemCount} comprados"
  - Thin progress bar in brand green
  - Caption "Creada por {createdBy.name} · {fecha relativa de updatedAt}", using a RelativeDateTimeFormatter with locale es_ES
  - Tap → push ListDetailView(listId).
- Context menu / swipe actions on a card:
  - "Archivar" or "Desarchivar" (`PATCH isArchived`)
  - "Renombrar" (alert with text field)
  - "Eliminar" (destructive; confirmationDialog "¿Eliminar la lista '{name}'? Se borrarán todos sus artículos.")
- FAB: circular, 56pt, brand green, `plus`, bottom-right, active tab only. Opens the CreateListSheet.
- Polling: refreshes every 5 s while the view is visible and the scenePhase is `.active`. Also supports pull-to-refresh.
- Empty state (active tab):
  - Icon `cart.badge.plus`
  - "Aún no hay listas" and "Crea la primera, por ejemplo 'Mercado semanal'."
  - Button "Crear lista"
- Empty state (archived tab): "No hay listas archivadas".
- Loading: 3 skeleton cards (redacted).
- Error: "No se pudieron cargar las listas" with a "Reintentar" button.

### 8. CreateListSheet (sheet, own NavigationStack, .medium detent)
- Title "Nueva lista".
- Field "Nombre de la lista" with autofocus and placeholder "Mercado semanal".
- Toolbar: "Cancelar" and "Crear" (disabled when the name is empty).
- `POST /api/lists` → dismiss sheet → push the new list's ListDetailView. This is an event-driven push, so the parent appends the id to the path.

### 9. ListDetailView
- Navigation title: the list name.
- Toolbar menu `ellipsis.circle`, with:
  - "Renombrar lista"
  - "Archivar lista" / "Desarchivar lista"
  - "Eliminar lista" (destructive with confirmation; on success, pop)
- Header: progress "{comprados}/{total} comprados".
- Category filter row: horizontally scrolling chips.
  - First chip is "Todas", followed by the 8 categories with their icons.
  - Each chip shows a count badge of pending items.
  - The selected chip is filled brand green; filtering happens client-side.
- Body: a `List` with insetGrouped sections, one per category that has items, in fixed category order.
  - Section header: category icon + Spanish label + "{pendientes}".
  - Within a section: unpurchased items first (by createdAt), then purchased items.
- Item row (min 52pt):
  - Leading circular checkbox (`circle` / `checkmark.circle.fill` in brand green, 44pt hit area).
  - Name in body text. When purchased: strikethrough with secondary color.
  - Quantity as trailing secondary text (e.g. "2 kg").
  - Caption below: "Añadido por {addedBy.name}". When purchased: "Comprado por {purchasedBy.name}".
- Row interactions:
  - Tap checkbox → optimistic toggle + light haptic → `PATCH /api/items/:id {isPurchased}`. On failure, revert and show toast "No se pudo actualizar".
  - Tap row body → ItemFormSheet in edit mode.
  - Swipe trailing → "Eliminar" (destructive) → `DELETE /api/items/:id`, optimistic.
- Bottom bar: full-width primary button "Añadir artículo" (`plus`) → ItemFormSheet in add mode, with the category preselected from the active filter (or "Otros").
- Polling: `GET /api/lists/:id/items` every 3 s while visible and active.
  - The server response replaces local state, except for items with an in-flight mutation.
  - Changed rows animate with `.animation(.default, value: items)`.
- If polling returns 404 or 403 (list deleted by another member), show alert "Esta lista ya no existe" → OK → pop.
- Archived list: shows a banner "Lista archivada" with a "Desarchivar" button. Items remain editable.
- Empty state:
  - Icon `basket`
  - "La lista está vacía" and "Añade lo que necesitáis comprar."
  - Button "Añadir artículo"
- Filter yields nothing: "No hay artículos en {categoría}".
- Loading: skeleton rows. Error: "No se pudo cargar la lista" with "Reintentar".

### 10. ItemFormSheet (sheet, own NavigationStack, .medium/.large)
- Title "Nuevo artículo" or "Editar artículo".
- Fields:
  - "Nombre" (required, autofocus, placeholder "Leche")
  - "Cantidad (opcional)" (free text, placeholder "2 litros")
  - "Categoría": a 2-column grid of the 8 category tiles (icon + label); the selected tile has a brand border and tint.
- Toolbar: "Cancelar" and "Guardar" (disabled if the name is empty).
- Add mode: `POST /api/lists/:id/items`.
  - After saving, the sheet stays open with cleared fields and toast "Añadido: {nombre}", for fast multi-entry.
  - A secondary "Guardar y cerrar" button dismisses the sheet.
- Edit mode: `PATCH /api/items/:id` → dismiss.
- Edit mode also shows a destructive button "Eliminar artículo" at the bottom → DELETE → dismiss.

### 11. SettingsView
Grouped form, with data from `GET /api/family-groups/me` plus the session.
- Section "Perfil": name, email.
- Section "Grupo familiar":
  - Group name.
  - The invite code, large and monospaced, with buttons "Copiar" and ShareLink "Compartir" (same share text as in setup).
  - "Miembros": a list of members' names. The current user has the suffix "(tú)" and the creator shows the caption "Creador".
- Section (destructive):
  - "Salir del grupo"
    - Opens confirmationDialog "¿Salir de '{grupo}'? Dejarás de ver sus listas."
    - Confirm → `POST /api/family-groups/leave` → `session.setFamilyGroup(nil)`, and the root switches to FamilyGroupSetupView.
  - "Cerrar sesión" → `session.logout()`, and the root switches to AuthFlowView.
- Loading and error states are handled with "Reintentar".

</screens>

<navigation>
- **Root**: RootView switches on SessionModel state (splash / auth / group setup / main). Login, signup, group create/join, leave group and logout only change state; the root view swaps subtrees. No imperative navigation from these screens.
- **AuthFlowView**: one NavigationStack.
  - Root: WelcomeView.
  - Pushes LoginView and RegisterView (push from the right, back via the swipe gesture).
- **FamilyGroupSetupView**: one NavigationStack containing a single screen; it toggles modes via the segmented picker.
- **MainTabView** tabs:
  - "Listas": NavigationStack(path) with ListsHomeView → push ListDetailView(listId: UUID) via `.navigationDestination(for: UUID.self)`.
  - "Ajustes": NavigationStack with SettingsView.
- **Sheets** (each with its own NavigationStack):
  - CreateListSheet, from ListsHomeView
  - ItemFormSheet, from ListDetailView
- No NavigationStack inside pushed views.
- **Auth guard**: all main screens exist only under the authenticated-with-group branch. A 401 anywhere sets `user = nil`, and the root shows AuthFlowView.
- If any group endpoint returns 403 `NO_FAMILY_GROUP` (e.g. the group was removed), call `session.refreshMe()`; the root then shows FamilyGroupSetupView.
</navigation>

<design_direction>
**Audience and moment**
- Parents, partners and teens, standing in a supermarket aisle one-handed, or at home adding items in a few seconds.
- The feeling should be fresh, friendly, trustworthy and fast, like a tidy market stall.

**First screen**
- A returning user lands on ListsHomeView. Each card shows its progress, so the weekly list and how much is left are visible at a glance.
- A first-time user goes Welcome → Registro → Crear/Unirse grupo → empty lists state with "Crear lista" → first item added. That is under one minute.

**References**
- Apple Reminders: clean checkbox rows and grouped sections.
- Bring!: category iconography and a warm, food-forward tone.
- AnyList: density and strikethrough-purchased behaviour.

**Appearance**: light only; it is used in bright stores.

**Palette** (`Theme.Colors`)
- background `#F6F4EE` (warm paper)
- surface `#FFFFFF`
- textPrimary `#1E2A23`
- textSecondary `#5F6B64`
- brand `#2E7D4F` (leaf green; used for primary buttons, checkmarks and the FAB)
- accent `#E07A2E` (citrus orange; used for count badges and the invite code highlight only)
- separator `#E4E0D6`
- destructive: system red

**Typography**: SF Pro Rounded throughout (`.fontDesign(.rounded)`) for a family-friendly feel.
- display 34 bold
- title 28 bold
- headline 17 semibold
- body 17 regular
- caption 13 regular, textSecondary
- invite code: 34 semibold monospaced, tracking 6
- All styles support Dynamic Type.

**Shape and depth**
- Cards: radius 16, white, hairline border `#E4E0D6`, no shadow. The FAB alone gets a soft shadow (y 4, blur 12, 15% black).
- Buttons: radius 14, height 52.
- Chips: capsule.
- Detail screen: insetGrouped List sections on the paper background.

**Imagery**: SF Symbols only. Category icons:
| Category | Symbol |
|---|---|
| Frutas y Verduras | carrot.fill |
| Lácteos y Huevos | cup.and.saucer.fill |
| Carnes y Pescado | fish.fill |
| Panadería | basket.fill |
| Limpieza | bubbles.and.sparkles.fill |
| Bebidas | waterbottle.fill |
| Despensa | cabinet.fill |
| Otros | tag.fill |

Icons are tinted brand green on a 32pt circle filled with brand at 12% opacity.

**Components**
- Primary button: brand fill, white headline text, pressed state scales to 0.97 and dims to 0.9 opacity.
- Secondary button: white surface, brand text, hairline brand border.
- Inputs: white field, radius 12, 1pt separator border that turns brand on focus. The label sits above the field as a caption.
- List row: 52pt minimum height, with leading checkbox.
- Empty state: 56pt symbol in a brand-tint circle, headline, body text in secondary, and one primary button.
- Loading: `.redacted(reason: .placeholder)` skeletons.
- Error: an inline card with `exclamationmark.triangle`, the message, and a "Reintentar" secondary button.
- Toast: a capsule at the bottom showing textPrimary text on white, auto-hiding after 2 s.

**Theme file**: `Sources/Theme/Theme.swift` defines:
- Colors, Fonts, Spacing (4/8/16/24/32), Radii
- `PrimaryButtonStyle`, `SecondaryButtonStyle`, `CardModifier`, `ChipView`, `EmptyStateView`, `ErrorStateView`
- `ItemCategory` display helpers (label, symbol)

Views never hardcode colours or fonts.
</design_direction>

<animation_and_motion>
- Checkbox toggle: spring scale on the checkmark (0.8→1). The strikethrough and colour fade over 0.2 s. Light impact haptic.
- Rows inserted or removed by polling: default List animations.
- Group created or code copied: success notification haptic.
- FAB: press-scale feedback.
- Reduce Motion: replace springs with opacity fades.
</animation_and_motion>

## Accessibility
- Checkbox VoiceOver label: "{nombre}, {comprado | pendiente}", with the action hint "Marcar como comprado" or "Desmarcar".
- All touch targets are at least 44pt.
- Text contrast is at least 4.5:1 with the palette above.