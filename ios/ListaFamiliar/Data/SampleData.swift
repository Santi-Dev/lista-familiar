import Foundation

/// Datos de ejemplo de la «Familia García». Los identificadores son fijos para poder
/// referirse a ellos desde las capturas y los tests (`SampleData.firstListID`).
enum SampleData {
    static let lucia = Member(id: uuid(1), name: "Lucía")
    static let pablo = Member(id: uuid(2), name: "Pablo")
    static let marta = Member(id: uuid(3), name: "Marta")

    static let groupID = uuid(100)
    static let firstListID = uuid(200)
    static let email = "lucia@example.com"
    static let password = "contraseña123"

    static func user(inGroup: Bool = true) -> User {
        User(id: lucia.id, name: lucia.name, email: email, familyGroupID: inGroup ? groupID : nil)
    }

    /// Backend de ejemplo.
    /// - Parameters:
    ///   - signedIn: si arranca con la sesión de Lucía iniciada.
    ///   - inGroup: si Lucía ya pertenece al grupo (si no, se muestra la pantalla de crear o unirse).
    ///   - now: fecha de referencia; las listas se actualizaron hace 2, 26 y 74 horas.
    static func backend(
        signedIn: Bool = true,
        inGroup: Bool = true,
        groupName: String = "Familia García",
        firstListName: String = "Mercado semanal",
        now: Date = Date()
    ) -> InMemoryBackend {
        func ago(_ hours: Double) -> Date { now.addingTimeInterval(-hours * 3600) }

        let group = FamilyGroup(
            id: groupID, name: groupName, inviteCode: "ABC123", createdByID: lucia.id,
            members: [lucia, marta, pablo], createdAt: ago(24 * 30),
            roles: [lucia.id: .owner, marta.id: .admin, pablo.id: .editor])

        func list(_ n: Int, _ name: String, updated hours: Double, icon: ListIcon, store: String? = nil) -> ShoppingList {
            ShoppingList(
                id: uuid(200 + n), name: name, isArchived: false, createdBy: lucia,
                itemCount: 0, purchasedCount: 0, createdAt: ago(hours + 1), updatedAt: ago(hours),
                icon: icon, store: store)
        }
        let lists = [
            list(0, firstListName, updated: 2, icon: .cart, store: "Mercadona"),
            list(1, "Cumpleaños de Marta", updated: 26, icon: .party),
            list(2, "Limpieza del hogar", updated: 74, icon: .cleaning),
        ]

        var order = 0
        func item(
            _ list: Int, _ name: String, _ quantity: String?, _ category: ItemCategory, bought: Bool = false,
            note: String? = nil, urgent: Bool = false, assignee: Member? = nil
        ) -> ListItem {
            order += 1
            return ListItem(
                id: uuid(1000 + order), listID: uuid(200 + list), name: name, quantity: quantity,
                category: category, isPurchased: bought, purchasedBy: bought ? lucia : nil,
                purchasedAt: bought ? ago(2) : nil, addedBy: order.isMultiple(of: 3) ? pablo : lucia,
                createdAt: ago(3).addingTimeInterval(Double(order)), updatedAt: ago(2),
                note: note, isUrgent: urgent, assignee: assignee)
        }
        let items = [
            item(0, "Manzanas", "1 kg", .produce, assignee: marta),
            item(0, "Leche", "2 L", .dairyEggs, note: "Sin lactosa"),
            item(0, "Pechuga de pollo", "500 g", .meatFish, urgent: true),
            item(0, "Pan integral", "1", .bakery, bought: true),
            item(0, "Arroz", "1 kg", .pantry, bought: true),
            item(0, "Agua con gas", "6", .drinks),
            item(1, "Tarta de chocolate", nil, .bakery),
            item(1, "Velas", "10", .other),
            item(1, "Zumo de naranja", "2 L", .drinks),
            item(1, "Patatas fritas", "3 bolsas", .pantry),
            item(2, "Lejía", "1", .cleaning, bought: true),
            item(2, "Bayetas", "4", .cleaning, bought: true),
            item(2, "Friegasuelos", "1", .cleaning, bought: true),
        ]

        return InMemoryBackend(
            accounts: [
                .init(user: user(inGroup: inGroup), password: password),
                .init(user: User(id: pablo.id, name: pablo.name, email: "pablo@example.com", familyGroupID: groupID), password: password),
                .init(user: User(id: marta.id, name: marta.name, email: "marta@example.com", familyGroupID: groupID), password: password),
            ],
            currentUserID: signedIn ? lucia.id : nil,
            groups: inGroup ? [group] : [group.removingMember(lucia)],
            lists: lists,
            items: items,
            clock: { Date() })
    }

    private static func uuid(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", n))!
    }
}

private extension FamilyGroup {
    func removingMember(_ member: Member) -> FamilyGroup {
        var copy = self
        copy.members.removeAll { $0.id == member.id }
        return copy
    }
}
