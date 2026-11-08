import SwiftUI

struct ListDetailView: View {
    let listID: UUID

    @Environment(ListsStore.self) private var lists
    @Environment(\.dismiss) private var dismiss
    @State private var filter: ItemCategory?
    @State private var isAdding = false
    @State private var editing: ListItem?
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var isConfirmingDelete = false
    @State private var toast: String?

    private var list: ShoppingList? { lists.list(listID) }
    private var items: [ListItem] { lists.items(in: listID) }
    private var sections: [ItemSection] { items.sectioned(filter: filter) }

    var body: some View {
        content
            .toast($toast) // antes del botón inferior, para que el aviso quede encima de él
            .safeAreaInset(edge: .bottom) {
                if list != nil {
                    Button("Añadir artículo", systemImage: "plus") { isAdding = true }
                        .buttonStyle(.primary)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.bottom, Theme.Spacing.sm)
                }
            }
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { listMenu }
            }
            .alert("Renombrar lista", isPresented: $isRenaming) {
                TextField("Nombre", text: $renameText)
                Button("Cancelar", role: .cancel) {}
                Button("Guardar") {
                    let name = renameText
                    run { try await lists.rename(listID, to: name) }
                }
                .disabled(!NameInput.isValid(renameText))
            }
            .confirmationDialog("¿Eliminar la lista? Se borrarán todos sus artículos.",
                                isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    run {
                        try await lists.delete(listID)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $isAdding) {
                ItemFormSheet(listID: listID, mode: .add(category: filter ?? .other)) { name in
                    toast = "Añadido: \(name)"
                }
            }
            .sheet(item: $editing) { item in
                ItemFormSheet(listID: listID, mode: .edit(item)) { _ in }
            }
            .task { await load() }
    }

    // MARK: - Contenido

    @ViewBuilder
    private var content: some View {
        switch (list, lists.itemsState(for: listID)) {
        case (nil, .failed(let message)):
            ErrorStateView(message: message) { Task { await load() } }
        case (nil, _):
            PlaceholderRows(count: 6)
        case (let list?, _):
            VStack(spacing: 0) {
                header(list)
                CategoryFilterBar(selection: $filter, items: items)
                if sections.isEmpty {
                    emptyState
                } else {
                    itemList
                }
            }
            .animation(.default, value: filter)
        }
    }

    private func header(_ list: ShoppingList) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(list.name)
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
                .lineLimit(3)
                .accessibilityAddTraits(.isHeader)
            Text("\(list.purchasedCount)/\(list.itemCount) comprados")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
                .contentTransition(.numericText())
                .animation(.default, value: list.purchasedCount)
            if list.isArchived {
                HStack {
                    Label("Lista archivada", systemImage: "archivebox.fill")
                    Spacer()
                    Button("Desarchivar") { setArchived(false) }
                        .fontWeight(.semibold)
                }
                .font(.subheadline)
                .foregroundStyle(.highlight)
                .padding(Theme.Spacing.sm)
                .padding(.horizontal, Theme.Spacing.xs)
                .background(Color.highlight.opacity(0.12), in: .rect(cornerRadius: 8))
                .padding(.top, Theme.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.top, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let filter {
            EmptyStateView(icon: "magnifyingglass", title: "No hay artículos en \(filter.title)")
        } else {
            EmptyStateView(
                icon: "basket", title: "La lista está vacía",
                message: "Añade lo que necesitas comprar.")
        }
    }

    private var itemList: some View {
        List {
            ForEach(sections) { section in
                Section {
                    ForEach(section.items) { item in
                        ItemRow(item: item, onToggle: { toggle(item) }, onEdit: { editing = item })
                            .swipeActions(edge: .trailing) {
                                Button("Eliminar", systemImage: "trash", role: .destructive) {
                                    run { try await lists.deleteItem(item) }
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button(item.isPurchased ? "Pendiente" : "Comprado",
                                       systemImage: item.isPurchased ? "arrow.uturn.backward" : "checkmark") {
                                    toggle(item)
                                }
                                .tint(.brand)
                            }
                    }
                } header: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: section.category.symbol)
                            .foregroundStyle(.brand)
                        Text(section.category.title)
                        if section.pendingCount > 0 { CountBadge(count: section.pendingCount) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .animation(.default, value: items)
    }

    private var listMenu: some View {
        Menu {
            Button("Renombrar lista", systemImage: "pencil") {
                renameText = list?.name ?? ""
                isRenaming = true
            }
            if let list {
                Button(list.isArchived ? "Desarchivar lista" : "Archivar lista", systemImage: "archivebox") {
                    setArchived(!list.isArchived)
                }
            }
            Button("Eliminar lista", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
        } label: {
            Label("Opciones de la lista", systemImage: "ellipsis.circle")
        }
        .disabled(list == nil)
    }

    // MARK: - Acciones

    private func load() async {
        do {
            try await lists.loadDetail(listID)
        } catch {
            // La lista se borró (o ya no es de tu grupo): vuelve a «Mis listas».
            dismiss()
        }
    }

    private func toggle(_ item: ListItem) {
        run { try await lists.togglePurchased(item) }
    }

    private func setArchived(_ archived: Bool) {
        run { try await lists.setArchived(archived, listID: listID) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work() } catch { toast = error.userMessage }
        }
    }
}

#Preview {
    NavigationStack { ListDetailView(listID: SampleData.firstListID) }
        .previewEnvironment()
}
