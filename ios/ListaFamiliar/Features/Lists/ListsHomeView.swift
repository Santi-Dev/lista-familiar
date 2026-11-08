import SwiftUI

struct ListsHomeView: View {
    @Environment(GroupStore.self) private var group
    @Environment(ListsStore.self) private var lists
    @State private var path: [UUID] = []
    @State private var showArchived = false
    @State private var isCreating = false
    @State private var renaming: ShoppingList?
    @State private var renameText = ""
    @State private var deleting: ShoppingList?
    @State private var toast: String?

    private var visibleLists: [ShoppingList] { lists.lists(archived: showArchived) }
    private var loadState: LoadState { lists.state(archived: showArchived) }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .screenBackground()
                .navigationTitle("Mis listas")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Nueva lista", systemImage: "plus") { isCreating = true }
                    }
                }
                .navigationDestination(for: UUID.self) { ListDetailView(listID: $0) }
                .sheet(isPresented: $isCreating) {
                    CreateListSheet { path.append($0.id) }
                }
                .alert("Renombrar lista", isPresented: $renaming.isPresent(), presenting: renaming) { list in
                    TextField("Nombre", text: $renameText)
                    Button("Cancelar", role: .cancel) {}
                    Button("Guardar") { rename(list) }
                        .disabled(!NameInput.isValid(renameText))
                }
                .confirmationDialog(
                    "¿Eliminar «\(deleting?.name ?? "")»? Se borrarán todos sus artículos.",
                    isPresented: $deleting.isPresent(), titleVisibility: .visible, presenting: deleting
                ) { list in
                    Button("Eliminar", role: .destructive) { delete(list) }
                }
                .refreshable { await lists.load(archived: showArchived) }
                .task(id: showArchived) { await lists.load(archived: showArchived) }
                .toast($toast)
        }
    }

    private var content: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                if let group = group.group {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.textPrimary)
                        Text(group.members.count == 1 ? "1 miembro" : "\(group.members.count) miembros")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                    }
                }

                Picker("Mostrar", selection: $showArchived) {
                    Text("Activas").tag(false)
                    Text("Archivadas").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.vertical, Theme.Spacing.sm)

                listsSection
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .animation(.default, value: visibleLists)
    }

    @ViewBuilder
    private var listsSection: some View {
        if visibleLists.isEmpty {
            switch loadState {
            case .idle, .loading:
                PlaceholderRows(count: 3, height: 110).padding(-Theme.Spacing.lg)
            case .failed(let message):
                ErrorStateView(message: message) { Task { await lists.load(archived: showArchived) } }
                    .padding(.top, Theme.Spacing.xl)
            case .loaded where showArchived:
                EmptyStateView(icon: "archivebox", title: "No tienes listas archivadas")
                    .padding(.top, Theme.Spacing.xl)
            case .loaded:
                EmptyStateView(
                    icon: "cart.badge.plus", title: "Aún no tienes listas",
                    message: "Crea la primera, por ejemplo «Mercado semanal».",
                    actionTitle: "Crear lista") { isCreating = true }
                    .padding(.top, Theme.Spacing.xl)
            }
        } else {
            ForEach(visibleLists) { list in
                NavigationLink(value: list.id) {
                    ListCard(list: list)
                }
                .buttonStyle(.plain)
                .contextMenu { menu(for: list) }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private func menu(for list: ShoppingList) -> some View {
        Button(list.isArchived ? "Desarchivar" : "Archivar",
               systemImage: list.isArchived ? "tray.and.arrow.up" : "archivebox") {
            run { try await lists.setArchived(!list.isArchived, listID: list.id) }
        }
        Button("Renombrar", systemImage: "pencil") {
            renameText = list.name
            renaming = list
        }
        Button("Eliminar", systemImage: "trash", role: .destructive) { deleting = list }
    }

    private func rename(_ list: ShoppingList) {
        let name = renameText
        run { try await lists.rename(list.id, to: name) }
    }

    private func delete(_ list: ShoppingList) {
        run { try await lists.delete(list.id) }
    }

    private func run(_ work: @escaping () async throws -> Void) {
        Task {
            do { try await work() } catch { toast = error.userMessage }
        }
    }
}

extension Binding {
    /// `true` mientras el opcional tenga valor; al poner `false` lo vacía. Útil para alertas y diálogos.
    func isPresent<Wrapped: Sendable>() -> Binding<Bool> where Value == Wrapped? {
        Binding<Bool>(
            get: { wrappedValue != nil },
            set: { if !$0 { wrappedValue = nil } })
    }
}

#Preview {
    ListsHomeView().previewEnvironment()
}
