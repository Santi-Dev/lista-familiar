import SwiftUI

// Colores: viven en `Resources/Assets.xcassets` (con variante oscura) y Xcode genera
// `Color.brand`, `.highlight`, `.appBackground`, `.surface`, `.textPrimary`, `.textSecondary` y `.hairline`.
// Tipografía: Plus Jakarta Sans (titulares) e Inter (cuerpo y etiquetas), empaquetadas en `Resources/Fonts`
// y registradas al arrancar (`FontRegistry`). La fuente por defecto se fija una sola vez en `appStyle()`.

enum Theme {
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radius {
        static let card: CGFloat = 16
        static let button: CGFloat = 14
        static let field: CGFloat = 14
        static let tile: CGFloat = 12
    }

    /// Alto mínimo de los controles principales (área táctil cómoda).
    static let controlHeight: CGFloat = 52
}

// MARK: - Tipografía

extension Font {
    private static let headlineFamily = "Plus Jakarta Sans"
    private static let textFamily = "Inter"

    // Titulares (Plus Jakarta Sans).
    static let displayLarge = Font.custom(headlineFamily, size: 34, relativeTo: .largeTitle).weight(.bold)
    static let headlineLarge = Font.custom(headlineFamily, size: 26, relativeTo: .title).weight(.bold)
    static let headlineMedium = Font.custom(headlineFamily, size: 20, relativeTo: .title3).weight(.semibold)
    static let headlineSmall = Font.custom(headlineFamily, size: 17, relativeTo: .headline).weight(.semibold)

    // Cuerpo y etiquetas (Inter).
    static let bodyLarge = Font.custom(textFamily, size: 17, relativeTo: .body)
    static let bodyMedium = Font.custom(textFamily, size: 15, relativeTo: .callout)
    static let bodySmall = Font.custom(textFamily, size: 13, relativeTo: .footnote)
    static let labelLarge = Font.custom(textFamily, size: 15, relativeTo: .callout).weight(.semibold)
    static let labelMedium = Font.custom(textFamily, size: 13, relativeTo: .footnote).weight(.semibold)
    static let labelSmall = Font.custom(textFamily, size: 11, relativeTo: .caption2).weight(.semibold)

    static let inviteCode = Font.system(size: 32, weight: .semibold, design: .monospaced)
}

// MARK: - Color a partir de un valor hexadecimal

extension Color {
    /// Color sRGB fijo (no cambia con el modo oscuro). Para colores que sí cambian, usa el catálogo de assets.
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1)
    }
}
