import Foundation

/// Errores que entiende la interfaz. El backend traduce los suyos a estos casos,
/// así las vistas solo muestran `localizedDescription`.
enum AppError: LocalizedError, Equatable, Sendable {
    case invalidCredentials
    case emailAlreadyRegistered
    case emailConfirmationRequired
    case notInGroup
    case notFound
    /// La política de seguridad del servidor rechaza el cambio (por ejemplo, un lector que intenta editar).
    case forbidden
    case offline
    /// Mensaje legible que viene del servidor (por ejemplo, de una excepción de una función SQL).
    case server(String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidCredentials: "Correo o contraseña incorrectos."
        case .emailAlreadyRegistered: "Ya existe una cuenta con ese correo."
        case .emailConfirmationRequired: "Confirma tu correo para continuar."
        case .notInGroup: "Todavía no perteneces a ningún grupo."
        case .notFound: "Esta lista ya no existe."
        case .forbidden: "Tu rol es de solo lectura: no puedes hacer este cambio."
        case .offline: "No hay conexión. Inténtalo de nuevo."
        case .server(let message): message
        case .unknown: "Algo salió mal. Inténtalo de nuevo."
        }
    }
}

extension Error {
    /// Texto para mostrar al usuario.
    var userMessage: String {
        (self as? AppError ?? .unknown).localizedDescription
    }
}
