import Foundation

struct ListItem: Identifiable, Hashable, Sendable {
    let id: UUID
    let listID: UUID
    var name: String
    var quantity: String?
    var category: ItemCategory
    var isPurchased: Bool
    var purchasedBy: Member?
    var purchasedAt: Date?
    var addedBy: Member?
    var createdAt: Date
    var updatedAt: Date
    /// Nota libre («marca Oatly o Hacendado»).
    var note: String? = nil
    var isUrgent: Bool = false
    /// Quién se encarga de comprarlo (si no hay nadie asignado, cualquiera).
    var assignee: Member? = nil

    /// «Comprado por …» si ya está comprado; si no, «Añadido por …».
    var attribution: String? {
        if isPurchased, let purchasedBy { return "Comprado por \(purchasedBy.name)" }
        if let addedBy { return "Añadido por \(addedBy.name)" }
        return nil
    }
}

/// Datos editables de un artículo: se usa tanto para crear como para editar.
struct ItemDraft: Hashable, Sendable {
    static let maxNoteLength = 280

    var name = ""
    var quantity = ""
    var category: ItemCategory = .other
    var note = ""
    var isUrgent = false
    var assigneeID: UUID?

    init(
        name: String = "", quantity: String = "", category: ItemCategory = .other,
        note: String = "", isUrgent: Bool = false, assigneeID: UUID? = nil
    ) {
        self.name = name
        self.quantity = quantity
        self.category = category
        self.note = note
        self.isUrgent = isUrgent
        self.assigneeID = assigneeID
    }

    init(item: ListItem) {
        self.init(
            name: item.name, quantity: item.quantity ?? "", category: item.category,
            note: item.note ?? "", isUrgent: item.isUrgent, assigneeID: item.assignee?.id)
    }

    var cleanName: String { NameInput.clean(name) }
    /// `nil` si la cantidad está vacía.
    var cleanQuantity: String? {
        let value = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    /// `nil` si la nota está vacía; se recorta a `maxNoteLength` caracteres.
    var cleanNote: String? {
        let value = String(note.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxNoteLength))
        return value.isEmpty ? nil : value
    }
    var isValid: Bool { !cleanName.isEmpty }
}

/// Cantidad escrita como «número + unidad» («2 kg», «1,5 L», «6»). El formulario la muestra con un selector;
/// si el texto de un artículo no encaja (por ejemplo, «3 bolsas»), se conserva tal cual.
struct QuantityParts: Hashable, Sendable {
    /// Unidad de medida del selector y lo que suma o resta cada toque.
    struct Unit: Identifiable, Hashable, Sendable {
        let symbol: String
        let step: Double
        var id: String { symbol }
    }

    /// Unidades que ofrece el formulario.
    static let units = [
        Unit(symbol: "uds", step: 1), Unit(symbol: "kg", step: 0.5), Unit(symbol: "g", step: 50),
        Unit(symbol: "L", step: 0.5), Unit(symbol: "packs", step: 1),
    ]

    var amount: Double
    /// `nil` es una cantidad sin unidad («6»).
    var unit: String?

    /// Paso del selector para la unidad actual.
    var step: Double { Self.units.first { $0.symbol == unit }?.step ?? 1 }

    /// El número sin unidad: «2» o «1,5». La coma decimal es la de España.
    var amountText: String {
        amount.rounded() == amount ? String(Int(amount)) : String(amount).replacingOccurrences(of: ".", with: ",")
    }

    /// «2 kg», «1,5 L» o «6».
    var text: String {
        guard let unit else { return amountText }
        return "\(amountText) \(unit)"
    }

    /// `nil` si el texto no es «número» o «número unidad» con una unidad conocida.
    init?(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let numberEnd = trimmed.firstIndex(where: { !($0.isNumber || $0 == "," || $0 == ".") }) ?? trimmed.endIndex
        guard let amount = Double(trimmed[..<numberEnd].replacingOccurrences(of: ",", with: ".")), amount > 0 else {
            return nil
        }
        let rest = trimmed[numberEnd...].trimmingCharacters(in: .whitespaces)
        if rest.isEmpty {
            self.init(amount: amount, unit: nil)
        } else if let unit = Self.units.first(where: { $0.symbol.lowercased() == rest.lowercased() })?.symbol {
            self.init(amount: amount, unit: unit)
        } else {
            return nil
        }
    }

    init(amount: Double, unit: String?) {
        self.amount = amount
        self.unit = unit
    }
}

/// Artículos de una categoría, en el orden en que se muestran.
struct ItemSection: Identifiable, Hashable, Sendable {
    let category: ItemCategory
    let items: [ListItem]

    var id: ItemCategory { category }
    var pendingCount: Int { items.count { !$0.isPurchased } }
}

extension Array where Element == ListItem {
    /// Agrupa por categoría en el orden de `ItemCategory.allCases`; los pendientes van antes que los comprados
    /// y, entre los pendientes, los urgentes primero.
    func sectioned(filter: ItemCategory? = nil) -> [ItemSection] {
        let grouped = Dictionary(grouping: self) { $0.category }
        return ItemCategory.allCases.compactMap { category in
            guard filter == nil || filter == category,
                  let items = grouped[category], !items.isEmpty else { return nil }
            let sorted = items.sorted { lhs, rhs in
                if lhs.isPurchased != rhs.isPurchased { return !lhs.isPurchased }
                if lhs.isUrgent != rhs.isUrgent { return lhs.isUrgent }
                return lhs.createdAt < rhs.createdAt
            }
            return ItemSection(category: category, items: sorted)
        }
    }

    func pendingCount(in category: ItemCategory) -> Int {
        count { $0.category == category && !$0.isPurchased }
    }
}
