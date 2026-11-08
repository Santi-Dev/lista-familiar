import Foundation

/// Icono temático de una lista. El valor bruto es el que guarda la base de datos.
enum ListIcon: String, CaseIterable, Identifiable, Hashable, Sendable {
    case cart = "CART"
    case food = "FOOD"
    case pharmacy = "PHARMACY"
    case party = "PARTY"
    case cleaning = "CLEANING"
    case home = "HOME"

    var id: String { rawValue }

    /// Valores desconocidos (por ejemplo, de una versión futura) caen en «Compra».
    init(databaseValue: String) {
        self = ListIcon(rawValue: databaseValue) ?? .cart
    }

    var title: String {
        switch self {
        case .cart: "Compra"
        case .food: "Comida"
        case .pharmacy: "Farmacia"
        case .party: "Fiesta"
        case .cleaning: "Limpieza"
        case .home: "Hogar"
        }
    }

    var symbol: String {
        switch self {
        case .cart: "cart.fill"
        case .food: "fork.knife"
        case .pharmacy: "cross.case.fill"
        case .party: "party.popper.fill"
        case .cleaning: "bubbles.and.sparkles.fill"
        case .home: "house.fill"
        }
    }
}

struct ShoppingList: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var isArchived: Bool
    var createdBy: Member?
    var itemCount: Int
    var purchasedCount: Int
    var createdAt: Date
    var updatedAt: Date
    var icon: ListIcon = .cart
    /// Tienda donde se compra (opcional), por ejemplo «Mercadona».
    var store: String? = nil
    /// Las listas fijadas salen antes que las demás.
    var isPinned: Bool = false

    var progress: Double { itemCount == 0 ? 0 : Double(purchasedCount) / Double(itemCount) }
    var isComplete: Bool { itemCount > 0 && purchasedCount == itemCount }
}

/// Datos editables de una lista: se usa tanto para crear como para editar.
struct ListDraft: Hashable, Sendable {
    static let maxStoreLength = 40

    var name = ""
    var icon: ListIcon = .cart
    var store = ""
    var isPinned = false

    init(name: String = "", icon: ListIcon = .cart, store: String = "", isPinned: Bool = false) {
        self.name = name
        self.icon = icon
        self.store = store
        self.isPinned = isPinned
    }

    init(list: ShoppingList) {
        self.init(name: list.name, icon: list.icon, store: list.store ?? "", isPinned: list.isPinned)
    }

    var cleanName: String { NameInput.clean(name) }
    /// `nil` si la tienda está vacía.
    var cleanStore: String? {
        let value = String(store.trimmingCharacters(in: .whitespacesAndNewlines).prefix(Self.maxStoreLength))
        return value.isEmpty ? nil : value
    }
    var isValid: Bool { !cleanName.isEmpty }
}

/// Cambios parciales de una lista; `nil` significa «no tocar».
struct ListChanges: Hashable, Sendable {
    var name: String?
    var isArchived: Bool?
    var icon: ListIcon?
    /// Doble opcional: `.some(nil)` borra la tienda, `nil` no la toca.
    var store: String??
    var isPinned: Bool?

    init(name: String? = nil, isArchived: Bool? = nil, icon: ListIcon? = nil, store: String?? = nil, isPinned: Bool? = nil) {
        self.name = name
        self.isArchived = isArchived
        self.icon = icon
        self.store = store
        self.isPinned = isPinned
    }

    /// Todos los datos editables de una lista a la vez.
    init(draft: ListDraft) {
        self.init(name: draft.cleanName, icon: draft.icon, store: .some(draft.cleanStore), isPinned: draft.isPinned)
    }
}

/// Nombre de lista o grupo introducido por el usuario.
enum NameInput {
    static func clean(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func isValid(_ raw: String) -> Bool { !clean(raw).isEmpty }
}
