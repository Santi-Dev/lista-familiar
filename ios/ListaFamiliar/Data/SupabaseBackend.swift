import Foundation
import Supabase

/// Implementación sobre Supabase. Las reglas de acceso viven en la base de datos
/// (políticas RLS y funciones `security definer` de `supabase/migrations/`).
final class SupabaseBackend: Backend {
    private let client: SupabaseClient

    init(url: URL = AppConfig.supabaseURL, anonKey: String = AppConfig.supabaseAnonKey) {
        client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey,
            options: SupabaseClientOptions(auth: .init(emitLocalSessionAsInitialSession: true))
        )
    }

    // MARK: - Sesión

    func restoreSession() async throws -> User? {
        guard client.auth.currentSession != nil else { return nil }
        let session: Session
        do {
            session = try await client.auth.session
        } catch let error as URLError {
            throw Self.map(error)
        } catch {
            // Sesión caducada o revocada: hay que volver a iniciar sesión.
            return nil
        }
        return try await perform { try await self.profile(for: session.user) }
    }

    func signIn(email: String, password: String) async throws -> User {
        try await perform {
            let session = try await self.client.auth.signIn(email: email, password: password)
            return try await self.profile(for: session.user)
        }
    }

    func signUp(name: String, email: String, password: String) async throws -> User {
        try await perform {
            let response = try await self.client.auth.signUp(
                email: email, password: password, data: ["name": .string(name)])
            guard let session = response.session else { throw AppError.emailConfirmationRequired }
            return try await self.profile(for: session.user)
        }
    }

    func signOut() async {
        try? await client.auth.signOut()
    }

    func deleteAccount() async throws {
        try await perform {
            try await self.client.rpc("delete_my_account").execute()
            // El usuario ya no existe en el servidor: basta con limpiar la sesión local.
            try? await self.client.auth.signOut(scope: .local)
        }
    }

    private func profile(for authUser: Auth.User) async throws -> User {
        let row: ProfileRecord = try await client.from("profiles")
            .select(ProfileRecord.columns)
            .eq("id", value: authUser.id)
            .single()
            .execute().value
        return User(id: authUser.id, name: row.name, email: authUser.email ?? "", familyGroupID: row.familyGroupID)
    }

    // MARK: - Grupo familiar

    func fetchGroup() async throws -> FamilyGroup? {
        try await perform {
            let rows: [GroupRecord] = try await self.client.from("family_groups")
                .select(GroupRecord.columns)
                .limit(1)
                .execute().value
            return rows.first?.model
        }
    }

    func createGroup(named name: String) async throws -> FamilyGroup {
        try await perform {
            try await self.client.rpc("create_family_group", params: ["group_name": name]).execute()
            return try await self.requireGroup()
        }
    }

    func joinGroup(code: String) async throws -> FamilyGroup {
        try await perform {
            try await self.client.rpc("join_family_group", params: ["code": code]).execute()
            return try await self.requireGroup()
        }
    }

    func leaveGroup() async throws {
        try await perform { _ = try await self.client.rpc("leave_family_group").execute() }
    }

    private func requireGroup() async throws -> FamilyGroup {
        guard let group = try await fetchGroup() else { throw AppError.notInGroup }
        return group
    }

    // MARK: - Listas

    func fetchLists(archived: Bool) async throws -> [ShoppingList] {
        try await perform {
            let rows: [ListRecord] = try await self.client.from("shopping_lists")
                .select(ListRecord.columns)
                .eq("is_archived", value: archived)
                .order("updated_at", ascending: false)
                .execute().value
            return rows.map(\.model)
        }
    }

    func fetchList(id: UUID) async throws -> ShoppingList {
        try await perform {
            let row: ListRecord = try await self.client.from("shopping_lists")
                .select(ListRecord.columns)
                .eq("id", value: id)
                .single()
                .execute().value
            return row.model
        }
    }

    func createList(named name: String, groupID: UUID) async throws -> ShoppingList {
        try await perform {
            let userID = try await self.client.auth.session.user.id
            let row: ListRecord = try await self.client.from("shopping_lists")
                .insert(ListInsert(name: name, familyGroupID: groupID, createdByID: userID))
                .select(ListRecord.columns)
                .single()
                .execute().value
            return row.model
        }
    }

    func updateList(id: UUID, _ changes: ListChanges) async throws -> ShoppingList {
        try await perform {
            let row: ListRecord = try await self.client.from("shopping_lists")
                .update(ListUpdate(changes))
                .eq("id", value: id)
                .select(ListRecord.columns)
                .single()
                .execute().value
            return row.model
        }
    }

    func deleteList(id: UUID) async throws {
        try await perform { _ = try await self.client.from("shopping_lists").delete().eq("id", value: id).execute() }
    }

    // MARK: - Artículos

    func fetchItems(listID: UUID) async throws -> [ListItem] {
        try await perform {
            let rows: [ItemRecord] = try await self.client.from("list_items")
                .select(ItemRecord.columns)
                .eq("shopping_list_id", value: listID)
                .order("created_at")
                .execute().value
            return rows.map(\.model)
        }
    }

    func createItem(in listID: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try await perform {
            // `added_by_id` lo rellena el trigger `item_before_write` con `auth.uid()`.
            let row: ItemRecord = try await self.client.from("list_items")
                .insert(ItemInsert(listID: listID, draft: draft))
                .select(ItemRecord.columns)
                .single()
                .execute().value
            return row.model
        }
    }

    func updateItem(id: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try await updateItem(id: id, ItemUpdate(draft: draft))
    }

    func setPurchased(_ isPurchased: Bool, itemID: UUID) async throws -> ListItem {
        // `purchased_by_id` y `purchased_at` los gestiona el trigger `item_before_write`.
        try await updateItem(id: itemID, ItemUpdate(isPurchased: isPurchased))
    }

    private func updateItem(id: UUID, _ update: ItemUpdate) async throws -> ListItem {
        try await perform {
            let row: ItemRecord = try await self.client.from("list_items")
                .update(update)
                .eq("id", value: id)
                .select(ItemRecord.columns)
                .single()
                .execute().value
            return row.model
        }
    }

    func deleteItem(id: UUID) async throws {
        try await perform { _ = try await self.client.from("list_items").delete().eq("id", value: id).execute() }
    }

    // MARK: - Tiempo real

    /// Un canal con un `postgresChange` por tabla. RLS filtra los eventos a tu grupo.
    func changes() -> AsyncStream<Void> {
        let client = client
        return AsyncStream { continuation in
            let channel = client.channel("changes-\(UUID().uuidString)")
            let streams = ["shopping_lists", "list_items"].map {
                channel.postgresChange(AnyAction.self, schema: "public", table: $0)
            }
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

    // MARK: - Errores

    /// Ejecuta una operación y traduce cualquier error a `AppError`.
    private func perform<T: Sendable>(_ work: @Sendable () async throws -> T) async throws -> T {
        do {
            return try await work()
        } catch let error as AppError {
            throw error
        } catch let error as PostgrestError {
            // PGRST116: `.single()` sin filas (la lista se borró o ya no es de tu grupo).
            if error.code == "PGRST116" { throw AppError.notFound }
            throw AppError.server(error.message)
        } catch let error as AuthError {
            throw Self.map(error)
        } catch let error as URLError {
            throw Self.map(error)
        } catch {
            throw AppError.unknown
        }
    }

    private static func map(_ error: URLError) -> AppError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost,
             .dataNotAllowed, .internationalRoamingOff:
            .offline
        default:
            .unknown
        }
    }

    private static func map(_ error: AuthError) -> AppError {
        let text = error.localizedDescription.lowercased()
        if error.errorCode == .invalidCredentials || text.contains("invalid login credentials") {
            return .invalidCredentials
        }
        if error.errorCode == .userAlreadyExists || error.errorCode == .emailExists || text.contains("already registered") {
            return .emailAlreadyRegistered
        }
        if error.errorCode == .emailNotConfirmed { return .emailConfirmationRequired }
        return .server(error.localizedDescription)
    }
}
