import Foundation

struct FamilyGroup: Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    var inviteCode: String
    var createdByID: UUID?
    var members: [Member]
    var createdAt: Date

    func isCreator(_ member: Member) -> Bool { member.id == createdByID }

    /// Texto que se comparte para invitar a alguien al grupo.
    var invitationMessage: String {
        "Únete a nuestra lista de la compra en Lista Familiar con el código: \(inviteCode)"
    }
}

/// Reglas del código de invitación (los genera `gen_invite_code()` en la base de datos).
enum InviteCode {
    static let length = 6

    /// Mayúsculas, sin espacios ni símbolos y como máximo `length` caracteres.
    static func normalize(_ raw: String) -> String {
        String(raw.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(length))
    }

    static func isComplete(_ code: String) -> Bool { code.count == length }
}
