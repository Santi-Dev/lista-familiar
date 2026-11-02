import Foundation
import Observation

@Observable @MainActor
final class ListsHomeViewModel {
    private(set) var lists: [ShoppingListSummaryDto] = []
    private(set) var group: FamilyGroupDto?
    private(set) var isLoading = true
    private(set) var errorMsg: String?
    var showArchived = false

    private let backend: any Backend

    init(backend: any Backend = APIClient.shared) {
        self.backend = backend
    }

    func loadGroup() async {
        group = try? await backend.myGroup()
    }

    func loadLists() async {
        do {
            lists = try await backend.getLists(archived: showArchived ? "true" : "false").items
            errorMsg = nil
        } catch {
            if lists.isEmpty { errorMsg = "No se pudieron cargar las listas" }
        }
        isLoading = false
    }

    func toggleArchive(_ list: ShoppingListSummaryDto) async {
        _ = try? await backend.update(id: list.id, body: UpdateListDto(isArchived: !list.isArchived))
        await loadLists()
    }

    func rename(id: String, to name: String) async {
        guard !name.isEmpty else { return }
        _ = try? await backend.update(id: id, body: UpdateListDto(name: name))
        await loadLists()
    }

    func delete(id: String) async {
        _ = try? await backend.delete(id: id)
        await loadLists()
    }

    /// Recarga cuando Supabase Realtime avisa de un cambio en las listas o sus artículos.
    func observeChanges() async {
        for await _ in backend.changes(tables: ["shopping_lists", "list_items"]) {
            await loadLists()
        }
    }

    /// Respaldo por si Realtime se cae: recarga cada 30 s mientras la app está activa.
    func poll(isActive: @MainActor () -> Bool) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard isActive() else { continue }
            await loadLists()
        }
    }
}

@Observable @MainActor
final class CreateListViewModel {
    var name = ""
    private(set) var isLoading = false

    private let backend: any Backend

    init(backend: any Backend = APIClient.shared) {
        self.backend = backend
    }

    var canCreate: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading }

    /// Devuelve el id de la lista creada, o nil si falló.
    func create() async -> String? {
        isLoading = true
        do {
            let list = try await backend.create(body: CreateListDto(name: name))
            return list.id
        } catch {
            isLoading = false
            return nil
        }
    }
}
