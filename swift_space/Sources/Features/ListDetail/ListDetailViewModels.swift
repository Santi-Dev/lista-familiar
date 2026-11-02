import Foundation
import Observation

@Observable @MainActor
final class ListDetailViewModel {
    let listId: String
    private(set) var listInfo: ShoppingListSummaryDto?
    private(set) var items: [ListItemDto] = []
    private(set) var isLoading = true
    private(set) var errorMsg: String?
    /// La lista ya no existe o no es accesible: la vista debe cerrarse.
    private(set) var isGone = false
    var selectedCategory: ItemCategory?
    private(set) var toastMessage: String?

    private let backend: any Backend

    init(listId: String, backend: any Backend = APIClient.shared) {
        self.listId = listId
        self.backend = backend
    }

    // MARK: - Estado derivado

    var filteredItems: [ListItemDto] {
        guard let cat = selectedCategory else { return items }
        return items.filter { $0.category == cat.rawValue }
    }

    var groupedItems: [(ItemCategory, [ListItemDto])] {
        let grouped = Dictionary(grouping: filteredItems) { ItemCategory.from($0.category) }
        return ItemCategory.allCases.compactMap { cat in
            guard let catItems = grouped[cat], !catItems.isEmpty else { return nil }
            return (cat, catItems)
        }
    }

    func pendingCount(in category: ItemCategory) -> Int {
        items.filter { $0.category == category.rawValue && !$0.isPurchased }.count
    }

    // MARK: - Carga

    func load() async {
        do {
            let response = try await backend.getListItems(id: listId)
            items = response.items
            listInfo = response.list
            errorMsg = nil
        } catch {
            if case APIError.http(let status, _)? = error as? APIError, status == 404 || status == 403 {
                isGone = true
                return
            }
            if items.isEmpty { errorMsg = "No se pudo cargar la lista" }
        }
        isLoading = false
    }

    /// Recarga cuando Supabase Realtime avisa de un cambio.
    func observeChanges() async {
        for await _ in backend.changes(tables: ["shopping_lists", "list_items"]) {
            await load()
        }
    }

    /// Respaldo por si Realtime se cae: recarga cada 30 s mientras la app está activa.
    func poll(isActive: @MainActor () -> Bool) async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(30))
            guard isActive() else { continue }
            await load()
        }
    }

    // MARK: - Acciones

    func togglePurchased(_ item: ListItemDto) async {
        do {
            _ = try await backend.updateItem(id: item.id, body: UpdateItemDto(isPurchased: !item.isPurchased))
            await load()
        } catch {
            showToast("No se pudo actualizar")
        }
    }

    func deleteItem(_ itemId: String) async {
        _ = try? await backend.deleteItem(id: itemId)
        await load()
    }

    func toggleArchive() async {
        guard let info = listInfo else { return }
        _ = try? await backend.update(id: listId, body: UpdateListDto(isArchived: !info.isArchived))
        await load()
    }

    func rename(to name: String) async {
        guard !name.isEmpty else { return }
        _ = try? await backend.update(id: listId, body: UpdateListDto(name: name))
        await load()
    }

    func deleteList() async {
        _ = try? await backend.delete(id: listId)
        isGone = true
    }

    func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if toastMessage == message { toastMessage = nil }
        }
    }
}

@Observable @MainActor
final class ItemFormViewModel {
    let listId: String
    let editItem: ListItemDto?
    var name = ""
    var quantity = ""
    var category: ItemCategory
    private(set) var isLoading = false
    private(set) var errorMsg: String?

    private let backend: any Backend

    init(listId: String, editItem: ListItemDto?, preselectedCategory: ItemCategory, backend: any Backend = APIClient.shared) {
        self.listId = listId
        self.editItem = editItem
        self.backend = backend
        if let item = editItem {
            name = item.name
            quantity = item.quantity ?? ""
            category = ItemCategory.from(item.category)
        } else {
            category = preselectedCategory
        }
    }

    var isEdit: Bool { editItem != nil }
    var canSave: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty && !isLoading }

    /// Guarda el artículo. Devuelve el nombre guardado, o nil si falló.
    /// Con `resetAfter` (solo al añadir) deja el formulario vacío para añadir otro.
    func save(resetAfter: Bool) async -> String? {
        isLoading = true
        errorMsg = nil
        defer { isLoading = false }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let qty = quantity.isEmpty ? nil : quantity
        do {
            if let editItem {
                _ = try await backend.updateItem(id: editItem.id, body: UpdateItemDto(name: trimmed, quantity: qty, category: category.rawValue))
            } else {
                _ = try await backend.createItem(id: listId, body: CreateItemDto(name: trimmed, quantity: qty, category: category.rawValue))
                if resetAfter {
                    name = ""
                    quantity = ""
                }
            }
            return trimmed
        } catch {
            errorMsg = "No se pudo guardar"
            return nil
        }
    }

    func delete() async {
        guard let item = editItem else { return }
        _ = try? await backend.deleteItem(id: item.id)
    }
}
