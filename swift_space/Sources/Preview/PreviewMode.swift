import SwiftUI

/// Modo de capturas para CI: `-PREVIEW_SCREEN <nombre>` sustituye la red por datos de
/// ejemplo y muestra directamente una pantalla. No afecta al uso normal de la app.
enum PreviewMode {
    static let screen: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PREVIEW_SCREEN"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static func activate() {
        guard screen != nil else { return }
        URLProtocol.registerClass(PreviewURLProtocol.self)
        KeychainHelper.authToken = "preview-token"
    }

    @ViewBuilder
    static func root(_ name: String) -> some View {
        switch name {
        case "welcome": AuthFlowView()
        case "login": NavigationStack { LoginView() }
        case "register": NavigationStack { RegisterView() }
        case "family-setup": FamilyGroupSetupView()
        case "settings": SettingsView()
        case "detail": NavigationStack { ListDetailView(listId: "l1") }
        case "create-list": CreateListSheet(onCreated: { _ in })
        case "item-form": ItemFormSheet(listId: "l1", preselectedCategory: .OTROS, onSaved: { _ in })
        default: MainTabView() // "lists"
        }
    }
}

final class PreviewURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let path = request.url?.path ?? ""
        let (status, body) = Self.response(for: path, query: request.url?.query ?? "")
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil,
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static let me = #"{"id":"u1","name":"Lucía","email":"lucia@example.com","familyGroupId":"g1"}"#
    private static let user = #"{"id":"u1","name":"Lucía"}"#
    private static let now = "2026-01-15T10:00:00.000Z"

    private static func list(_ id: String, _ name: String, _ total: Int, _ done: Int) -> String {
        #"{"id":"\#(id)","name":"\#(name)","isArchived":false,"createdBy":\#(user),"itemCount":\#(total),"purchasedCount":\#(done),"createdAt":"\#(now)","updatedAt":"\#(now)"}"#
    }

    private static func item(_ id: String, _ name: String, _ qty: String, _ cat: String, _ bought: Bool) -> String {
        #"{"id":"\#(id)","shoppingListId":"l1","name":"\#(name)","quantity":"\#(qty)","category":"\#(cat)","isPurchased":\#(bought),"purchasedBy":\#(bought ? user : "null"),"purchasedAt":\#(bought ? "\"\(now)\"" : "null"),"addedBy":\#(user),"createdAt":"\#(now)","updatedAt":"\#(now)"}"#
    }

    private static func response(for path: String, query: String) -> (Int, String) {
        switch path {
        case "/api/auth/me":
            return (200, #"{"user":\#(me)}"#)
        case "/api/family-groups/me":
            return (200, #"{"id":"g1","name":"Familia García","inviteCode":"ABC123","createdById":"u1","members":[\#(user),{"id":"u2","name":"Pablo"},{"id":"u3","name":"Marta"}],"createdAt":"\#(now)"}"#)
        case "/api/lists":
            if query.contains("archived=true") { return (200, #"{"items":[]}"#) }
            return (200, #"{"items":[\#(list("l1", "Mercado semanal", 6, 2)),\#(list("l2", "Cumpleaños de Marta", 4, 0)),\#(list("l3", "Limpieza del hogar", 3, 3))]}"#)
        case "/api/lists/l1/items":
            let items = [
                item("i1", "Manzanas", "1 kg", "FRUTAS_VERDURAS", false),
                item("i2", "Leche", "2 L", "LACTEOS_HUEVOS", false),
                item("i3", "Pechuga de pollo", "500 g", "CARNES_PESCADO", false),
                item("i4", "Pan integral", "1", "PANADERIA", true),
                item("i5", "Arroz", "1 kg", "DESPENSA", true),
                item("i6", "Agua con gas", "6", "BEBIDAS", false),
            ].joined(separator: ",")
            return (200, #"{"list":\#(list("l1", "Mercado semanal", 6, 2)),"items":[\#(items)]}"#)
        default:
            return (200, "{}")
        }
    }
}
