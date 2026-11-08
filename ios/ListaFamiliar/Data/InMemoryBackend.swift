import Foundation

/// Backend completo en memoria, sin red. Se usa en los `#Preview`, en las capturas de CI
/// (`-PREVIEW_SCREEN`), en el modo demo (`-DEMO`) y como doble de pruebas en los tests.
actor InMemoryBackend: Backend {
    struct Account: Sendable {
        var user: User
        var password: String
    }

    private var accounts: [Account]
    private var currentUserID: UUID?
    private var groups: [FamilyGroup]
    private var lists: [ShoppingList]
    private var items: [ListItem]
    private let clock: @Sendable () -> Date

    /// Error que se lanza en la siguiente llamada (para probar estados de error).
    private var nextError: AppError?
    /// Número de llamadas recibidas (para comprobar en los tests que se reutiliza la caché).
    private(set) var callCount = 0
    /// Correos a los que se ha pedido restablecer la contraseña (para los tests).
    private(set) var passwordResetEmails: [String] = []

    init(
        accounts: [Account] = [],
        currentUserID: UUID? = nil,
        groups: [FamilyGroup] = [],
        lists: [ShoppingList] = [],
        items: [ListItem] = [],
        clock: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.accounts = accounts
        self.currentUserID = currentUserID
        self.groups = groups
        self.lists = lists
        self.items = items
        self.clock = clock
    }

    func failNextCall(with error: AppError) { nextError = error }

    private func step() throws {
        callCount += 1
        if let error = nextError {
            nextError = nil
            throw error
        }
    }

    private func requireUser() throws -> User {
        guard let id = currentUserID, let account = accounts.first(where: { $0.user.id == id }) else {
            throw AppError.server("No autenticado")
        }
        return account.user
    }

    private func updateUser(_ user: User) {
        if let index = accounts.firstIndex(where: { $0.user.id == user.id }) { accounts[index].user = user }
    }

    /// El usuario de la sesión, si puede editar (los lectores solo consultan).
    @discardableResult
    private func requireEditor() throws -> User {
        let user = try requireUser()
        if let group = groups.first(where: { $0.id == user.familyGroupID }), !group.role(of: user.id).canEdit {
            throw AppError.forbidden
        }
        return user
    }

    // MARK: - Sesión

    func restoreSession() async throws -> User? {
        try step()
        return try? requireUser()
    }

    func signIn(email: String, password: String) async throws -> User {
        try step()
        guard let account = accounts.first(where: {
            $0.user.email.caseInsensitiveCompare(email) == .orderedSame && $0.password == password
        }) else { throw AppError.invalidCredentials }
        currentUserID = account.user.id
        return account.user
    }

    func signUp(name: String, email: String, password: String) async throws -> User {
        try step()
        guard !accounts.contains(where: { $0.user.email.caseInsensitiveCompare(email) == .orderedSame }) else {
            throw AppError.emailAlreadyRegistered
        }
        let user = User(id: UUID(), name: name, email: email, familyGroupID: nil)
        accounts.append(Account(user: user, password: password))
        currentUserID = user.id
        return user
    }

    func signOut() async { currentUserID = nil }

    func sendPasswordReset(email: String) async throws {
        try step()
        // Igual que el servidor real: no se revela si el correo tiene cuenta.
        passwordResetEmails.append(email)
    }

    func deleteAccount() async throws {
        try step()
        let user = try requireUser()
        try await leaveGroup()
        accounts.removeAll { $0.user.id == user.id }
        currentUserID = nil
    }

    // MARK: - Grupo familiar

    func fetchGroup() async throws -> FamilyGroup? {
        try step()
        let user = try requireUser()
        return groups.first { $0.id == user.familyGroupID }
    }

    func createGroup(named name: String) async throws -> FamilyGroup {
        try step()
        var user = try requireUser()
        guard !user.hasFamilyGroup else { throw AppError.server("Ya perteneces a un grupo") }
        let group = FamilyGroup(
            id: UUID(), name: NameInput.clean(name), inviteCode: Self.makeInviteCode(),
            createdByID: user.id, members: [user.asMember], createdAt: clock(), roles: [user.id: .owner])
        groups.append(group)
        user.familyGroupID = group.id
        updateUser(user)
        return group
    }

    func joinGroup(code: String) async throws -> FamilyGroup {
        try step()
        var user = try requireUser()
        guard !user.hasFamilyGroup else { throw AppError.server("Ya perteneces a un grupo") }
        guard let index = groups.firstIndex(where: { $0.inviteCode == InviteCode.normalize(code) }) else {
            throw AppError.server("Código de invitación no válido")
        }
        groups[index].members.append(user.asMember)
        groups[index].roles[user.id] = .editor
        user.familyGroupID = groups[index].id
        updateUser(user)
        return groups[index]
    }

    func leaveGroup() async throws {
        try step()
        var user = try requireUser()
        guard let groupID = user.familyGroupID, let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        let leavingRole = groups[index].role(of: user.id)
        groups[index].members.removeAll { $0.id == user.id }
        groups[index].roles[user.id] = nil
        if groups[index].members.isEmpty {
            groups.remove(at: index)
            let listIDs = Set(lists.map(\.id))
            lists.removeAll()
            items.removeAll { listIDs.contains($0.listID) }
        } else if leavingRole == .owner {
            // Igual que `leave_family_group`: hereda el grupo un administrador o, si no, quien lleva más tiempo.
            let successor = groups[index].members.first { groups[index].role(of: $0.id) == .admin }
                ?? groups[index].members[0]
            groups[index].roles[successor.id] = .owner
        }
        user.familyGroupID = nil
        updateUser(user)
    }

    func setMemberRole(_ role: MemberRole, memberID: UUID) async throws -> FamilyGroup {
        try step()
        let user = try requireUser()
        guard let index = groups.firstIndex(where: { $0.id == user.familyGroupID }) else { throw AppError.notInGroup }
        let actorRole = groups[index].role(of: user.id)
        guard actorRole.canManageRoles else { throw AppError.server("No tienes permiso para cambiar roles.") }
        guard groups[index].members.contains(where: { $0.id == memberID }) else {
            throw AppError.server("Esa persona no pertenece a tu grupo.")
        }
        let targetRole = groups[index].role(of: memberID)
        guard actorRole.assignableRoles(to: targetRole).contains(role) else {
            throw AppError.server(targetRole == .owner
                ? "El propietario no se puede cambiar."
                : "Solo el propietario gestiona a los administradores.")
        }
        groups[index].roles[memberID] = role
        return groups[index]
    }

    private static func makeInviteCode() -> String {
        let chars = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return String((0..<InviteCode.length).map { _ in chars.randomElement()! })
    }

    // MARK: - Listas

    private func summary(_ list: ShoppingList) -> ShoppingList {
        var list = list
        let listItems = items.filter { $0.listID == list.id }
        list.itemCount = listItems.count
        list.purchasedCount = listItems.count(where: \.isPurchased)
        return list
    }

    private func touch(listID: UUID) {
        if let index = lists.firstIndex(where: { $0.id == listID }) { lists[index].updatedAt = clock() }
    }

    func fetchLists(archived: Bool) async throws -> [ShoppingList] {
        try step()
        _ = try requireUser()
        return lists.filter { $0.isArchived == archived }.map(summary).sorted { $0.updatedAt > $1.updatedAt }
    }

    func fetchList(id: UUID) async throws -> ShoppingList {
        try step()
        guard let list = lists.first(where: { $0.id == id }) else { throw AppError.notFound }
        return summary(list)
    }

    func createList(_ draft: ListDraft, groupID: UUID) async throws -> ShoppingList {
        try step()
        let user = try requireEditor()
        let list = ShoppingList(
            id: UUID(), name: draft.cleanName, isArchived: false, createdBy: user.asMember,
            itemCount: 0, purchasedCount: 0, createdAt: clock(), updatedAt: clock(),
            icon: draft.icon, store: draft.cleanStore, isPinned: draft.isPinned)
        lists.append(list)
        return list
    }

    func updateList(id: UUID, _ changes: ListChanges) async throws -> ShoppingList {
        try step()
        try requireEditor()
        guard let index = lists.firstIndex(where: { $0.id == id }) else { throw AppError.notFound }
        if let name = changes.name { lists[index].name = name }
        if let isArchived = changes.isArchived { lists[index].isArchived = isArchived }
        if let icon = changes.icon { lists[index].icon = icon }
        if let store = changes.store { lists[index].store = store }
        if let isPinned = changes.isPinned { lists[index].isPinned = isPinned }
        lists[index].updatedAt = clock()
        return summary(lists[index])
    }

    func deleteList(id: UUID) async throws {
        try step()
        try requireEditor()
        lists.removeAll { $0.id == id }
        items.removeAll { $0.listID == id }
    }

    // MARK: - Artículos

    func fetchItems(listID: UUID) async throws -> [ListItem] {
        try step()
        guard lists.contains(where: { $0.id == listID }) else { throw AppError.notFound }
        return items.filter { $0.listID == listID }.sorted { $0.createdAt < $1.createdAt }
    }

    /// La persona asignada tiene que ser del grupo (igual que el trigger `item_before_write`).
    private func assignee(_ id: UUID?) throws -> Member? {
        guard let id else { return nil }
        guard let member = groups.flatMap(\.members).first(where: { $0.id == id }) else {
            throw AppError.server("La persona asignada no pertenece al grupo.")
        }
        return member
    }

    func createItem(in listID: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try step()
        let user = try requireEditor()
        guard lists.contains(where: { $0.id == listID }) else { throw AppError.notFound }
        let assigned = try assignee(draft.assigneeID)
        let item = ListItem(
            id: UUID(), listID: listID, name: draft.cleanName, quantity: draft.cleanQuantity,
            category: draft.category, isPurchased: false, purchasedBy: nil, purchasedAt: nil,
            addedBy: user.asMember, createdAt: clock(), updatedAt: clock(),
            note: draft.cleanNote, isUrgent: draft.isUrgent, assignee: assigned)
        items.append(item)
        touch(listID: listID)
        return item
    }

    func updateItem(id: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try step()
        try requireEditor()
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw AppError.notFound }
        items[index].name = draft.cleanName
        items[index].quantity = draft.cleanQuantity
        items[index].category = draft.category
        items[index].note = draft.cleanNote
        items[index].isUrgent = draft.isUrgent
        items[index].assignee = try assignee(draft.assigneeID)
        items[index].updatedAt = clock()
        touch(listID: items[index].listID)
        return items[index]
    }

    func setPurchased(_ isPurchased: Bool, itemID: UUID) async throws -> ListItem {
        try step()
        let user = try requireEditor()
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { throw AppError.notFound }
        items[index].isPurchased = isPurchased
        items[index].purchasedBy = isPurchased ? user.asMember : nil
        items[index].purchasedAt = isPurchased ? clock() : nil
        items[index].updatedAt = clock()
        touch(listID: items[index].listID)
        return items[index]
    }

    func deleteItem(id: UUID) async throws {
        try step()
        try requireEditor()
        guard let item = items.first(where: { $0.id == id }) else { return }
        items.removeAll { $0.id == id }
        touch(listID: item.listID)
    }

    // MARK: - Tiempo real

    nonisolated func changes() -> AsyncStream<Void> {
        // Sin servidor no hay cambios externos: el stream queda abierto hasta que se cancela.
        AsyncStream { _ in }
    }
}
