import Foundation

/// Usuario con sesión iniciada.
struct User: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var email: String
    var familyGroupID: UUID?

    var hasFamilyGroup: Bool { familyGroupID != nil }

    var asMember: Member { Member(id: id, name: name) }
}

/// Referencia pública a una persona del grupo (nombre visible para los demás miembros).
struct Member: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
}
