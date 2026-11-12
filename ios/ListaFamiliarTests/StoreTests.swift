import Foundation
import Testing
@testable import ListaFamiliar

@MainActor
@Suite("SessionStore")
struct SessionStoreTests {
    @Test func restoresSavedSession() async {
        let store = SessionStore(backend: SampleData.backend())
        await store.restore()
        #expect(store.user?.name == "Lucía")
        #expect(store.user?.hasFamilyGroup == true)
    }

    @Test func restoreWithoutSessionIsSignedOut() async {
        let store = SessionStore(backend: SampleData.backend(signedIn: false))
        await store.restore()
        #expect(store.phase == .signedOut)
    }

    @Test func restoreOfflineKeepsTheErrorInsteadOfSigningOut() async {
        let backend = SampleData.backend()
        await backend.failNextCall(with: .offline)
        let store = SessionStore(backend: backend)
        await store.restore()
        #expect(store.phase == .unavailable(AppError.offline.localizedDescription))
    }

    @Test func signInWithWrongPassword() async {
        let store = SessionStore(backend: SampleData.backend(signedIn: false), user: nil)
        await #expect(throws: AppError.invalidCredentials) {
            try await store.signIn(email: SampleData.email, password: "mal")
        }
        #expect(store.phase == .signedOut)
    }

    @Test func signInTrimsTheEmail() async throws {
        let store = SessionStore(backend: SampleData.backend(signedIn: false), user: nil)
        try await store.signIn(email: " \(SampleData.email) ", password: SampleData.password)
        #expect(store.user?.id == SampleData.lucia.id)
    }

    @Test func signUpWithExistingEmail() async {
        let store = SessionStore(backend: SampleData.backend(signedIn: false), user: nil)
        await #expect(throws: AppError.emailAlreadyRegistered) {
            try await store.signUp(name: "Otra", email: SampleData.email, password: "12345678")
        }
    }

    @Test func signUpThenJoinGroup() async throws {
        let backend = SampleData.backend(signedIn: false)
        let session = SessionStore(backend: backend, user: nil)
        let groups = GroupStore(backend: backend)

        try await session.signUp(name: "  Ana ", email: "ana@example.com", password: "12345678")
        #expect(session.user?.name == "Ana")
        #expect(session.user?.hasFamilyGroup == false)

        let group = try await groups.join(code: "abc 123")
        session.joined(group)
        #expect(session.user?.familyGroupID == SampleData.groupID)
        #expect(group.members.contains { $0.name == "Ana" })
    }

    @Test func signOut() async {
        let store = SessionStore(backend: SampleData.backend(), user: SampleData.user())
        await store.signOut()
        #expect(store.phase == .signedOut)
    }
}

@MainActor
@Suite("GroupStore")
struct GroupStoreTests {
    @Test func loadsGroup() async {
        let store = GroupStore(backend: SampleData.backend())
        await store.load()
        #expect(store.group?.name == "Familia García")
        #expect(store.group?.members.count == 3)
        #expect(store.state == .loaded)
    }

    @Test func joinWithInvalidCode() async {
        let backend = SampleData.backend(inGroup: false)
        let store = GroupStore(backend: backend)
        await #expect(throws: AppError.server("Código de invitación no válido")) {
            try await store.join(code: "ZZZZZZ")
        }
        #expect(store.group == nil)
    }

    @Test func createGroupWhenNotInOne() async throws {
        let store = GroupStore(backend: SampleData.backend(inGroup: false))
        let group = try await store.create(named: "  Casa  ")
        #expect(group.name == "Casa")
        #expect(group.inviteCode.count == InviteCode.length)
        #expect(store.group == group)
    }

    @Test func leaveForgetsTheGroup() async throws {
        let store = GroupStore(backend: SampleData.backend())
        await store.load()
        try await store.leave()
        #expect(store.group == nil)
        #expect(store.state == .idle)
    }
}

@MainActor
@Suite("ListsStore")
struct ListsStoreTests {
    @Test func loadsActiveListsNewestFirst() async {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        let lists = store.lists(archived: false)
        #expect(lists.map(\.name) == ["Mercado semanal", "Cumpleaños de Marta", "Limpieza del hogar", "Escapada a Lisboa"])
        #expect(lists.first?.itemCount == 6)
        #expect(lists.first?.purchasedCount == 2)
        #expect(store.state(archived: false) == .loaded)
    }

    @Test func createTripListKeepsItsKind() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let list = try await store.createList(
            ListDraft(name: "Viaje a Roma", icon: .trip, kind: .trip), groupID: SampleData.groupID)
        #expect(list.kind == .trip)
        #expect(list.icon == .trip)
        #expect(try await store.createList(named: "Compra", groupID: SampleData.groupID).kind == .market)
    }

    @Test func failedFirstLoadShowsError() async {
        let backend = SampleData.backend()
        await backend.failNextCall(with: .offline)
        let store = ListsStore(backend: backend)
        await store.load(archived: false)
        #expect(store.state(archived: false) == .failed(AppError.offline.localizedDescription))
    }

    @Test func failedRefreshKeepsExistingLists() async {
        let backend = SampleData.backend()
        let store = ListsStore(backend: backend)
        await store.load(archived: false)
        await backend.failNextCall(with: .offline)
        await store.load(archived: false)
        #expect(store.lists(archived: false).count == 4)
        #expect(store.state(archived: false) == .loaded)
    }

    @Test func togglePurchasedUpdatesItemAndCounts() async throws {
        let store = ListsStore(backend: SampleData.backend())
        try await store.loadDetail(SampleData.firstListID)
        let milk = try #require(store.items(in: SampleData.firstListID).first { $0.name == "Leche" })

        try await store.togglePurchased(milk)

        let updated = try #require(store.items(in: SampleData.firstListID).first { $0.id == milk.id })
        #expect(updated.isPurchased)
        #expect(updated.purchasedBy == SampleData.lucia)
        #expect(store.list(SampleData.firstListID)?.purchasedCount == 3)
    }

    @Test("Si el servidor falla, el cambio se deshace")
    func failedToggleIsRolledBack() async throws {
        let backend = SampleData.backend()
        let store = ListsStore(backend: backend)
        try await store.loadDetail(SampleData.firstListID)
        let milk = try #require(store.items(in: SampleData.firstListID).first { $0.name == "Leche" })

        await backend.failNextCall(with: .offline)
        await #expect(throws: AppError.offline) { try await store.togglePurchased(milk) }

        #expect(store.items(in: SampleData.firstListID).first { $0.id == milk.id }?.isPurchased == false)
        #expect(store.list(SampleData.firstListID)?.purchasedCount == 2)
    }

    @Test func addEditAndDeleteItem() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let listID = SampleData.firstListID
        try await store.loadDetail(listID)

        let eggs = try await store.addItem(ItemDraft(name: " Huevos ", quantity: "12", category: .dairyEggs), to: listID)
        #expect(eggs.name == "Huevos")
        #expect(store.list(listID)?.itemCount == 7)

        try await store.updateItem(eggs, with: ItemDraft(name: "Huevos camperos", quantity: "", category: .dairyEggs))
        let edited = try #require(store.items(in: listID).first { $0.id == eggs.id })
        #expect(edited.name == "Huevos camperos")
        #expect(edited.quantity == nil)

        try await store.deleteItem(edited)
        #expect(!store.items(in: listID).contains { $0.id == eggs.id })
        #expect(store.list(listID)?.itemCount == 6)
    }

    @Test func archiveMovesListBetweenTabs() async throws {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        try await store.setArchived(true, listID: SampleData.firstListID)
        #expect(store.lists(archived: false).count == 3)
        #expect(store.lists(archived: true).map(\.id) == [SampleData.firstListID])
    }

    @Test func renameIgnoresBlankNames() async throws {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        try await store.rename(SampleData.firstListID, to: "   ")
        #expect(store.list(SampleData.firstListID)?.name == "Mercado semanal")
        try await store.rename(SampleData.firstListID, to: " Compra del mes ")
        #expect(store.list(SampleData.firstListID)?.name == "Compra del mes")
    }

    @Test func deletedListIsForgottenAndDetailReportsNotFound() async throws {
        let store = ListsStore(backend: SampleData.backend())
        await store.load(archived: false)
        try await store.delete(SampleData.firstListID)
        #expect(store.list(SampleData.firstListID) == nil)
        await #expect(throws: AppError.notFound) { try await store.loadDetail(SampleData.firstListID) }
    }

    @Test func createListIsReadyToOpen() async throws {
        let store = ListsStore(backend: SampleData.backend())
        let list = try await store.createList(named: "Barbacoa", groupID: SampleData.groupID)
        #expect(store.list(list.id)?.name == "Barbacoa")
        #expect(store.itemsState(for: list.id) == .loaded)
        #expect(store.items(in: list.id).isEmpty)
    }
}
