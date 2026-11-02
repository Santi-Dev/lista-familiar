import SwiftUI

struct RootView: View {
    @Environment(SessionModel.self) private var session

    var body: some View {
        Group {
            if session.isLoading {
                SplashView()
            } else if !session.isAuthenticated {
                AuthFlowView()
            } else if !session.hasFamilyGroup {
                FamilyGroupSetupView()
            } else {
                MainTabView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: session.isLoading)
        .animation(.easeInOut(duration: 0.3), value: session.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: session.hasFamilyGroup)
    }
}
