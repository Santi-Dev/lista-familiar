import SnapshotTesting
import SwiftUI
import XCTest
@testable import FamilyShoppingLists

/// Tests de snapshots de las pantallas, en claro y oscuro, con datos de `PreviewBackend` (sin red).
/// Las imágenes de referencia viven en `Tests/__Snapshots__`. Para regenerarlas, lanza el workflow
/// `snapshots` con `record = true` (ver docs/TESTS.md).
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private let iPhone = ViewImageConfig.iPhone13Pro
    private let smallPhone = ViewImageConfig.iPhoneSe

    override func setUp() {
        super.setUp()
        APIClient.shared = PreviewBackend()
    }

    override func tearDown() {
        APIClient.shared = PreviewBackend()
        super.tearDown()
    }

    // MARK: - Helper

    /// Renderiza la vista en claro y oscuro y compara con las referencias.
    private func assertScreen<V: View>(
        _ view: V,
        config: ViewImageConfig,
        named name: String = "screen",
        wait: TimeInterval = 1.5,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        for (suffix, style) in [("light", UIUserInterfaceStyle.light), ("dark", .dark)] {
            let host = UIHostingController(rootView: view.environment(SessionModel()))
            host.overrideUserInterfaceStyle = style
            assertSnapshot(
                of: host,
                as: .wait(
                    for: wait,
                    on: .image(on: config, precision: 0.98, perceptualPrecision: 0.98,
                               traits: UITraitCollection(userInterfaceStyle: style))
                ),
                named: "\(name)-\(suffix)",
                file: file, testName: testName, line: line
            )
        }
    }

    // MARK: - Autenticación

    func testWelcome() { assertScreen(AuthFlowView(), config: iPhone) }
    func testLogin() { assertScreen(NavigationStack { LoginView() }, config: iPhone) }
    func testRegister() { assertScreen(NavigationStack { RegisterView() }, config: iPhone) }
    func testFamilyGroupSetup() { assertScreen(FamilyGroupSetupView(), config: iPhone) }

    // MARK: - Aplicación principal

    func testListsHome() { assertScreen(MainTabView(), config: iPhone) }
    func testListDetail() { assertScreen(NavigationStack { ListDetailView(listId: "l1") }, config: iPhone) }
    func testSettings() { assertScreen(SettingsView(), config: iPhone) }
    func testCreateListSheet() { assertScreen(CreateListSheet(onCreated: { _ in }), config: iPhone) }
    func testItemFormSheet() {
        assertScreen(ItemFormSheet(listId: "l1", preselectedCategory: .OTROS, onSaved: { _ in }), config: iPhone)
    }

    // MARK: - Títulos largos (regresión del título cortado)

    func testListsHomeWithLongGroupName() {
        APIClient.shared = PreviewBackend(groupName: "Familia García Rodríguez de la Fuente y Martínez")
        assertScreen(MainTabView(), config: smallPhone)
    }

    func testListDetailWithLongListName() {
        APIClient.shared = PreviewBackend(firstListName: "Compra grande del mes para toda la familia y la fiesta del domingo")
        assertScreen(NavigationStack { ListDetailView(listId: "l1") }, config: smallPhone)
    }
}
