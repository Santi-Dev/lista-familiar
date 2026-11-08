import Foundation

/// Rol de una persona dentro del grupo familiar. El valor bruto es el que guarda la base de datos.
///
/// - Propietario: crea el grupo y gestiona a todos los demás.
/// - Administrador: gestiona editores y lectores.
/// - Editor: añade, edita y marca artículos y listas.
/// - Solo lectura: consulta las listas, pero no las cambia.
enum MemberRole: String, CaseIterable, Identifiable, Hashable, Sendable {
    case owner = "OWNER"
    case admin = "ADMIN"
    case editor = "EDITOR"
    case viewer = "VIEWER"

    var id: String { rawValue }

    /// Valores desconocidos (por ejemplo, de una versión futura) se tratan como editor.
    init(databaseValue: String) {
        self = MemberRole(rawValue: databaseValue) ?? .editor
    }

    var title: String {
        switch self {
        case .owner: "Propietario"
        case .admin: "Administrador"
        case .editor: "Editor"
        case .viewer: "Solo lectura"
        }
    }

    var summary: String {
        switch self {
        case .owner: "Gestiona el grupo y los roles"
        case .admin: "Gestiona editores y lectores"
        case .editor: "Añade y marca artículos"
        case .viewer: "Solo consulta las listas"
        }
    }

    /// Puede crear, editar y marcar listas y artículos.
    var canEdit: Bool { self != .viewer }

    /// Puede cambiar el rol de otras personas.
    var canManageRoles: Bool { self == .owner || self == .admin }

    /// Roles que esta persona puede asignar a alguien que hoy es `target` (vacío si no puede cambiarlo).
    /// Mismas reglas que la función SQL `set_member_role`: el propietario no cambia y los administradores
    /// solo gestionan editores y lectores.
    func assignableRoles(to target: MemberRole) -> [MemberRole] {
        switch (self, target) {
        case (_, .owner): []
        case (.owner, _): [.admin, .editor, .viewer]
        case (.admin, .editor), (.admin, .viewer): [.editor, .viewer]
        default: []
        }
    }
}
