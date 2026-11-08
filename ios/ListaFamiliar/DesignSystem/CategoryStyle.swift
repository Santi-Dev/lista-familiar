import SwiftUI

extension ItemCategory {
    /// Color de la categoría (iconos, puntos y chips). Verdes, azules, ámbar… del sistema de diseño.
    var tint: Color {
        switch self {
        case .produce: Color(hex: 0x3B7A57)
        case .dairyEggs: Color(hex: 0x2A75D3)
        case .meatFish: Color(hex: 0xE11D48)
        case .bakery: Color(hex: 0xB45309)
        case .cleaning: Color(hex: 0x0D9488)
        case .drinks: Color(hex: 0x0891B2)
        case .pantry: Color(hex: 0xD97706)
        case .other: Color(hex: 0x6B7280)
        }
    }
}
