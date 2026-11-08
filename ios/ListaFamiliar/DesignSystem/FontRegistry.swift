import CoreText
import Foundation

/// Registra las fuentes empaquetadas (`Resources/Fonts/*.ttf`) para todo el proceso.
/// No hace falta tocar el Info.plist. Si una fuente no se encuentra, SwiftUI usa la del sistema.
enum FontRegistry {
    static func registerAll(in bundle: Bundle = .main) {
        let urls = (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? [])
            + (bundle.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? [])
        guard !urls.isEmpty else { return }
        CTFontManagerRegisterFontsForURLs(urls as CFArray, .process, nil)
    }
}
