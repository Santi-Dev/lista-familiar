import SwiftUI

enum AppTab: Hashable {
    case lists
    case settings
}

/// App principal. Aquí vive la única suscripción de tiempo real y el refresco al volver a la app,
/// que comparten «Mis listas» y el detalle a través de `ListsStore`.
struct MainTabView: View {
    @Environment(GroupStore.self) private var group
    @Environment(ListsStore.self) private var lists
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection: AppTab

    init(initialTab: AppTab = .lists) {
        _selection = State(initialValue: initialTab)
    }

    var body: some View {
        tabs
            .task { await group.load() }
            .task { await lists.observeChanges() }
            .task { await pollWhileActive() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await lists.refresh() } }
            }
    }

    @ViewBuilder
    private var tabs: some View {
        let view = TabView(selection: $selection) {
            Tab("Listas", systemImage: "list.bullet.clipboard", value: AppTab.lists) {
                ListsHomeView()
            }
            Tab("Ajustes", systemImage: "gearshape", value: AppTab.settings) {
                SettingsView()
            }
        }
        if #available(iOS 26, *) {
            view.tabBarMinimizeBehavior(.onScrollDown)
        } else {
            view
        }
    }

    /// Respaldo por si se cae Realtime: recarga cada 30 s mientras la app está en primer plano.
    private func pollWhileActive() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            if scenePhase == .active {
                await lists.refresh()
                await group.load() // los roles pueden haber cambiado desde otro móvil
            }
        }
    }
}

#Preview {
    MainTabView().previewEnvironment()
}
