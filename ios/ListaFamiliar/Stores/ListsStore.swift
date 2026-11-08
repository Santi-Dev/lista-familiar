import Foundation
import Observation

/// Listas de la compra y sus artículos: una sola fuente de verdad para «Mis listas» y el detalle.
///
/// Los cambios se aplican primero en local (la interfaz responde al instante) y después en el
/// servidor; si el servidor falla, se deshacen y se lanza el error para que la vista avise.
@Observable @MainActor
final class ListsStore {
    /// Todas las listas conocidas, activas y archivadas.
    private(set) var lists: [UUID: ShoppingList] = [:]
    private(set) var state: [Bool: LoadState] = [:]
    /// Artículos por lista (solo de las listas que se han abierto).
    private(set) var items: [UUID: [ListItem]] = [:]
    private(set) var itemsState: [UUID: LoadState] = [:]

    private let backend: any Backend

    init(backend: any Backend) {
        self.backend = backend
    }

    // MARK: - Lectura

    /// Las fijadas primero; dentro de cada grupo, las modificadas más recientemente.
    func lists(archived: Bool) -> [ShoppingList] {
        lists.values.filter { $0.isArchived == archived }.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned { return lhs.isPinned }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    func state(archived: Bool) -> LoadState { state[archived] ?? .idle }

    func list(_ id: UUID) -> ShoppingList? { lists[id] }

    func items(in listID: UUID) -> [ListItem] { items[listID] ?? [] }

    func itemsState(for listID: UUID) -> LoadState { itemsState[listID] ?? .idle }

    // MARK: - Carga

    func load(archived: Bool) async {
        if lists(archived: archived).isEmpty { state[archived] = .loading }
        do {
            let fetched = try await backend.fetchLists(archived: archived)
            lists = lists.filter { $0.value.isArchived != archived }
            for list in fetched { lists[list.id] = list }
            state[archived] = .loaded
        } catch {
            // Si ya hay datos, se mantienen: un fallo puntual de red no vacía la pantalla.
            if lists(archived: archived).isEmpty { state[archived] = .failed(error.userMessage) }
        }
    }

    /// Carga la lista y sus artículos. Si ya no existe, la olvida y lanza `AppError.notFound`.
    func loadDetail(_ listID: UUID) async throws {
        if items[listID] == nil { itemsState[listID] = .loading }
        do {
            async let list = backend.fetchList(id: listID)
            async let listItems = backend.fetchItems(listID: listID)
            let (summary, fetched) = try await (list, listItems)
            lists[listID] = summary
            items[listID] = fetched
            itemsState[listID] = .loaded
        } catch AppError.notFound {
            forget(listID)
            throw AppError.notFound
        } catch {
            if items[listID] == nil { itemsState[listID] = .failed(error.userMessage) }
        }
    }

    /// Recarga todo lo que ya se ha cargado (al volver a la app o cuando avisa Realtime).
    func refresh() async {
        for archived in state.keys { await load(archived: archived) }
        for listID in items.keys { try? await loadDetail(listID) }
    }

    /// Recarga cuando Supabase Realtime avisa de un cambio. Vive mientras dure la tarea que la llama.
    func observeChanges() async {
        for await _ in backend.changes() {
            await refresh()
        }
    }

    // MARK: - Listas

    func createList(named name: String, groupID: UUID) async throws -> ShoppingList {
        try await createList(ListDraft(name: name), groupID: groupID)
    }

    func createList(_ draft: ListDraft, groupID: UUID) async throws -> ShoppingList {
        let list = try await backend.createList(draft, groupID: groupID)
        lists[list.id] = list
        items[list.id] = []
        itemsState[list.id] = .loaded
        return list
    }

    /// Guarda nombre, icono, tienda y «fijada» a la vez.
    func update(_ listID: UUID, with draft: ListDraft) async throws {
        guard draft.isValid else { return }
        try await mutate(listID, {
            $0.name = draft.cleanName
            $0.icon = draft.icon
            $0.store = draft.cleanStore
            $0.isPinned = draft.isPinned
        }) {
            try await self.backend.updateList(id: listID, ListChanges(draft: draft))
        }
    }

    func setPinned(_ isPinned: Bool, listID: UUID) async throws {
        try await mutate(listID, { $0.isPinned = isPinned }) {
            try await self.backend.updateList(id: listID, ListChanges(isPinned: isPinned))
        }
    }

    func rename(_ listID: UUID, to name: String) async throws {
        let name = NameInput.clean(name)
        guard !name.isEmpty else { return }
        try await mutate(listID, { $0.name = name }) {
            try await self.backend.updateList(id: listID, ListChanges(name: name))
        }
    }

    func setArchived(_ isArchived: Bool, listID: UUID) async throws {
        try await mutate(listID, { $0.isArchived = isArchived }) {
            try await self.backend.updateList(id: listID, ListChanges(isArchived: isArchived))
        }
    }

    func delete(_ listID: UUID) async throws {
        let snapshot = (lists[listID], items[listID], itemsState[listID])
        forget(listID)
        do {
            try await backend.deleteList(id: listID)
        } catch {
            lists[listID] = snapshot.0
            items[listID] = snapshot.1
            itemsState[listID] = snapshot.2
            throw error
        }
    }

    private func mutate(
        _ listID: UUID,
        _ change: (inout ShoppingList) -> Void,
        remote: @escaping () async throws -> ShoppingList
    ) async throws {
        guard let original = lists[listID] else { return }
        var updated = original
        change(&updated)
        lists[listID] = updated
        do {
            lists[listID] = try await remote()
        } catch {
            lists[listID] = original
            throw error
        }
    }

    private func forget(_ listID: UUID) {
        lists[listID] = nil
        items[listID] = nil
        itemsState[listID] = nil
    }

    // MARK: - Artículos

    @discardableResult
    func addItem(_ draft: ItemDraft, to listID: UUID) async throws -> ListItem {
        let item = try await backend.createItem(in: listID, draft)
        items[listID, default: []].append(item)
        syncCounts(listID, touched: true)
        return item
    }

    /// `members` sirve para mostrar al instante a quién se ha asignado el artículo; la respuesta del servidor
    /// sustituye después al valor local.
    func updateItem(_ item: ListItem, with draft: ItemDraft, members: [Member] = []) async throws {
        let assignee = draft.assigneeID.flatMap { id in members.first(where: { $0.id == id }) }
        try await mutateItem(item, {
            $0.name = draft.cleanName
            $0.quantity = draft.cleanQuantity
            $0.category = draft.category
            $0.note = draft.cleanNote
            $0.isUrgent = draft.isUrgent
            $0.assignee = assignee
        }) {
            try await self.backend.updateItem(id: item.id, draft)
        }
    }

    func togglePurchased(_ item: ListItem) async throws {
        let purchased = !item.isPurchased
        try await mutateItem(item, { $0.isPurchased = purchased; if !purchased { $0.purchasedBy = nil } }) {
            try await self.backend.setPurchased(purchased, itemID: item.id)
        }
    }

    func deleteItem(_ item: ListItem) async throws {
        guard let index = items[item.listID]?.firstIndex(where: { $0.id == item.id }) else { return }
        let removed = items[item.listID]!.remove(at: index)
        syncCounts(item.listID, touched: true)
        do {
            try await backend.deleteItem(id: item.id)
        } catch {
            items[item.listID]?.insert(removed, at: min(index, items[item.listID]?.count ?? 0))
            syncCounts(item.listID, touched: false)
            throw error
        }
    }

    private func mutateItem(
        _ item: ListItem,
        _ change: (inout ListItem) -> Void,
        remote: @escaping () async throws -> ListItem
    ) async throws {
        let listID = item.listID
        guard let index = items[listID]?.firstIndex(where: { $0.id == item.id }) else { return }
        let original = items[listID]![index]
        change(&items[listID]![index])
        syncCounts(listID, touched: true)
        do {
            let saved = try await remote()
            if let index = items[listID]?.firstIndex(where: { $0.id == saved.id }) { items[listID]![index] = saved }
        } catch {
            if let index = items[listID]?.firstIndex(where: { $0.id == original.id }) { items[listID]![index] = original }
            syncCounts(listID, touched: false)
            throw error
        }
    }

    /// Mantiene los contadores del resumen de la lista al día con sus artículos.
    private func syncCounts(_ listID: UUID, touched: Bool) {
        guard var list = lists[listID], let listItems = items[listID] else { return }
        list.itemCount = listItems.count
        list.purchasedCount = listItems.count(where: \.isPurchased)
        if touched { list.updatedAt = Date() }
        lists[listID] = list
    }

    /// Olvida todo (al cerrar sesión o salir del grupo).
    func reset() {
        lists = [:]
        state = [:]
        items = [:]
        itemsState = [:]
    }
}
