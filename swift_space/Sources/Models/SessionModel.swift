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
        Task { @MainActor in
            await checkAuth()
        }
    }

    @MainActor
    func checkAuth() async {
        isLoading = true
        defer { isLoading = false }
        guard APIClient.shared.authToken != nil else {
            user = nil
            return
        }
        do {
            let response: MeResponseDto = try await APIClient.shared.me()
            user = response.user
        } catch {
            logger.error("checkAuth failed: \(error.localizedDescription)")
            APIClient.shared.authToken = nil
            user = nil
        }
    }

    @MainActor
    func login(email: String, password: String) async throws {
        let response = try await APIClient.shared.login(body: LoginDto(email: email, password: password))
        APIClient.shared.authToken = response.token
        user = response.user
    }

    @MainActor
    func signup(email: String, password: String, name: String) async throws {
        let response = try await APIClient.shared.signup(body: SignupDto(email: email, password: password, name: name))
        APIClient.shared.authToken = response.token
        user = response.user
    }

    @MainActor
    func logout() {
        APIClient.shared.authToken = nil
        user = nil
    }

    @MainActor
    func setFamilyGroup(id: String?) {
        user?.familyGroupId = id
    }

    @MainActor
    func refreshMe() async {
        do {
            let response: MeResponseDto = try await APIClient.shared.me()
            user = response.user
        } catch {
            logger.error("refreshMe failed: \(error.localizedDescription)")
        }
    }
}
