import SwiftUI

/// Pantallas que se pueden mostrar sueltas con `-PREVIEW_SCREEN <nombre>` (capturas de CI)
/// y en los tests de snapshots. Al añadir una pantalla, añádela aquí y en `.github/workflows/ios-preview.yml`.
enum PreviewScreen: String, CaseIterable, Sendable {
    case welcome
    case login
    case register
    case familySetup = "family-setup"
    case lists
    case detail
    case settings
    case createList = "create-list"
    case itemForm = "item-form"

    var needsSession: Bool {
        switch self {
        case .welcome, .login, .register: false
        default: true
        }
    }
}

/// Muestra una pantalla suelta con datos de ejemplo.
struct PreviewScreenView: View {
    let screen: PreviewScreen

    var body: some View {
        switch screen {
        case .welcome: AuthFlowView()
        case .login: AuthFlowView(initialRoute: .signIn)
        case .register: AuthFlowView(initialRoute: .signUp)
        case .familySetup: FamilyGroupSetupView()
        case .lists: MainTabView()
        case .detail: NavigationStack { ListDetailView(listID: SampleData.firstListID) }
        case .settings: MainTabView(initialTab: .settings)
        case .createList: CreateListSheet { _ in }
        case .itemForm: ItemFormSheet(listID: SampleData.firstListID, mode: .add(category: .other)) { _ in }
        }
    }
}

extension View {
    /// Entorno de ejemplo para `#Preview`: stores sobre `InMemoryBackend` con la sesión de Lucía.
    @MainActor func previewEnvironment(signedIn: Bool = true, inGroup: Bool = true) -> some View {
        let backend = SampleData.backend(signedIn: signedIn, inGroup: inGroup)
        let user = signedIn ? SampleData.user(inGroup: inGroup) : nil
        return appEnvironment(AppModel(backend: backend, user: user))
    }
}
