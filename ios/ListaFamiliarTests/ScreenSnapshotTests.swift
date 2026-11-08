import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import ListaFamiliar

/// Snapshots de las pantallas en claro y oscuro con datos de `SampleData` (sin red).
///
/// Las referencias viven en `ios/Snapshots/` (fuera del target, para no copiarlas al bundle de tests).
/// Para regenerarlas, lanza el workflow `snapshots` con `record = true` (ver docs/TESTS.md) o, en local,
/// ejecuta los tests con la variable de entorno `SNAPSHOT_TESTING_RECORD=all`.
///
/// Cada pantalla se muestra en una `UIWindow` real (UIKit solo se usa aquí, en los tests),
/// se espera a que la imagen sea estable y se captura con `drawHierarchy`, así el Liquid Glass se renderiza de verdad.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private enum Device {
        /// Tamaño de pantalla del simulador.
        case standard
        /// Ancho de los iPhone más estrechos soportados (375 pt): para detectar textos cortados.
        case narrow
    }

    // MARK: - Autenticación

    func testWelcome() async { await assertScreen(.welcome) }
    func testLogin() async { await assertScreen(.login) }
    func testRegister() async { await assertScreen(.register) }
    func testFamilyGroupSetup() async { await assertScreen(.familySetup) }

    // MARK: - App principal

    func testListsHome() async { await assertScreen(.lists) }
    func testListDetail() async { await assertScreen(.detail) }
    func testSettings() async { await assertScreen(.settings) }
    func testCreateListSheet() async { await assertScreen(.createList) }
    func testItemFormSheet() async { await assertScreen(.itemForm) }

    // MARK: - Nombres largos (regresión del título cortado)

    func testListsHomeWithLongGroupName() async {
        await assertScreen(.lists, device: .narrow,
                           backend: SampleData.backend(groupName: "Familia García Rodríguez de la Fuente y Martínez"))
    }

    func testListDetailWithLongListName() async {
        await assertScreen(.detail, device: .narrow,
                           backend: SampleData.backend(firstListName: "Compra grande del mes para toda la familia y la fiesta del domingo"))
    }

    // MARK: - Ayudas

    /// Captura la pantalla en claro y oscuro y la compara con las referencias.
    private func assertScreen(
        _ screen: PreviewScreen,
        device: Device = .standard,
        backend: InMemoryBackend? = nil,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) async {
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            // Un backend nuevo por captura: las dos variantes parten de los mismos datos.
            let backend = backend ?? SampleData.backend(inGroup: screen != .familySetup)
            let user = screen.needsSession ? SampleData.user(inGroup: screen != .familySetup) : nil
            let view = PreviewScreenView(screen: screen).appEnvironment(AppModel(backend: backend, user: user))
            let image = await render(view, size: size(for: device), style: style)
            let failure = verifySnapshot(
                of: image,
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "screen-\(suffix)",
                snapshotDirectory: snapshotDirectory(file: file),
                file: file, testName: testName, line: line)
            if let failure { XCTFail(failure, file: file, line: line) }
        }
    }

    private func snapshotDirectory(file: StaticString) -> String {
        URL(fileURLWithPath: "\(file)")
            .deletingLastPathComponent()   // ListaFamiliarTests/
            .deletingLastPathComponent()   // ios/
            .appendingPathComponent("Snapshots", isDirectory: true)
            .path
    }

    private var scene: UIWindowScene? {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
    }

    private func size(for device: Device) -> CGSize {
        let screen = scene?.screen.bounds.size ?? CGSize(width: 402, height: 874)
        switch device {
        case .standard: return screen
        case .narrow: return CGSize(width: 375, height: screen.height)
        }
    }

    /// Muestra la vista en una ventana real y devuelve la captura cuando la imagen es estable.
    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) async -> UIImage {
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: .zero)
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: view)
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Espera mínima para que arranquen las cargas (`.task`)…
        try? await Task.sleep(for: .seconds(1.5))

        // …y después captura hasta tener 2 imágenes seguidas idénticas (máximo ~12 s).
        var last = capture(window, size: size)
        var stableFrames = 0
        for _ in 0..<24 {
            try? await Task.sleep(for: .milliseconds(500))
            let next = capture(window, size: size)
            if next.pngData() == last.pngData() {
                stableFrames += 1
                if stableFrames >= 2 { return next }
            } else {
                stableFrames = 0
            }
            last = next
        }
        return last
    }

    private func capture(_ window: UIWindow, size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            window.drawHierarchy(in: CGRect(origin: .zero, size: size), afterScreenUpdates: true)
        }
    }
}
