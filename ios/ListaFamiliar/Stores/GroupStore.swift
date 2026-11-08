import Foundation
import Observation

/// Grupo familiar del usuario. Lo comparten la cabecera de «Mis listas», Ajustes y la pantalla de alta.
@Observable @MainActor
final class GroupStore {
    private(set) var group: FamilyGroup?
    private(set) var state: LoadState = .idle

    private let backend: any Backend

    init(backend: any Backend) {
        self.backend = backend
    }

    func load() async {
        if group == nil { state = .loading }
        do {
            group = try await backend.fetchGroup()
            state = .loaded
        } catch {
            if group == nil { state = .failed(error.userMessage) }
        }
    }

    func create(named name: String) async throws -> FamilyGroup {
        let group = try await backend.createGroup(named: NameInput.clean(name))
        self.group = group
        state = .loaded
        return group
    }

    func join(code: String) async throws -> FamilyGroup {
        let group = try await backend.joinGroup(code: InviteCode.normalize(code))
        self.group = group
        state = .loaded
        return group
    }

    func leave() async throws {
        try await backend.leaveGroup()
        reset()
    }

    /// Olvida los datos del grupo (al cerrar sesión o salir del grupo).
    func reset() {
        group = nil
        state = .idle
    }
}
