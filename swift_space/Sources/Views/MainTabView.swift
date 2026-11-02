import SwiftUI

struct MainTabView: View {
    var body: some View {
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
