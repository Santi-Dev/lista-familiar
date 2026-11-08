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
            createdByID: user.id, members: [user.asMember], createdAt: clock())
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
        user.familyGroupID = groups[index].id
        updateUser(user)
        return groups[index]
    }

    func leaveGroup() async throws {
        try step()
        var user = try requireUser()
        guard let groupID = user.familyGroupID, let index = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[index].members.removeAll { $0.id == user.id }
        if groups[index].members.isEmpty {
            groups.remove(at: index)
            let listIDs = Set(lists.map(\.id))
            lists.removeAll()
            items.removeAll { listIDs.contains($0.listID) }
        }
        user.familyGroupID = nil
        updateUser(user)
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

    func createList(named name: String, groupID: UUID) async throws -> ShoppingList {
        try step()
        let user = try requireUser()
        let list = ShoppingList(
            id: UUID(), name: NameInput.clean(name), isArchived: false, createdBy: user.asMember,
            itemCount: 0, purchasedCount: 0, createdAt: clock(), updatedAt: clock())
        lists.append(list)
        return list
    }

    func updateList(id: UUID, _ changes: ListChanges) async throws -> ShoppingList {
        try step()
        guard let index = lists.firstIndex(where: { $0.id == id }) else { throw AppError.notFound }
        if let name = changes.name { lists[index].name = name }
        if let isArchived = changes.isArchived { lists[index].isArchived = isArchived }
        lists[index].updatedAt = clock()
        return summary(lists[index])
    }

    func deleteList(id: UUID) async throws {
        try step()
        lists.removeAll { $0.id == id }
        items.removeAll { $0.listID == id }
    }

    // MARK: - Artículos

    func fetchItems(listID: UUID) async throws -> [ListItem] {
        try step()
        guard lists.contains(where: { $0.id == listID }) else { throw AppError.notFound }
        return items.filter { $0.listID == listID }.sorted { $0.createdAt < $1.createdAt }
    }

    func createItem(in listID: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try step()
        let user = try requireUser()
        guard lists.contains(where: { $0.id == listID }) else { throw AppError.notFound }
        let item = ListItem(
            id: UUID(), listID: listID, name: draft.cleanName, quantity: draft.cleanQuantity,
            category: draft.category, isPurchased: false, purchasedBy: nil, purchasedAt: nil,
            addedBy: user.asMember, createdAt: clock(), updatedAt: clock())
        items.append(item)
        touch(listID: listID)
        return item
    }

    func updateItem(id: UUID, _ draft: ItemDraft) async throws -> ListItem {
        try step()
        guard let index = items.firstIndex(where: { $0.id == id }) else { throw AppError.notFound }
        items[index].name = draft.cleanName
        items[index].quantity = draft.cleanQuantity
        items[index].category = draft.category
        items[index].updatedAt = clock()
        touch(listID: items[index].listID)
        return items[index]
    }

    func setPurchased(_ isPurchased: Bool, itemID: UUID) async throws -> ListItem {
        try step()
        let user = try requireUser()
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
