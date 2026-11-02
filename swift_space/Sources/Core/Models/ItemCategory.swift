import SwiftUI

enum ItemCategory: String, CaseIterable {
    case FRUTAS_VERDURAS
    case LACTEOS_HUEVOS
    case CARNES_PESCADO
    case PANADERIA
    case LIMPIEZA
    case BEBIDAS
    case DESPENSA
    case OTROS

    var label: String {
        switch self {
        case .FRUTAS_VERDURAS: return "Frutas y Verduras"
        case .LACTEOS_HUEVOS: return "Lácteos y Huevos"
        case .CARNES_PESCADO: return "Carnes y Pescado"
        case .PANADERIA: return "Panadería"
        case .LIMPIEZA: return "Limpieza"
        case .BEBIDAS: return "Bebidas"
        case .DESPENSA: return "Despensa"
        case .OTROS: return "Otros"
        }
    }

    var symbol: String {
        switch self {
        case .FRUTAS_VERDURAS: return "carrot.fill"
        case .LACTEOS_HUEVOS: return "cup.and.saucer.fill"
        case .CARNES_PESCADO: return "fish.fill"
        case .PANADERIA: return "basket.fill"
        case .LIMPIEZA: return "bubbles.and.sparkles.fill"
        case .BEBIDAS: return "waterbottle.fill"
        case .DESPENSA: return "cabinet.fill"
        case .OTROS: return "tag.fill"
        }
    }

    static func from(_ raw: String) -> ItemCategory {
        ItemCategory(rawValue: raw) ?? .OTROS
    }
}
