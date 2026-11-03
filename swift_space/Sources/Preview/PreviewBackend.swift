import Foundation

/// Datos de ejemplo sin red para las capturas de CI.
struct PreviewBackend: Backend {
    /// Configurables para probar nombres largos en los tests de snapshots.
    var groupName = "Familia García"
    var firstListName = "Mercado semanal"

    private static let now = "2026-01-15T10:00:00.000Z"
    private static let lucia = UserPublicDto(id: "u1", name: "Lucía")
    private static var luciaJSON: JSONValue { .object(["id": .string("u1"), "name": .string("Lucía")]) }

    private static func list(_ id: String, _ name: String, _ total: Double, _ done: Double) -> ShoppingListSummaryDto {
        ShoppingListSummaryDto(id: id, name: name, isArchived: false, createdBy: luciaJSON,
                               itemCount: total, purchasedCount: done, createdAt: now, updatedAt: now)
    }

    private static func item(_ id: String, _ name: String, _ qty: String, _ cat: String, _ bought: Bool) -> ListItemDto {
        ListItemDto(id: id, shoppingListId: "l1", name: name, quantity: qty, category: cat, isPurchased: bought,
                    purchasedBy: bought ? luciaJSON : nil, purchasedAt: bought ? now : nil,
                    addedBy: luciaJSON, createdAt: now, updatedAt: now)
    }

    private var group: FamilyGroupDto {
        FamilyGroupDto(
            id: "g1", name: groupName, inviteCode: "ABC123", createdById: "u1",
            members: [Self.lucia, UserPublicDto(id: "u2", name: "Pablo"), UserPublicDto(id: "u3", name: "Marta")],
            createdAt: Self.now)
    }

    func me() async throws -> MeResponseDto {
        MeResponseDto(user: AuthUserDto(id: "u1", email: "lucia@example.com", name: "Lucía", familyGroupId: "g1"))
    }
    func login(body: LoginDto) async throws -> AuthResponseDto { AuthResponseDto(token: "preview", user: try await me().user) }
    func signup(body: SignupDto) async throws -> AuthResponseDto { try await login(body: LoginDto(email: body.email, password: body.password)) }
    func signOut() async {}

    func myGroup() async throws -> FamilyGroupDto { group }
    func create(body: CreateGroupDto) async throws -> FamilyGroupDto { group }
    func join(body: JoinGroupDto) async throws -> FamilyGroupDto { group }
    func leave() async throws -> SuccessDto { SuccessDto(success: true) }

    func getLists(archived: String?) async throws -> ListsResponseDto {
        if archived == "true" { return ListsResponseDto(items: []) }
        return ListsResponseDto(items: [
            Self.list("l1", firstListName, 6, 2),
            Self.list("l2", "Cumpleaños de Marta", 4, 0),
            Self.list("l3", "Limpieza del hogar", 3, 3),
        ])
    }
    func create(body: CreateListDto) async throws -> ShoppingListSummaryDto { Self.list("l9", body.name, 0, 0) }
    func update(id: String, body: UpdateListDto) async throws -> ShoppingListSummaryDto { Self.list(id, body.name ?? "Lista", 0, 0) }
    func delete(id: String) async throws -> SuccessResponseDto { SuccessResponseDto(success: true) }

    func getListItems(id: String) async throws -> ListItemsResponseDto {
        ListItemsResponseDto(list: Self.list("l1", firstListName, 6, 2), items: [
            Self.item("i1", "Manzanas", "1 kg", "FRUTAS_VERDURAS", false),
            Self.item("i2", "Leche", "2 L", "LACTEOS_HUEVOS", false),
            Self.item("i3", "Pechuga de pollo", "500 g", "CARNES_PESCADO", false),
            Self.item("i4", "Pan integral", "1", "PANADERIA", true),
            Self.item("i5", "Arroz", "1 kg", "DESPENSA", true),
            Self.item("i6", "Agua con gas", "6", "BEBIDAS", false),
        ])
    }
    func createItem(id: String, body: CreateItemDto) async throws -> ListItemDto {
        Self.item("i9", body.name, body.quantity ?? "", body.category, false)
    }
    func updateItem(id: String, body: UpdateItemDto) async throws -> ListItemDto {
        Self.item(id, body.name ?? "Artículo", body.quantity ?? "", body.category ?? "OTROS", body.isPurchased ?? false)
    }
    func deleteItem(id: String) async throws -> SuccessDto { SuccessDto(success: true) }
    func changes(tables: [String]) -> AsyncStream<Void> { AsyncStream { $0.finish() } }
}
