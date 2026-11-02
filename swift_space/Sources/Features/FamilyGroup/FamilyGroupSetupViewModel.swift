import Foundation
import Observation

@Observable @MainActor
final class FamilyGroupSetupViewModel {
    enum Mode { case create, join }

    var mode: Mode = .create
    var groupName = ""
    var inviteCode = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var createdGroup: FamilyGroupDto?

    private let backend: any Backend

    init(backend: any Backend = APIClient.shared) {
        self.backend = backend
    }

    /// Solo mayúsculas y 6 caracteres como máximo.
    func normalizeInviteCode() {
        let normalized = String(inviteCode.uppercased().prefix(6))
        if normalized != inviteCode { inviteCode = normalized }
    }

    var canCreate: Bool { !groupName.isEmpty && !isLoading }
    var canJoin: Bool { inviteCode.count == 6 && !isLoading }

    func create() async {
        isLoading = true
        errorMessage = nil
        do {
            createdGroup = try await backend.create(body: CreateGroupDto(name: groupName))
        } catch {
            errorMessage = userMessage(for: error, fallback: "No se pudo conectar.")
        }
        isLoading = false
    }

    /// Devuelve el grupo al que se unió, o nil si falló (el motivo queda en `errorMessage`).
    func join() async -> FamilyGroupDto? {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            return try await backend.join(body: JoinGroupDto(inviteCode: inviteCode))
        } catch {
            errorMessage = userMessage(for: error, fallback: "No se pudo conectar.")
            return nil
        }
    }
}
