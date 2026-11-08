import Foundation

/// Contrato de acceso a datos. Solo lo usan los stores (`Stores/`), nunca las vistas.
///
/// - `SupabaseBackend`: implementación real (Auth + PostgREST con RLS + RPC + Realtime).
/// - `InMemoryBackend`: datos de ejemplo en memoria para previews, capturas de CI, modo demo y tests.
///
/// Todos los errores que lanzan las implementaciones son `AppError`.
protocol Backend: Sendable {
    // MARK: Sesión
    /// Usuario de la sesión guardada, o `nil` si no hay sesión.
    func restoreSession() async throws -> User?
    func signIn(email: String, password: String) async throws -> User
    func signUp(name: String, email: String, password: String) async throws -> User
    func signOut() async
    /// Borra la cuenta y todos sus datos (función SQL `delete_my_account`).
    func deleteAccount() async throws

    // MARK: Grupo familiar
    /// Grupo del usuario, o `nil` si no pertenece a ninguno.
    func fetchGroup() async throws -> FamilyGroup?
    func createGroup(named name: String) async throws -> FamilyGroup
    func joinGroup(code: String) async throws -> FamilyGroup
    func leaveGroup() async throws

    // MARK: Listas
    func fetchLists(archived: Bool) async throws -> [ShoppingList]
    func fetchList(id: UUID) async throws -> ShoppingList
    func createList(named name: String, groupID: UUID) async throws -> ShoppingList
    func updateList(id: UUID, _ changes: ListChanges) async throws -> ShoppingList
    func deleteList(id: UUID) async throws

    // MARK: Artículos
    func fetchItems(listID: UUID) async throws -> [ListItem]
    func createItem(in listID: UUID, _ draft: ItemDraft) async throws -> ListItem
    func updateItem(id: UUID, _ draft: ItemDraft) async throws -> ListItem
    func setPurchased(_ isPurchased: Bool, itemID: UUID) async throws -> ListItem
    func deleteItem(id: UUID) async throws

    // MARK: Tiempo real
    /// Emite cada vez que cambian las listas o los artículos del grupo. Termina al cancelar la tarea.
    func changes() -> AsyncStream<Void>
}
