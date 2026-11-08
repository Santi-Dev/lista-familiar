import SwiftUI

// Colores: viven en `Resources/Assets.xcassets` (con variante oscura) y Xcode genera
// `Color.brand`, `.highlight`, `.appBackground`, `.surface`, `.textPrimary`, `.textSecondary` y `.hairline`.
// La tipografía SF Pro Rounded se aplica una sola vez en la raíz (`appStyle()`) y se hereda.

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
        static let field: CGFloat = 12
        static let tile: CGFloat = 10
    }

    /// Alto mínimo de los controles principales (área táctil cómoda).
    static let controlHeight: CGFloat = 52
}

extension Font {
    static let screenTitle = Font.system(size: 28, weight: .bold)
    static let heroTitle = Font.system(size: 34, weight: .bold)
    static let inviteCode = Font.system(size: 32, weight: .semibold, design: .monospaced)
}
