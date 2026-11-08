import SwiftUI

@main
struct ListaFamiliarApp: App {
    private let mode = LaunchMode.current
    @State private var model: AppModel

    init() {
        FontRegistry.registerAll()
        let mode = LaunchMode.current
        let backend = mode.makeBackend()
        if case .screenshot(let screen) = mode {
            let user = screen.needsSession ? SampleData.user(inGroup: screen != .familySetup) : nil
            _model = State(initialValue: AppModel(backend: backend, user: user))
        } else {
            _model = State(initialValue: AppModel(backend: backend))
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch mode {
                case .testHost:
                    Color.clear
                case .screenshot(let screen):
                    PreviewScreenView(screen: screen)
                case .live, .demo:
                    RootView()
                }
            }
            .appEnvironment(model)
        }
    }
}
