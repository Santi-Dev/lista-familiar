import Foundation

/// Fallback for schema fragments the generator cannot type precisely.
enum JSONValue: Codable, Hashable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: JSONValue].self) { self = .object(value) }
        else if let value = try? container.decode([JSONValue].self) { self = .array(value) }
        else { throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value") }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}


struct AuthResponseDto: Codable, Hashable {
    var token: String
    var user: AuthUserDto
}

struct AuthUserDto: Codable, Hashable {
    var id: String
    var email: String
    var name: String
    var familyGroupId: String?
}

struct CreateGroupDto: Codable, Hashable {
    var name: String
}

struct CreateItemDto: Codable, Hashable {
    var name: String
    var quantity: String?
    var category: String
}

struct CreateListDto: Codable, Hashable {
    var name: String
}

struct FamilyGroupDto: Codable, Hashable {
    var id: String
    var name: String
    var inviteCode: String
    var createdById: String?
    var members: [UserPublicDto]
    var createdAt: String
}

struct JoinGroupDto: Codable, Hashable {
    var inviteCode: String
}

struct ListItemDto: Codable, Hashable {
    var id: String
    var shoppingListId: String
    var name: String
    var quantity: String?
    var category: String
    var isPurchased: Bool
    var purchasedBy: JSONValue?
    var purchasedAt: String?
    var addedBy: JSONValue?
    var createdAt: String
    var updatedAt: String
}

struct ListItemsResponseDto: Codable, Hashable {
    var list: ShoppingListSummaryDto
    var items: [ListItemDto]
}

struct ListsResponseDto: Codable, Hashable {
    var items: [ShoppingListSummaryDto]
}

struct LoginDto: Codable, Hashable {
    var email: String
    var password: String
}

struct MeResponseDto: Codable, Hashable {
    var user: AuthUserDto
}

struct ShoppingListSummaryDto: Codable, Hashable {
    var id: String
    var name: String
    var isArchived: Bool
    var createdBy: JSONValue?
    var itemCount: Double
    var purchasedCount: Double
    var createdAt: String
    var updatedAt: String
}

struct SignupDto: Codable, Hashable {
    var email: String
    var password: String
    var name: String
}

struct SuccessDto: Codable, Hashable {
    var success: Bool
}

struct SuccessResponseDto: Codable, Hashable {
    var success: Bool
}

struct UpdateItemDto: Codable, Hashable {
    var name: String?
    var quantity: String?
    var category: String?
    var isPurchased: Bool?
}

struct UpdateListDto: Codable, Hashable {
    var name: String?
    var isArchived: Bool?
}

struct UserPublicDto: Codable, Hashable {
    var id: String
    var name: String
}
