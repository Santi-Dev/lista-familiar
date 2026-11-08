import Foundation

// Filas de Postgres (snake_case y relaciones embebidas) y su traducción a los modelos de la app.
// Solo las usa `SupabaseBackend`.

struct MemberRecord: Decodable, Sendable {
    let id: UUID
    let name: String
    var model: Member { Member(id: id, name: name) }
}

struct ProfileRecord: Decodable, Sendable {
    static let columns = "id,name,family_group_id"
    let id: UUID
    let name: String
    let familyGroupID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, name
        case familyGroupID = "family_group_id"
    }
}

struct GroupRecord: Decodable, Sendable {
    // `family_groups` y `profiles` tienen dos relaciones (miembros y creador): el hint evita PGRST201.
    static let columns = "id,name,invite_code,created_by_id,created_at,members:profiles!family_group_id(id,name)"
    let id: UUID
    let name: String
    let inviteCode: String
    let createdByID: UUID?
    let createdAt: String
    let members: [MemberRecord]

    enum CodingKeys: String, CodingKey {
        case id, name, members
        case inviteCode = "invite_code"
        case createdByID = "created_by_id"
        case createdAt = "created_at"
    }

    var model: FamilyGroup {
        FamilyGroup(
            id: id, name: name, inviteCode: inviteCode, createdByID: createdByID,
            members: members.map(\.model).sorted { $0.name.localizedCompare($1.name) == .orderedAscending },
            createdAt: PostgresDate.parse(createdAt))
    }
}

struct ListRecord: Decodable, Sendable {
    static let columns = "id,name,is_archived,created_at,updated_at,created_by:profiles!created_by_id(id,name),list_items(is_purchased)"
    let id: UUID
    let name: String
    let isArchived: Bool
    let createdAt: String
    let updatedAt: String
    let createdBy: MemberRecord?
    let items: [PurchaseFlag]?

    struct PurchaseFlag: Decodable, Sendable {
        let isPurchased: Bool
        enum CodingKeys: String, CodingKey { case isPurchased = "is_purchased" }
    }

    enum CodingKeys: String, CodingKey {
        case id, name
        case isArchived = "is_archived"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case createdBy = "created_by"
        case items = "list_items"
    }

    var model: ShoppingList {
        let flags = items ?? []
        return ShoppingList(
            id: id, name: name, isArchived: isArchived, createdBy: createdBy?.model,
            itemCount: flags.count, purchasedCount: flags.count(where: \.isPurchased),
            createdAt: PostgresDate.parse(createdAt), updatedAt: PostgresDate.parse(updatedAt))
    }
}

struct ItemRecord: Decodable, Sendable {
    static let columns = "id,shopping_list_id,name,quantity,category,is_purchased,purchased_at,created_at,updated_at,added_by:profiles!added_by_id(id,name),purchased_by:profiles!purchased_by_id(id,name)"
    let id: UUID
    let listID: UUID
    let name: String
    let quantity: String?
    let category: String
    let isPurchased: Bool
    let purchasedAt: String?
    let createdAt: String
    let updatedAt: String
    let addedBy: MemberRecord?
    let purchasedBy: MemberRecord?

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category
        case listID = "shopping_list_id"
        case isPurchased = "is_purchased"
        case purchasedAt = "purchased_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case addedBy = "added_by"
        case purchasedBy = "purchased_by"
    }

    var model: ListItem {
        ListItem(
            id: id, listID: listID, name: name, quantity: quantity,
            category: ItemCategory(databaseValue: category), isPurchased: isPurchased,
            purchasedBy: purchasedBy?.model, purchasedAt: purchasedAt.map(PostgresDate.parse),
            addedBy: addedBy?.model, createdAt: PostgresDate.parse(createdAt), updatedAt: PostgresDate.parse(updatedAt))
    }
}

// MARK: - Escrituras

struct ListInsert: Encodable, Sendable {
    let name: String
    let familyGroupID: UUID
    let createdByID: UUID

    enum CodingKeys: String, CodingKey {
        case name
        case familyGroupID = "family_group_id"
        case createdByID = "created_by_id"
    }
}

struct ListUpdate: Encodable, Sendable {
    let name: String?
    let isArchived: Bool?

    init(_ changes: ListChanges) {
        name = changes.name
        isArchived = changes.isArchived
    }

    enum CodingKeys: String, CodingKey {
        case name
        case isArchived = "is_archived"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        try container.encodeIfPresent(isArchived, forKey: .isArchived)
    }
}

struct ItemInsert: Encodable, Sendable {
    let listID: UUID
    let name: String
    let quantity: String?
    let category: String

    init(listID: UUID, draft: ItemDraft) {
        self.listID = listID
        name = draft.cleanName
        quantity = draft.cleanQuantity
        category = draft.category.rawValue
    }

    enum CodingKeys: String, CodingKey {
        case name, quantity, category
        case listID = "shopping_list_id"
    }
}

struct ItemUpdate: Encodable, Sendable {
    /// Doble opcional para la cantidad: `.some(nil)` la borra, `nil` no la toca.
    var name: String?
    var quantity: String??
    var category: String?
    var isPurchased: Bool?

    init(draft: ItemDraft) {
        name = draft.cleanName
        quantity = .some(draft.cleanQuantity)
        category = draft.category.rawValue
    }

    init(isPurchased: Bool) {
        self.isPurchased = isPurchased
    }

    enum CodingKeys: String, CodingKey {
        case name, quantity, category
        case isPurchased = "is_purchased"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(name, forKey: .name)
        if let quantity { try container.encode(quantity, forKey: .quantity) }
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(isPurchased, forKey: .isPurchased)
    }
}

// MARK: - Fechas

/// `timestamptz` de PostgREST: ISO 8601 con o sin fracción de segundo.
enum PostgresDate {
    // `ISO8601DateFormatter` es seguro entre hilos y admite «+00:00» y fracciones de 6 dígitos.
    nonisolated(unsafe) private static let withFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    nonisolated(unsafe) private static let plain = ISO8601DateFormatter()

    static func parse(_ text: String) -> Date {
        withFraction.date(from: text) ?? plain.date(from: text) ?? .distantPast
    }
}
