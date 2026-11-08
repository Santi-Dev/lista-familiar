import Foundation
import Observation
import os

/// Sesión del usuario. Decide qué parte de la app se muestra (`RootView`).
@Observable @MainActor
final class SessionStore {
    enum Phase: Equatable {
        case launching
        /// No se pudo comprobar la sesión (por ejemplo, sin conexión al abrir la app).
        case unavailable(String)
        case signedOut
        case signedIn(User)
    }

    private(set) var phase: Phase = .launching

    var user: User? {
        if case .signedIn(let user) = phase { return user }
        return nil
    }

    private let backend: any Backend
    private let logger = Logger(subsystem: "com.santidev.listafamiliar", category: "Session")

    init(backend: any Backend) {
        self.backend = backend
    }

    /// Sesión ya resuelta, sin pasar por `restore()` (previews, capturas y tests).
    init(backend: any Backend, user: User?) {
        self.backend = backend
        phase = user.map(Phase.signedIn) ?? .signedOut
    }

    /// Recupera la sesión guardada (Supabase la guarda en el llavero).
    func restore() async {
        phase = .launching
        do {
            phase = try await backend.restoreSession().map(Phase.signedIn) ?? .signedOut
        } catch {
            logger.error("restore failed: \(error.localizedDescription)")
            phase = .unavailable(error.userMessage)
        }
    }

    func signIn(email: String, password: String) async throws {
        let user = try await backend.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        phase = .signedIn(user)
    }

    func signUp(name: String, email: String, password: String) async throws {
        let user = try await backend.signUp(
            name: NameInput.clean(name), email: email.trimmingCharacters(in: .whitespaces), password: password)
        phase = .signedIn(user)
    }

    func signOut() async {
        phase = .signedOut
        await backend.signOut()
    }

    /// Pide el correo para restablecer la contraseña. Funciona igual aunque el correo no tenga cuenta.
    func sendPasswordReset(email: String) async throws {
        try await backend.sendPasswordReset(email: email.trimmingCharacters(in: .whitespaces))
    }

    func deleteAccount() async throws {
        try await backend.deleteAccount()
        phase = .signedOut
    }

    /// El usuario ha creado un grupo o se ha unido a uno.
    func joined(_ group: FamilyGroup) {
        guard var user else { return }
        user.familyGroupID = group.id
        phase = .signedIn(user)
    }

    /// El usuario ha salido de su grupo.
    func leftGroup() {
        guard var user else { return }
        user.familyGroupID = nil
        phase = .signedIn(user)
    }
}

/// Reglas de los formularios de acceso.
enum Credentials {
    static let minimumPasswordLength = 8

    static func isPlausibleEmail(_ email: String) -> Bool {
        let parts = email.trimmingCharacters(in: .whitespaces).split(separator: "@")
        return parts.count == 2 && parts[1].contains(".") && !parts[0].isEmpty
    }

    static func canSignIn(email: String, password: String) -> Bool {
        isPlausibleEmail(email) && !password.isEmpty
    }

    static func canSignUp(name: String, email: String, password: String) -> Bool {
        NameInput.isValid(name) && isPlausibleEmail(email) && password.count >= minimumPasswordLength
    }

    /// Alta con la contraseña repetida y la política de privacidad aceptada.
    static func canSignUp(
        name: String, email: String, password: String, confirmation: String, acceptedPrivacy: Bool
    ) -> Bool {
        canSignUp(name: name, email: email, password: password) && password == confirmation && acceptedPrivacy
    }
}
