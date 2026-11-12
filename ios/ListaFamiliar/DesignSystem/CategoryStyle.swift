import SwiftUI

extension MemberRole {
    /// Color de la etiqueta del rol.
    var tint: Color {
        switch self {
        case .owner: .brand
        case .admin: Color(hex: 0x2A75D3)
        case .editor: .textSecondary
        case .viewer: .highlight
        }
    }
}

extension ListIcon {
    /// Color del icono de la lista (tarjetas y selector).
    var tint: Color {
        switch self {
        case .cart: .brand
        case .food: Color(hex: 0xE11D48)
        case .pharmacy: Color(hex: 0x0D9488)
        case .party: Color(hex: 0xD97706)
        case .cleaning: Color(hex: 0x0891B2)
        case .home: Color(hex: 0x2A75D3)
        case .trip: Color(hex: 0x7C3AED)
        }
    }
}

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
        case .clothes: Color(hex: 0x7C3AED)
        case .tech: Color(hex: 0x2A75D3)
        case .toiletries: Color(hex: 0x0891B2)
        case .documents: Color(hex: 0xB45309)
        case .medicine: Color(hex: 0xE11D48)
        case .leisure: Color(hex: 0x0D9488)
        }
    }
}
