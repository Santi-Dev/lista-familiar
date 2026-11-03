import SwiftUI

struct MainTabView: View {
    var body: some View {
        if #available(iOS 26, *) {
            tabs.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            tabs
        }
    }

    private var tabs: some View {
        TabView {
            Tab("Listas", systemImage: "list.bullet.clipboard") {
                ListsHomeView()
            }
            Tab("Ajustes", systemImage: "gearshape") {
                SettingsView()
            }
        }
        .tint(Theme.Colors.brand)
    }
}
