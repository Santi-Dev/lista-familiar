import Foundation
import Testing
@testable import ListaFamiliar

@Suite("Modelos y reglas de formulario")
struct ModelTests {
    @Test("El código de invitación se normaliza a 6 caracteres en mayúsculas", arguments: [
        ("abc123", "ABC123"),
        (" ab c-12 3 ", "ABC123"),
        ("abcdefgh", "ABCDEF"),
        ("ñandú", "AND"),
    ])
    func inviteCode(raw: String, expected: String) {
        #expect(InviteCode.normalize(raw) == expected)
    }

    @Test func inviteCodeCompleteness() {
        #expect(InviteCode.isComplete("ABC123"))
        #expect(!InviteCode.isComplete("ABC12"))
    }

    @Test func draftCleansNameAndQuantity() {
        let draft = ItemDraft(name: "  Leche ", quantity: "   ", category: .dairyEggs)
        #expect(draft.cleanName == "Leche")
        #expect(draft.cleanQuantity == nil)
        #expect(draft.isValid)
        #expect(!ItemDraft(name: "   ").isValid)
    }

    @Test func unknownCategoryFallsBackToOther() {
        #expect(ItemCategory(databaseValue: "CONGELADOS") == .other)
        #expect(ItemCategory(databaseValue: "BEBIDAS") == .drinks)
    }

    @Test("Las secciones siguen el orden de categorías y los pendientes van primero")
    func sections() {
        let now = Date()
        func item(_ name: String, _ category: ItemCategory, bought: Bool, minutes: Double) -> ListItem {
            ListItem(id: UUID(), listID: UUID(), name: name, quantity: nil, category: category, isPurchased: bought,
                     purchasedBy: nil, purchasedAt: nil, addedBy: nil,
                     createdAt: now.addingTimeInterval(minutes * 60), updatedAt: now)
        }
        let items = [
            item("Agua", .drinks, bought: false, minutes: 0),
            item("Pan", .bakery, bought: true, minutes: 1),
            item("Bollos", .bakery, bought: false, minutes: 2),
            item("Manzanas", .produce, bought: false, minutes: 3),
        ]

        let sections = items.sectioned()
        #expect(sections.map(\.category) == [.produce, .bakery, .drinks])
        #expect(sections[1].items.map(\.name) == ["Bollos", "Pan"])
        #expect(sections[1].pendingCount == 1)
        #expect(items.sectioned(filter: .bakery).map(\.category) == [.bakery])
        #expect(items.pendingCount(in: .bakery) == 1)
    }

    @Test func attribution() {
        let lucia = Member(id: UUID(), name: "Lucía")
        let pablo = Member(id: UUID(), name: "Pablo")
        var item = ListItem(id: UUID(), listID: UUID(), name: "Leche", quantity: nil, category: .dairyEggs,
                            isPurchased: false, purchasedBy: nil, purchasedAt: nil, addedBy: pablo,
                            createdAt: .now, updatedAt: .now)
        #expect(item.attribution == "Añadido por Pablo")
        item.isPurchased = true
        item.purchasedBy = lucia
        #expect(item.attribution == "Comprado por Lucía")
    }

    @Test func credentials() {
        #expect(Credentials.isPlausibleEmail("lucia@example.com"))
        #expect(!Credentials.isPlausibleEmail("lucia@example"))
        #expect(!Credentials.isPlausibleEmail("@example.com"))
        #expect(Credentials.canSignUp(name: "Lucía", email: "lucia@example.com", password: "12345678"))
        #expect(!Credentials.canSignUp(name: "Lucía", email: "lucia@example.com", password: "1234567"))
        #expect(!Credentials.canSignUp(name: "  ", email: "lucia@example.com", password: "12345678"))
    }

    @Test("Fechas de PostgREST con y sin fracción de segundo", arguments: [
        "2026-01-15T10:00:00.123456+00:00",
        "2026-01-15T10:00:00+00:00",
        "2026-01-15T10:00:00.123Z",
    ])
    func postgresDates(text: String) throws {
        let date = PostgresDate.parse(text)
        let expected = try #require(ISO8601DateFormatter().date(from: "2026-01-15T10:00:00Z"))
        #expect(abs(date.timeIntervalSince(expected)) < 1)
    }

    @Test func listProgress() {
        var list = ShoppingList(id: UUID(), name: "Mercado", isArchived: false, createdBy: nil,
                                itemCount: 0, purchasedCount: 0, createdAt: .now, updatedAt: .now)
        #expect(list.progress == 0)
        #expect(!list.isComplete)
        list.itemCount = 4
        list.purchasedCount = 4
        #expect(list.progress == 1)
        #expect(list.isComplete)
    }
}
