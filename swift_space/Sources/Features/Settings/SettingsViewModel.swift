import Foundation
import Observation

@Observable @MainActor
final class SettingsViewModel {
    private(set) var group: FamilyGroupDto?
    private(set) var isLoading = true
    private(set) var errorMsg: String?
    private(set) var isDeleting = false
    var deleteError: String?

    private let backend: any Backend

    init(backend: any Backend = APIClient.shared) {
        self.backend = backend
    }

    func load() async {
        isLoading = true
        do {
            group = try await backend.myGroup()
            errorMsg = nil
        } catch {
            errorMsg = "No se pudo cargar la información"
        }
        isLoading = false
    }

    /// Borra la cuenta en el servidor. Devuelve `true` si salió bien; si no, deja el motivo en `deleteError`.
    func deleteAccount() async -> Bool {
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await backend.deleteAccount()
            return true
        } catch {
            deleteError = userMessage(for: error, fallback: "No se pudo eliminar la cuenta. Inténtalo de nuevo.")
            return false
        }
    }

    func leaveGroup() async {
        _ = try? await backend.leave()
    }
}
