import Foundation
import Observation

@Observable @MainActor
final class SettingsViewModel {
    private(set) var group: FamilyGroupDto?
    private(set) var isLoading = true
    private(set) var errorMsg: String?

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

    func leaveGroup() async {
        _ = try? await backend.leave()
    }
}
