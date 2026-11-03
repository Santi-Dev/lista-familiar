import Foundation
import Supabase

/// Implementación sobre Supabase: Auth + PostgREST (con RLS) + RPC para los grupos.
/// Las reglas de acceso viven en la base de datos (supabase/migrations/001_init.sql).
final class SupabaseBackend: Backend, @unchecked Sendable {
    private let client: SupabaseClient

    init() {
        client = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
    }

    // MARK: - Filas (snake_case de Postgres)

    private struct UserRef: Codable {
        var id: String
        var name: String
        var json: JSONValue { .object(["id": .string(id), "name": .string(name)]) }
        enum CodingKeys: String, CodingKey { case id, name }
    }

    private struct ProfileRow: Codable {
        var id: String
        var name: String
        var familyGroupId: String?
        enum CodingKeys: String, CodingKey { case id, name; case familyGroupId = "family_group_id" }
    }

    private struct GroupRow: Codable {
        var id: String
        var name: String
        var inviteCode: String
        var createdById: String?
        var createdAt: String
        var members: [UserRef]
        enum CodingKeys: String, CodingKey {
            case id, name, members
            case inviteCode = "invite_code", createdById = "created_by_id", createdAt = "created_at"
        }
    }

    private struct ListRow: Codable {
        var id: String
        var name: String
        var isArchived: Bool
        var createdAt: String
        var updatedAt: String
        var createdBy: UserRef?
        var items: [PurchaseFlag]?
        struct PurchaseFlag: Codable {
            var isPurchased: Bool
            enum CodingKeys: String, CodingKey { case isPurchased = "is_purchased" }
        }
        enum CodingKeys: String, CodingKey {
            case id, name
            case isArchived = "is_archived", createdAt = "created_at", updatedAt = "updated_at"
            case createdBy = "created_by", items = "list_items"
        }
        var dto: ShoppingListSummaryDto {
            let flags = items ?? []
            return ShoppingListSummaryDto(
                id: id, name: name, isArchived: isArchived, createdBy: createdBy?.json,
                itemCount: Double(flags.count),
                purchasedCount: Double(flags.filter(\.isPurchased).count),
                createdAt: createdAt, updatedAt: updatedAt)
        }
    }

    private struct ItemRow: Codable {
        var id: String
        var shoppingListId: String
        var name: String
        var quantity: String?
        var category: String
        var isPurchased: Bool
        var purchasedAt: String?
        var createdAt: String
        var updatedAt: String
        var addedBy: UserRef?
        var purchasedBy: UserRef?
        enum CodingKeys: String, CodingKey {
            case id, name, quantity, category
            case shoppingListId = "shopping_list_id", isPurchased = "is_purchased", purchasedAt = "purchased_at"
            case createdAt = "created_at", updatedAt = "updated_at"
            case addedBy = "added_by", purchasedBy = "purchased_by"
        }
        var dto: ListItemDto {
            ListItemDto(id: id, shoppingListId: shoppingListId, name: name, quantity: quantity,
                        category: category, isPurchased: isPurchased, purchasedBy: purchasedBy?.json,
                        purchasedAt: purchasedAt, addedBy: addedBy?.json, createdAt: createdAt, updatedAt: updatedAt)
        }
    }

    private static let listSelect = "id,name,is_archived,created_at,updated_at,created_by:profiles!created_by_id(id,name),list_items(is_purchased)"
    private static let itemSelect = "id,shopping_list_id,name,quantity,category,is_purchased,purchased_at,created_at,updated_at,added_by:profiles!added_by_id(id,name),purchased_by:profiles!purchased_by_id(id,name)"
    // `family_groups` y `profiles` tienen dos relaciones (miembros y creador): el hint evita PGRST201.
    private static let groupSelect = "id,name,invite_code,created_by_id,created_at,members:profiles!family_group_id(id,name)"

    // MARK: - Errores

    private func run<T>(_ work: () async throws -> T) async throws -> T {
        do { return try await work() }
        catch let error as APIError { throw error }
        catch let error as PostgrestError { throw APIError.http(status: 400, message: error.message) }
        catch {
            let text = error.localizedDescription
            if text.localizedCaseInsensitiveContains("invalid login credentials") {
                throw APIError.http(status: 401, message: "Correo o contraseña incorrectos")
            }
            if text.localizedCaseInsensitiveContains("already registered") {
                throw APIError.http(status: 409, message: "Ya existe una cuenta con ese correo")
            }
            throw APIError.http(status: 500, message: text)
        }
    }

    private func userId() async throws -> String {
        try await client.auth.session.user.id.uuidString.lowercased()
    }

    // MARK: - Auth

    func me() async throws -> MeResponseDto {
        try await run {
            let session = try await client.auth.session
            let id = session.user.id.uuidString.lowercased()
            let profile: ProfileRow = try await client.from("profiles").select("id,name,family_group_id")
                .eq("id", value: id).single().execute().value
            return MeResponseDto(user: AuthUserDto(id: id, email: session.user.email ?? "", name: profile.name,
                                                   familyGroupId: profile.familyGroupId))
        }
    }

    func login(body: LoginDto) async throws -> AuthResponseDto {
        try await run {
            let session = try await client.auth.signIn(email: body.email, password: body.password)
            return AuthResponseDto(token: session.accessToken, user: try await me().user)
        }
    }

    func signup(body: SignupDto) async throws -> AuthResponseDto {
        try await run {
            let response = try await client.auth.signUp(email: body.email, password: body.password,
                                                        data: ["name": .string(body.name)])
            guard let session = response.session else {
                throw APIError.http(status: 400, message: "Confirma tu correo para continuar")
            }
            return AuthResponseDto(token: session.accessToken, user: try await me().user)
        }
    }

    func signOut() async { try? await client.auth.signOut() }

    // MARK: - Grupos

    func myGroup() async throws -> FamilyGroupDto {
        try await run {
            let row: GroupRow = try await client.from("family_groups").select(Self.groupSelect)
                .limit(1).single().execute().value
            return FamilyGroupDto(id: row.id, name: row.name, inviteCode: row.inviteCode,
                                  createdById: row.createdById,
                                  members: row.members.map { UserPublicDto(id: $0.id, name: $0.name) },
                                  createdAt: row.createdAt)
        }
    }

    private struct CreateGroupParams: Encodable { var group_name: String }
    private struct JoinGroupParams: Encodable { var code: String }

    func create(body: CreateGroupDto) async throws -> FamilyGroupDto {
        try await run {
            try await client.rpc("create_family_group", params: CreateGroupParams(group_name: body.name)).execute()
            return try await myGroup()
        }
    }

    func join(body: JoinGroupDto) async throws -> FamilyGroupDto {
        try await run {
            try await client.rpc("join_family_group", params: JoinGroupParams(code: body.inviteCode)).execute()
            return try await myGroup()
        }
    }

    func leave() async throws -> SuccessDto {
        try await run {
            try await client.rpc("leave_family_group").execute()
            return SuccessDto(success: true)
        }
    }

    // MARK: - Listas

    func getLists(archived: String?) async throws -> ListsResponseDto {
        try await run {
            let rows: [ListRow] = try await client.from("shopping_lists").select(Self.listSelect)
                .eq("is_archived", value: archived == "true" ? "true" : "false")
                .order("updated_at", ascending: false).execute().value
            return ListsResponseDto(items: rows.map(\.dto))
        }
    }

    private struct ListInsert: Encodable {
        var name: String
        var family_group_id: String
        var created_by_id: String
    }

    func create(body: CreateListDto) async throws -> ShoppingListSummaryDto {
        try await run {
            guard let groupId = try await me().user.familyGroupId else {
                throw APIError.http(status: 400, message: "No perteneces a ningún grupo")
            }
            let row: ListRow = try await client.from("shopping_lists")
                .insert(ListInsert(name: body.name, family_group_id: groupId, created_by_id: try await userId()))
                .select(Self.listSelect).single().execute().value
            return row.dto
        }
    }

    private struct ListUpdate: Encodable {
        var name: String?
        var is_archived: Bool?
    }

    func update(id: String, body: UpdateListDto) async throws -> ShoppingListSummaryDto {
        try await run {
            let row: ListRow = try await client.from("shopping_lists")
                .update(ListUpdate(name: body.name, is_archived: body.isArchived))
                .eq("id", value: id).select(Self.listSelect).single().execute().value
            return row.dto
        }
    }

    func delete(id: String) async throws -> SuccessResponseDto {
        try await run {
            try await client.from("shopping_lists").delete().eq("id", value: id).execute()
            return SuccessResponseDto(success: true)
        }
    }

    // MARK: - Artículos

    func getListItems(id: String) async throws -> ListItemsResponseDto {
        try await run {
            let list: ListRow = try await client.from("shopping_lists").select(Self.listSelect)
                .eq("id", value: id).single().execute().value
            let rows: [ItemRow] = try await client.from("list_items").select(Self.itemSelect)
                .eq("shopping_list_id", value: id)
                .order("category").order("created_at").execute().value
            return ListItemsResponseDto(list: list.dto, items: rows.map(\.dto))
        }
    }

    private struct ItemInsert: Encodable {
        var shopping_list_id: String
        var name: String
        var quantity: String?
        var category: String
    }

    func createItem(id: String, body: CreateItemDto) async throws -> ListItemDto {
        try await run {
            let row: ItemRow = try await client.from("list_items")
                .insert(ItemInsert(shopping_list_id: id, name: body.name, quantity: body.quantity, category: body.category))
                .select(Self.itemSelect).single().execute().value
            return row.dto
        }
    }

    private struct ItemUpdate: Encodable {
        var name: String?
        var quantity: String?
        var category: String?
        var is_purchased: Bool?
    }

    func updateItem(id: String, body: UpdateItemDto) async throws -> ListItemDto {
        try await run {
            let row: ItemRow = try await client.from("list_items")
                .update(ItemUpdate(name: body.name, quantity: body.quantity, category: body.category, is_purchased: body.isPurchased))
                .eq("id", value: id).select(Self.itemSelect).single().execute().value
            return row.dto
        }
    }

    func deleteItem(id: String) async throws -> SuccessDto {
        try await run {
            try await client.from("list_items").delete().eq("id", value: id).execute()
            return SuccessDto(success: true)
        }
    }

    // MARK: - Realtime

    /// Canal de Realtime con un `postgresChange` por tabla. RLS filtra los eventos a tu grupo.
    func changes(tables: [String]) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let channel = client.channel("rt-\(UUID().uuidString)")
            let streams = tables.map { channel.postgresChange(AnyAction.self, schema: "public", table: $0) }
            let task = Task {
                do { try await channel.subscribeWithError() } catch { continuation.finish(); return }
                await withTaskGroup(of: Void.self) { group in
                    for stream in streams {
                        group.addTask { for await _ in stream { continuation.yield() } }
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
                Task { await channel.unsubscribe() }
            }
        }
    }
}
