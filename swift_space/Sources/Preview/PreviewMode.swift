import SwiftUI

/// Modo de capturas para CI: `-PREVIEW_SCREEN <nombre>` sustituye Supabase por datos de
/// ejemplo (`PreviewBackend`) y muestra directamente una pantalla. No afecta al uso normal.
enum PreviewMode {
    static let screen: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-PREVIEW_SCREEN"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

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
