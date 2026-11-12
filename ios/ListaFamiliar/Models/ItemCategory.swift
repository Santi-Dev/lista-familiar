import Foundation

/// Categorías de artículo. El valor bruto es el que guarda la base de datos.
enum ItemCategory: String, CaseIterable, Identifiable, Hashable, Sendable, Codable {
    case produce = "FRUTAS_VERDURAS"
    case dairyEggs = "LACTEOS_HUEVOS"
    case meatFish = "CARNES_PESCADO"
    case bakery = "PANADERIA"
    case cleaning = "LIMPIEZA"
    case drinks = "BEBIDAS"
    case pantry = "DESPENSA"
    case other = "OTROS"
    // Categorías de las listas de viaje.
    case clothes = "ROPA"
    case tech = "TECNOLOGIA"
    case toiletries = "ASEO"
    case documents = "DOCUMENTOS"
    case medicine = "BOTIQUIN"
    case leisure = "OCIO"

    var id: String { rawValue }

    /// Valores desconocidos (por ejemplo, de una versión futura) caen en «Otros».
    init(databaseValue: String) {
        self = ItemCategory(rawValue: databaseValue) ?? .other
    }

    var title: String {
        switch self {
        case .produce: "Frutas y Verduras"
        case .dairyEggs: "Lácteos y Huevos"
        case .meatFish: "Carnes y Pescado"
        case .bakery: "Panadería"
        case .cleaning: "Limpieza"
        case .drinks: "Bebidas"
        case .pantry: "Despensa"
        case .other: "Otros"
        case .clothes: "Ropa"
        case .tech: "Tecnología"
        case .toiletries: "Aseo"
        case .documents: "Documentos"
        case .medicine: "Botiquín"
        case .leisure: "Ocio"
        }
    }

    var symbol: String {
        switch self {
        case .produce: "carrot.fill"
        case .dairyEggs: "cup.and.saucer.fill"
        case .meatFish: "fish.fill"
        case .bakery: "basket.fill"
        case .cleaning: "bubbles.and.sparkles.fill"
        case .drinks: "waterbottle.fill"
        case .pantry: "cabinet.fill"
        case .other: "tag.fill"
        case .clothes: "tshirt.fill"
        case .tech: "laptopcomputer"
        case .toiletries: "shower.fill"
        case .documents: "doc.text.fill"
        case .medicine: "cross.case.fill"
        case .leisure: "book.fill"
        }
    }
}
