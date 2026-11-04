import SnapshotTesting
import SwiftUI
import UIKit
import XCTest
@testable import FamilyShoppingLists

/// Tests de snapshots de las pantallas, en claro y oscuro, con datos de `PreviewBackend` (sin red).
/// Las imágenes de referencia viven en `Tests/__Snapshots__`. Para regenerarlas, lanza el workflow
/// `snapshots` con `record = true` (ver docs/TESTS.md).
///
/// Cada pantalla se muestra en una `UIWindow` real, se espera a que terminen las cargas (`.task`)
/// y se captura la jerarquía con `drawHierarchy`, de modo que el Liquid Glass se renderiza de verdad.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    override func setUp() {
        super.setUp()
        APIClient.shared = PreviewBackend()
        // 2 horas después de las fechas fijas de PreviewBackend: los textos relativos salen siempre como «hace 2 horas».
        RelativeDate.now = { ISO8601DateFormatter().date(from: "2026-01-15T12:00:00Z")! }
    }

    override func tearDown() {
        APIClient.shared = PreviewBackend()
        RelativeDate.now = { Date() }
        super.tearDown()
    }

    // MARK: - Helpers

    private enum Device {
        /// Tamaño de pantalla del simulador.
        case standard
        /// Ancho de los iPhone más estrechos soportados (375 pt): para detectar textos cortados.
        case narrow
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

    /// Muestra la vista en una ventana real, espera a que cargue y devuelve la captura.
    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle, wait: Duration) async -> UIImage {
        let window: UIWindow
        if let scene {
            window = UIWindow(windowScene: scene)
        } else {
            window = UIWindow(frame: .zero)
        }
        window.frame = CGRect(origin: .zero, size: size)
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(rootView: view.environment(SessionModel()))
        window.makeKeyAndVisible()
        defer { window.isHidden = true }

        // Espera mínima para que arranquen las cargas (`.task`)…
        try? await Task.sleep(for: wait)

        // …y después captura hasta que la imagen sea estable (2 capturas seguidas idénticas), con un máximo de ~12 s.
        // Así no dependemos de la velocidad del runner ni de animaciones que aún no han terminado.
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

    /// Captura la pantalla en claro y oscuro y compara con las referencias.
    private func assertScreen<V: View>(
        _ view: V,
        device: Device = .standard,
        wait: Duration = .seconds(2),
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) async {
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let image = await render(view, size: size(for: device), style: style, wait: wait)
            assertSnapshot(
                of: image,
                as: .image(precision: 0.98, perceptualPrecision: 0.98),
                named: "screen-\(suffix)",
                file: file, testName: testName, line: line
            )
        }
    }

    // MARK: - Autenticación

    func testWelcome() async { await assertScreen(AuthFlowView()) }
    func testLogin() async { await assertScreen(NavigationStack { LoginView() }) }
    func testRegister() async { await assertScreen(NavigationStack { RegisterView() }) }
    func testFamilyGroupSetup() async { await assertScreen(FamilyGroupSetupView()) }

    // MARK: - Aplicación principal

    func testListsHome() async { await assertScreen(MainTabView()) }
    func testListDetail() async { await assertScreen(NavigationStack { ListDetailView(listId: "l1") }) }
    func testSettings() async { await assertScreen(SettingsView()) }
    func testCreateListSheet() async { await assertScreen(CreateListSheet(onCreated: { _ in })) }
    func testItemFormSheet() async {
        await assertScreen(ItemFormSheet(listId: "l1", preselectedCategory: .OTROS, onSaved: { _ in }))
    }

    // MARK: - Títulos largos (regresión del título cortado)

    func testListsHomeWithLongGroupName() async {
        APIClient.shared = PreviewBackend(groupName: "Familia García Rodríguez de la Fuente y Martínez")
        await assertScreen(MainTabView(), device: .narrow)
    }

    func testListDetailWithLongListName() async {
        APIClient.shared = PreviewBackend(firstListName: "Compra grande del mes para toda la familia y la fiesta del domingo")
        await assertScreen(NavigationStack { ListDetailView(listId: "l1") }, device: .narrow)
    }
}
