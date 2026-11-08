import SwiftUI

enum AuthRoute: Hashable {
    case signIn
    case signUp
}

/// Bienvenida → iniciar sesión / crear cuenta. Cambiar entre las dos sustituye la pantalla
/// en lugar de apilar una encima de otra.
struct AuthFlowView: View {
    @State private var path: [AuthRoute]

    init(initialRoute: AuthRoute? = nil) {
        _path = State(initialValue: initialRoute.map { [$0] } ?? [])
    }

    var body: some View {
        NavigationStack(path: $path) {
            WelcomeView(open: { path = [$0] })
                .navigationDestination(for: AuthRoute.self) { route in
                    switch route {
                    case .signIn: SignInView(switchToSignUp: { path = [.signUp] })
                    case .signUp: SignUpView(switchToSignIn: { path = [.signIn] })
                    }
                }
        }
    }
}

#Preview {
    AuthFlowView().previewEnvironment(signedIn: false)
}
