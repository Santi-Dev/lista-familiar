import Foundation

enum APIError: Error, LocalizedError {
    case http(status: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .http(let status, let message): return message ?? "Error en la petición (\(status))."
        }
    }
}

/// Contrato de datos de la app. `SupabaseBackend` es la implementación real y
/// `PreviewBackend` sirve datos de ejemplo para las capturas de CI.
protocol Backend: Sendable {
    func me() async throws -> MeResponseDto
    func login(body: LoginDto) async throws -> AuthResponseDto
    func signup(body: SignupDto) async throws -> AuthResponseDto
    func signOut() async

    func myGroup() async throws -> FamilyGroupDto
    func create(body: CreateGroupDto) async throws -> FamilyGroupDto
    func join(body: JoinGroupDto) async throws -> FamilyGroupDto
    func leave() async throws -> SuccessDto

    func getLists(archived: String?) async throws -> ListsResponseDto
    func create(body: CreateListDto) async throws -> ShoppingListSummaryDto
    func update(id: String, body: UpdateListDto) async throws -> ShoppingListSummaryDto
    func delete(id: String) async throws -> SuccessResponseDto
    func getListItems(id: String) async throws -> ListItemsResponseDto
    func createItem(id: String, body: CreateItemDto) async throws -> ListItemDto
    func updateItem(id: String, body: UpdateItemDto) async throws -> ListItemDto
    func deleteItem(id: String) async throws -> SuccessDto

    /// Emite un valor cada vez que cambia alguna de las tablas (Realtime); termina si se cancela la tarea.
    func changes(tables: [String]) -> AsyncStream<Void>
}

enum APIClient {
    /// `var` para poder sustituirlo en los tests (por ejemplo por `PreviewBackend`).
    static var shared: any Backend = (PreviewMode.screen != nil || PreviewMode.isRunningTests) ? PreviewBackend() : SupabaseBackend()
}
