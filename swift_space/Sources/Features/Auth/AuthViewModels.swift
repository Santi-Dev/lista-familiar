import Foundation
import Observation

@Observable @MainActor
final class LoginViewModel {
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var canSubmit: Bool { !email.isEmpty && !password.isEmpty && !isLoading }

    func submit(session: SessionModel) async {
        isLoading = true
        errorMessage = nil
        do {
            try await session.login(email: email, password: password)
        } catch {
            errorMessage = userMessage(for: error)
        }
        isLoading = false
    }
}

@Observable @MainActor
final class RegisterViewModel {
    var name = ""
    var email = ""
    var password = ""
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    var isValid: Bool { !name.isEmpty && email.contains("@") && password.count >= 8 }
    var canSubmit: Bool { isValid && !isLoading }

    func submit(session: SessionModel) async {
        isLoading = true
        errorMessage = nil
        do {
            try await session.signup(email: email, password: password, name: name)
        } catch {
            errorMessage = userMessage(for: error)
        }
        isLoading = false
    }
}
