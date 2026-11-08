import SwiftUI

/// Elige la parte de la app según la sesión: arranque, acceso, alta del grupo o la app principal.
struct RootView: View {
    @Environment(SessionStore.self) private var session
    @Environment(GroupStore.self) private var group
    @Environment(ListsStore.self) private var lists

    var body: some View {
        content
            .animation(.easeInOut(duration: 0.3), value: session.phase)
            .task { await session.restore() }
            // Al cambiar de usuario o de grupo, los datos anteriores ya no sirven.
            .onChange(of: session.user?.familyGroupID) { _, _ in
                group.reset()
                lists.reset()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch session.phase {
        case .launching:
            SplashView()
        case .unavailable(let message):
            ErrorStateView(message: message) { Task { await session.restore() } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.appBackground)
        case .signedOut:
            AuthFlowView()
                .transition(.opacity)
        case .signedIn(let user) where !user.hasFamilyGroup:
            FamilyGroupSetupView()
                .transition(.opacity)
        case .signedIn:
            MainTabView()
                .transition(.opacity)
        }
    }
}

#Preview("Con sesión") {
    RootView().previewEnvironment()
}

#Preview("Sin sesión") {
    RootView().previewEnvironment(signedIn: false)
}
