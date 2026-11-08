import SwiftUI

/// Punto de composición: crea el backend y los stores y los inyecta en el entorno de SwiftUI.
/// Las vistas los leen con `@Environment(SessionStore.self)`, etc.
@MainActor
struct AppModel {
    let session: SessionStore
    let group: GroupStore
    let lists: ListsStore

    init(backend: any Backend) {
        session = SessionStore(backend: backend)
        group = GroupStore(backend: backend)
        lists = ListsStore(backend: backend)
    }

    /// Con la sesión ya resuelta (previews, capturas y tests).
    init(backend: any Backend, user: User?) {
        session = SessionStore(backend: backend, user: user)
        group = GroupStore(backend: backend)
        lists = ListsStore(backend: backend)
    }
}

extension View {
    /// Inyecta los stores y el estilo común de la app.
    @MainActor func appEnvironment(_ model: AppModel) -> some View {
        self
            .environment(model.session)
            .environment(model.group)
            .environment(model.lists)
            .appStyle()
    }

    /// Tipografía Inter por defecto, tinte de marca y formato de fechas en español.
    @MainActor func appStyle() -> some View {
        self
            .font(.bodyLarge)
            .tint(.brand)
            .environment(\.locale, .appLocale)
    }
}

extension Locale {
    /// La app solo está en español: si el dispositivo no lo está, se usa español de España.
    static let appLocale: Locale = Locale.current.language.languageCode == .spanish ? .current : Locale(identifier: "es_ES")
}
