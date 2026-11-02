import Foundation

/// Texto de error para el usuario a partir de un error del backend.
func userMessage(for error: Error, fallback: String = "No se pudo conectar. Inténtalo de nuevo.") -> String {
    if let apiError = error as? APIError, case .http(_, let message) = apiError, let message, !message.isEmpty {
        return message
    }
    return fallback
}

enum RelativeDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()
    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "es_ES")
        return f
    }()

    /// "hace 2 horas" a partir de una fecha ISO 8601 (con o sin fracción de segundo).
    static func string(from iso: String) -> String {
        guard let date = withFraction.date(from: iso) ?? plain.date(from: iso) else { return "" }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
