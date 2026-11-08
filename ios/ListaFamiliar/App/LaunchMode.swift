import Foundation

/// Cómo se ha lanzado la app, según los argumentos del proceso.
enum LaunchMode: Equatable {
    /// Uso normal, contra Supabase.
    case live
    /// `-DEMO`: la app completa con datos de ejemplo en memoria, sin red.
    case demo
    /// `-PREVIEW_SCREEN <nombre>`: muestra una sola pantalla con datos de ejemplo (capturas de CI).
    case screenshot(PreviewScreen)
    /// La app actúa como anfitrión de los tests: no dibuja nada ni toca la red.
    case testHost

    static let current: LaunchMode = {
        let info = ProcessInfo.processInfo
        if info.environment["XCTestConfigurationFilePath"] != nil { return .testHost }
        let args = info.arguments
        if let index = args.firstIndex(of: "-PREVIEW_SCREEN"), index + 1 < args.count {
            return .screenshot(PreviewScreen(rawValue: args[index + 1]) ?? .lists)
        }
        if args.contains("-DEMO") { return .demo }
        return .live
    }()

    func makeBackend() -> any Backend {
        switch self {
        case .live: SupabaseBackend()
        case .demo: SampleData.backend(signedIn: false)
        case .screenshot(let screen): SampleData.backend(signedIn: screen.needsSession, inGroup: screen != .familySetup)
        case .testHost: SampleData.backend()
        }
    }
}
