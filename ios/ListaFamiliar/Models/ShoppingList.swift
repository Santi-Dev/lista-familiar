import Foundation

struct ShoppingList: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var isArchived: Bool
    var createdBy: Member?
    var itemCount: Int
    var purchasedCount: Int
    var createdAt: Date
    var updatedAt: Date

    var progress: Double { itemCount == 0 ? 0 : Double(purchasedCount) / Double(itemCount) }
    var isComplete: Bool { itemCount > 0 && purchasedCount == itemCount }
}

/// Cambios parciales de una lista; `nil` significa «no tocar».
struct ListChanges: Hashable, Sendable {
    var name: String?
    var isArchived: Bool?
}

/// Nombre de lista o grupo introducido por el usuario.
enum NameInput {
    static func clean(_ raw: String) -> String { raw.trimmingCharacters(in: .whitespacesAndNewlines) }
    static func isValid(_ raw: String) -> Bool { !clean(raw).isEmpty }
}
