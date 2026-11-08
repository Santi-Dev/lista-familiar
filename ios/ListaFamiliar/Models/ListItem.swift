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

    /// «Comprado por …» si ya está comprado; si no, «Añadido por …».
    var attribution: String? {
        if isPurchased, let purchasedBy { return "Comprado por \(purchasedBy.name)" }
        if let addedBy { return "Añadido por \(addedBy.name)" }
        return nil
    }
}

/// Datos editables de un artículo: se usa tanto para crear como para editar.
struct ItemDraft: Hashable, Sendable {
    var name = ""
    var quantity = ""
    var category: ItemCategory = .other

    init(name: String = "", quantity: String = "", category: ItemCategory = .other) {
        self.name = name
        self.quantity = quantity
        self.category = category
    }

    init(item: ListItem) {
        self.init(name: item.name, quantity: item.quantity ?? "", category: item.category)
    }

    var cleanName: String { NameInput.clean(name) }
    /// `nil` si la cantidad está vacía.
    var cleanQuantity: String? {
        let value = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    var isValid: Bool { !cleanName.isEmpty }
}

/// Artículos de una categoría, en el orden en que se muestran.
struct ItemSection: Identifiable, Hashable, Sendable {
    let category: ItemCategory
    let items: [ListItem]

    var id: ItemCategory { category }
    var pendingCount: Int { items.count { !$0.isPurchased } }
}

extension Array where Element == ListItem {
    /// Agrupa por categoría en el orden de `ItemCategory.allCases`; los pendientes van antes que los comprados.
    func sectioned(filter: ItemCategory? = nil) -> [ItemSection] {
        let grouped = Dictionary(grouping: self) { $0.category }
        return ItemCategory.allCases.compactMap { category in
            guard filter == nil || filter == category,
                  let items = grouped[category], !items.isEmpty else { return nil }
            let sorted = items.sorted { lhs, rhs in
                if lhs.isPurchased != rhs.isPurchased { return !lhs.isPurchased }
                return lhs.createdAt < rhs.createdAt
            }
            return ItemSection(category: category, items: sorted)
        }
    }

    func pendingCount(in category: ItemCategory) -> Int {
        count { $0.category == category && !$0.isPurchased }
    }
}
