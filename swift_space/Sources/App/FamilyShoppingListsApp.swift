import SwiftUI

@main
struct FamilyShoppingListsApp: App {
    @State private var session = SessionModel()

    init() {
        PreviewMode.activate()
        URLCache.shared = URLCache(memoryCapacity: 50_000_000, diskCapacity: 200_000_000)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = PreviewMode.screen {
                    PreviewMode.root(screen)
                } else {
                    RootView()
                }
            }
            .environment(session)
        }
    }
}
