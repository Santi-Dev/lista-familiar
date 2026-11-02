import SwiftUI
import os

private let logger = Logger(subsystem: "com.app.familyshoppinglists", category: "Session")

@Observable
class SessionModel {
    var user: AuthUserDto?
    var isLoading = true

    var isAuthenticated: Bool { user != nil }
    var hasFamilyGroup: Bool { user?.familyGroupId != nil }

    init() {
        Task { @MainActor in await checkAuth() }
    }

    /// Supabase guarda la sesión en el Keychain; si existe y es válida, `me()` devuelve el usuario.
    @MainActor
    func checkAuth() async {
        isLoading = true
        defer { isLoading = false }
        do {
            user = try await APIClient.shared.me().user
        } catch {
            logger.error("checkAuth failed: \(error.localizedDescription)")
            user = nil
        }
    }

    @MainActor
    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(body: LoginDto(email: email, password: password))
        user = response.user
    }

    @MainActor
    func signup(email: String, password: String, name: String) async throws {
        let response = try await APIClient.shared.signup(body: SignupDto(email: email, password: password, name: name))
        user = response.user
    }

    @MainActor
    func logout() {
        user = nil
        Task { await APIClient.shared.signOut() }
    }

    @MainActor
    func setFamilyGroup(id: String?) {
        user?.familyGroupId = id
    }

    @MainActor
    func refreshMe() async {
        do {
            user = try await APIClient.shared.me().user
        } catch {
            logger.error("refreshMe failed: \(error.localizedDescription)")
        }
    }
}
