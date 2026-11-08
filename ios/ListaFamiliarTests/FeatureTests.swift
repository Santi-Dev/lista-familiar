import Foundation
import Testing
@testable import ListaFamiliar

// Tests de las funciones que llegaron con el diseño de Stitch: artículos y listas más ricos, roles de miembro
// y recuperación de contraseña.

@Suite("Cantidades, borradores y roles")
struct RichModelTests {
    @Test("La cantidad se descompone en número y unidad", arguments: [
        ("2 kg", 2.0, "kg"),
        ("1,5 L", 1.5, "L"),
        ("500 g", 500.0, "g"),
        ("3 UDS", 3.0, "uds"),
        ("2 l", 2.0, "L"),
    ])
    func quantityParts(text: String, amount: Double, unit: String) throws {
        let parts = try #require(QuantityParts(text: text))
        #expect(parts.amount == amount)
        #expect(parts.unit == unit)
    }

    @Test func quantityWithoutUnit() throws {
        let parts = try #require(QuantityParts(text: "6"))
        #expect(parts.amount == 6)
        #expect(parts.unit == nil)
        #expect(parts.text == "6")
    }

    @Test("Si el texto no encaja, la cantidad se queda como texto libre", arguments: ["", "bolsas", "3 bolsas", "0", "dos"])
    func quantityPartsRejectsFreeText(text: String) {
        #expect(QuantityParts(text: text) == nil)
    }

    @Test func quantityTextAndStep() {
        #expect(QuantityParts(amount: 1.5, unit: "kg").text == "1,5 kg")
        #expect(QuantityParts(amount: 2, unit: nil).text == "2")
        #expect(QuantityParts(amount: 1, unit: "g").step == 50)
        #expect(QuantityParts(amount: 1, unit: nil).step == 1)
    }

    @Test func draftCleansNote() {
        var draft = ItemDraft(name: "Leche", note: "  Sin lactosa ")
        #expect(draft.cleanNote == "Sin lactosa")
        draft.note = "   "
        #expect(draft.cleanNote == nil)
        draft.note = String(repeating: "x", count: ItemDraft.maxNoteLength + 20)
        #expect(draft.cleanNote?.count == ItemDraft.maxNoteLength)
    }

    @Test func draftFromItemKeepsEverything() {
        let marta = Member(id: UUID(), name: "Marta")
        let item = ListItem(
            id: UUID(), listID: UUID(), name: "Leche", quantity: "2 L", category: .dairyEggs, isPurchased: false,
            purchasedBy: nil, purchasedAt: nil, addedBy: nil, createdAt: .now, updatedAt: .now,
            note: "Sin lactosa", isUrgent: true, assignee: marta)
        let draft = ItemDraft(item: item)
        #expect(draft.note == "Sin lactosa")
        #expect(draft.isUrgent)
        #expect(draft.assigneeID == marta.id)
    }

    @Test("Los urgentes van antes entre los pendientes y los comprados al final")
    func urgentItemsGoFirst() {
        let now = Date()
        func item(_ name: String, urgent: Bool, bought: Bool = false, minutes: Double) -> ListItem {
            ListItem(id: UUID(), listID: UUID(), name: name, quantity: nil, category: .pantry, isPurchased: bought,
                     purchasedBy: nil, purchasedAt: nil, addedBy: nil,
                     createdAt: now.addingTimeInterval(minutes * 60), updatedAt: now, isUrgent: urgent)
        }
        let items = [
            item("Arroz", urgent: false, minutes: 0),
            item("Sal", urgent: true, bought: true, minutes: 1),
            item("Aceite", urgent: true, minutes: 2),
        ]
        #expect(items.sectioned()[0].items.map(\.name) == ["Aceite", "Arroz", "Sal"])
    }

    @Test func listDraftCleansNameAndStore() {
        var draft = ListDraft(name: " Barbacoa ", icon: .party, store: "  Lidl ")
        #expect(draft.cleanName == "Barbacoa")
        #expect(draft.cleanStore == "Lidl")
        #expect(draft.isValid)
        draft.store = "   "
        #expect(draft.cleanStore == nil)
        draft.store = String(repeating: "t", count: ListDraft.maxStoreLength + 10)
        #expect(draft.cleanStore?.count == ListDraft.maxStoreLength)
        #expect(!ListDraft(name: "  ").isValid)
    }

    @Test func unknownListIconFallsBackToCart() {
        #expect(ListIcon(databaseValue: "NAVE") == .cart)
        #expect(ListIcon(databaseValue: "PARTY") == .party)
    }

    @Test("Quién puede cambiar el rol de quién")
    func roleRules() {
        #expect(MemberRole.owner.assignableRoles(to: .editor) == [.admin, .editor, .viewer])
        #expect(MemberRole.owner.assignableRoles(to: .owner).isEmpty)
        #expect(MemberRole.admin.assignableRoles(to: .viewer) == [.editor, .viewer])
        #expect(MemberRole.admin.assignableRoles(to: .admin).isEmpty)
        #expect(MemberRole.admin.assignableRoles(to: .owner).isEmpty)
        #expect(MemberRole.editor.assignableRoles(to: .viewer).isEmpty)
        #expect(MemberRole.viewer.assignableRoles(to: .editor).isEmpty)
    }

    @Test func rolePermissions() {
        #expect(MemberRole.owner.canEdit && MemberRole.admin.canEdit && MemberRole.editor.canEdit)
        #expect(!MemberRole.viewer.canEdit)
        #expect(MemberRole.owner.canManageRoles && MemberRole.admin.canManageRoles)
        #expect(!MemberRole.editor.canManageRoles && !MemberRole.viewer.canManageRoles)
        #expect(MemberRole(databaseValue: "ADMIN") == .admin)
        #expect(MemberRole(databaseValue: "???") == .editor)
    }

    @Test func groupRoleFallsBackToCreatorOrEditor() {
        let creator = UUID(), other = UUID(), viewer = UUID()
        let group = FamilyGroup(
            id: UUID(), name: "Casa", inviteCode: "ABC123", createdByID: creator,
            members: [], createdAt: .now, roles: [viewer: .viewer])
        #expect(group.role(of: creator) == .owner)
        #expect(group.role(of: other) == .editor)
        #expect(group.role(of: viewer) == .viewer)
    }

    @Test func signUpNeedsConfirmationAndPrivacy() {
        func can(_ confirmation: String, _ accepted: Bool) -> Bool {
            Credentials.canSignUp(
                name: "Lucía", email: "lucia@example.com", password: "12345678",
                confirmation: confirmation, acceptedPrivacy: accepted)
        }
        #expect(can("12345678", true))
        #expect(!can("12345679", true))
        #expect(!can("", true))
        #expect(!can("12345678", false))
    }
}

@MainActor
@Suite("Funciones nuevas en los stores")
struct RichStoreTests {
    // MARK: Recuperar contraseña

    @Test func passwordResetUsesTheTrimmedEmail() async throws {
        let backend = SampleData.backend(signedIn: false)
        let store = SessionStore(backend: backend, user: nil)
        try await store.sendPasswordReset(email: " ana@example.com ")
        #expect(await backend.passwordResetEmails == ["ana@example.com"])
    }

    @Test func passwordResetReportsErrors() async {
        let backend = SampleData.backend(signedIn: false)
        await backend.failNextCall(with: .offline)
        let store = SessionStore(backend: backend, user: nil)
        await #expect(throws: AppError.offline) { try await store.sendPasswordReset(email: "ana@example.com") }
    }

    // MARK: Roles

    @Test func ownerChangesRoles() async throws {
        let store = GroupStore(backend: SampleData.backend())
        await store.load()
        #expect(store.role(of: SampleData.lucia.id) == .owner)
        #expect(store.role(of: SampleData.marta.id) == .admin)

        try await store.setRole(.viewer, for: SampleData.pablo.id)
        #expect(store.role(of: SampleData.pablo.id) == .viewer)
        try await store.setRole(.admin, for: SampleData.pablo.id)
        #expect(store.role(of: SampleData.pablo.id) == .admin)
    }

    @Test func newMembersJoinAsEditors() async throws {
        let backend = SampleData.backend(signedIn: false)
        let session = SessionStore(backend: backend, user: nil)
        try await session.signUp(name: "Ana", email: "ana@example.com", password: "12345678")
        let store = GroupStore(backend: backend)
        let group = try await store.join(code: "ABC123")
        let ana = try #require(group.members.first { $0.name == "Ana" })
        #expect(store.role(of: ana.id) == .editor)
    }

    @Test func editorsCannotChangeRoles() async throws {
        let backend = SampleData.backend(signedIn: false)
        _ = try await backend.signIn(email: "pablo@example.com", password: SampleData.password)
        let store = GroupStore(backend: backend)
        await #expect(throws: AppError.server("No tienes permiso para cambiar roles.")) {
            try await store.setRole(.viewer, for: SampleData.marta.id)
        }
    }

    @Test func theOwnerCannotBeChanged() async throws {
        let store = GroupStore(backend: SampleData.backend())
        await #expect(throws: AppError.server("El propietario no se puede cambiar.")) {
            try await store.setRole(.editor, for: SampleData.lucia.id)
        }
    }

    @Test func adminsOnlyManageEditorsAndViewers() async throws {
        let backend = SampleData.backend(signedIn: false)
        _ = try await backend.signIn(email: "marta@example.com", password: SampleData.password)
        let store = GroupStore(backend: backend)
        try await store.setRole(.viewer, for: SampleData.pablo.id)
        #expect(store.role(of: SampleData.pablo.id) == .viewer)
        await #expect(throws: AppError.server("Solo el propietario gestiona a los administradores.")) {
            try await store.setRole(.admin, for: SampleData.pablo.id)
        }
    }

    @Test func ownerLeavingPassesTheGroupToAnAdmin() async throws {
        let backend = SampleData.backend()
        try await GroupStore(backend: backend).leave()

        _ = try await backend.signIn(email: "marta@example.com", password: SampleData.password)
        let store = GroupStore(backend: backend)
        await store.load()
        #expect(store.role(of: SampleData.marta.id) == .owner)
        #expect(store.group?.members.count == 2)
    }

    @Test func viewersReadButDoNotWrite() async throws {
        let backend = SampleData.backend()
        try await GroupStore(backend: backend).setRole(.viewer, for: SampleData.pablo.id)
        _ = try await backend.signIn(email: "pablo@example.com", password: SampleData.password)

        let store = ListsStore(backend: backend)
        let listID = SampleData.firstListID
        try await store.loadDetail(listID)
        #expect(store.items(in: listID).count == 6)

        let milk = try #require(store.items(in: listID).first { $0.name == "Leche" })
        await #expect(throws: AppError.forbidden) { try await store.addItem(ItemDraft(name: "Sal"), to: listID) }
        await #expect(throws: AppError.forbidden) { try await store.togglePurchased(milk) }
        await #expect(throws: AppError.forbidden) { try await store.setPinned(true, listID: listID) }
        await #expect(throws: AppError.forbidden) {
            try await store.createList(named: "Nueva", groupID: SampleData.groupID)
        }
        #expect(store.items(in: listID).first { $0.id == milk.id }?.isPurchased == false)
    }

    // MARK: Listas con icono, tienda y fijada

    @Test func createListWithIconStoreAndPin() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let draft = ListDraft(name: " Botiquín ", icon: .pharmacy, store: " Lidl ", isPinned: true)
        let list = try await store.createList(draft, groupID: SampleData.groupID)
        #expect(list.name == "Botiquín")
        #expect(list.icon == .pharmacy)
        #expect(list.store == "Lidl")
        #expect(list.isPinned)

        await store.load(archived: false)
        #expect(store.lists(archived: false).first?.id == list.id)
    }

    @Test func editingAListUpdatesAllItsDetails() async throws {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        let id = SampleData.firstListID
        #expect(store.list(id)?.store == "Mercadona")

        try await store.update(id, with: ListDraft(name: " Compra del mes ", icon: .home, store: "", isPinned: true))
        let list = try #require(store.list(id))
        #expect(list.name == "Compra del mes")
        #expect(list.icon == .home)
        #expect(list.store == nil)
        #expect(list.isPinned)
    }

    @Test func pinnedListsComeFirst() async throws {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        let oldest = try #require(store.lists(archived: false).last)
        try await store.setPinned(true, listID: oldest.id)
        #expect(store.lists(archived: false).first?.id == oldest.id)
        try await store.setPinned(false, listID: oldest.id)
        #expect(store.list(oldest.id)?.isPinned == false)
    }

    // MARK: Artículos con nota, urgente y responsable

    @Test func itemKeepsNoteUrgentAndAssignee() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let listID = SampleData.firstListID
        try await store.loadDetail(listID)

        let draft = ItemDraft(
            name: "Yogur", quantity: "4", category: .dairyEggs,
            note: " Sin azúcar ", isUrgent: true, assigneeID: SampleData.marta.id)
        let item = try await store.addItem(draft, to: listID)
        #expect(item.note == "Sin azúcar")
        #expect(item.isUrgent)
        #expect(item.assignee == SampleData.marta)

        let members = [SampleData.lucia, SampleData.pablo]
        try await store.updateItem(
            item, with: ItemDraft(name: "Yogur", quantity: "4", category: .dairyEggs, assigneeID: SampleData.pablo.id),
            members: members)
        let edited = try #require(store.items(in: listID).first { $0.id == item.id })
        #expect(edited.note == nil)
        #expect(!edited.isUrgent)
        #expect(edited.assignee == SampleData.pablo)
    }

    @Test func assigneeMustBelongToTheGroup() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let listID = SampleData.firstListID
        try await store.loadDetail(listID)
        await #expect(throws: AppError.server("La persona asignada no pertenece al grupo.")) {
            try await store.addItem(ItemDraft(name: "Sal", assigneeID: UUID()), to: listID)
        }
        #expect(store.items(in: listID).count == 6)
    }
}
