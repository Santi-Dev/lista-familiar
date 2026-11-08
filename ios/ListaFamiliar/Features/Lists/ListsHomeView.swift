import SwiftUI

struct ListsHomeView: View {
    private enum Filter: Hashable {
        case all, pending, completed, archived
    }

    @Environment(GroupStore.self) private var group
    @Environment(ListsStore.self) private var lists
    @Environment(SessionStore.self) private var session
    @State private var path: [UUID] = []
    @State private var filter = Filter.all
    @State private var searchText = ""
    @State private var isCreating = false
    @State private var editingList: ShoppingList?
    @State private var deleting: ShoppingList?
    @State private var toast: String?

    /// Los lectores consultan las listas, pero no las cambian.
    private var canEdit: Bool { group.role(of: session.user?.id).canEdit }
    private var showArchived: Bool { filter == .archived }
    private var loadState: LoadState { lists.state(archived: showArchived) }

    private var activeLists: [ShoppingList] { lists.lists(archived: false) }
    private var completedCount: Int { activeLists.count(where: \.isComplete) }

    private var visibleLists: [ShoppingList] {
        let base = lists.lists(archived: showArchived).filter { list in
            switch filter {
            case .all, .archived: true
            case .pending: !list.isComplete
            case .completed: list.isComplete
            }
        }
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return query.isEmpty ? base : base.filter { $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            content
                .screenBackground()
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: UUID.self) { ListDetailView(listID: $0) }
                .sheet(isPresented: $isCreating) {
                    ListFormSheet { path.append($0.id) }
                }
                .sheet(item: $editingList) { list in
                    ListFormSheet(mode: .edit(list))
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
            LazyVStack(alignment: .leading, spacing: Theme.Spacing.md) {
                titleBar
                groupCard
                searchField
                filterChips
                listsSection
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .animation(.default, value: visibleLists)
    }

    // MARK: - Cabecera

    private var titleBar: some View {
        HStack(alignment: .center) {
            Text("Mis listas")
                .font(.headlineLarge)
                .foregroundStyle(.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: Theme.Spacing.sm)
            if canEdit {
                Button { isCreating = true } label: {
                    Label("Nueva", systemImage: "plus")
                        .font(.headlineSmall)
                        .foregroundStyle(.white)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, 10)
                        .brandSurface(in: .capsule)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Nueva lista")
            }
        }
    }

    @ViewBuilder
    private var groupCard: some View {
        if let group = group.group {
            HStack(spacing: Theme.Spacing.md) {
                AvatarStack(names: group.members.map(\.name), maxVisible: 3, size: 36)
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headlineSmall)
                        .foregroundStyle(.textPrimary)
                    Text(group.members.count == 1 ? "1 miembro" : "\(group.members.count) miembros")
                        .font(.bodySmall)
                        .foregroundStyle(.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
            .accessibilityElement(children: .combine)
        }
    }

    private var searchField: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.textSecondary)
                .accessibilityHidden(true)
            TextField("Buscar listas", text: $searchText)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button("Borrar búsqueda", systemImage: "xmark.circle.fill") { searchText = "" }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.textSecondary)
                    .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, 12)
        .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.field))
        .overlay {
            RoundedRectangle(cornerRadius: Theme.Radius.field).strokeBorder(Color.hairline, lineWidth: 1)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                chip("Todas", count: activeLists.count, for: .all)
                chip("Pendientes", count: activeLists.count - completedCount, for: .pending)
                chip("Completadas", count: completedCount, for: .completed)
                chip("Archivadas", count: nil, for: .archived)
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .padding(.horizontal, -Theme.Spacing.lg)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: filter)
    }

    private func chip(_ title: String, count: Int?, for value: Filter) -> some View {
        let isSelected = filter == value
        return Button { filter = value } label: {
            HStack(spacing: Theme.Spacing.xs) {
                Text(title)
                if let count { Text("(\(count))") }
            }
            .font(.labelMedium)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .chipSurface(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Listas

    @ViewBuilder
    private var listsSection: some View {
        if visibleLists.isEmpty {
            if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
                EmptyStateView(icon: "magnifyingglass", title: "Sin resultados",
                               message: "Prueba con otro nombre.")
                    .padding(.top, Theme.Spacing.lg)
            } else {
                switch loadState {
                case .idle, .loading:
                    PlaceholderRows(count: 3, height: 110).padding(-Theme.Spacing.lg)
                case .failed(let message):
                    ErrorStateView(message: message) { Task { await lists.load(archived: showArchived) } }
                        .padding(.top, Theme.Spacing.xl)
                case .loaded where showArchived:
                    EmptyStateView(icon: "archivebox", title: "No tienes listas archivadas")
                        .padding(.top, Theme.Spacing.xl)
                case .loaded where filter == .completed:
                    EmptyStateView(icon: "checkmark.seal", title: "Aún no has completado ninguna lista")
                        .padding(.top, Theme.Spacing.xl)
                case .loaded where filter == .pending && !activeLists.isEmpty:
                    EmptyStateView(icon: "checkmark.seal", title: "¡No te queda nada pendiente!")
                        .padding(.top, Theme.Spacing.xl)
                case .loaded:
                    EmptyStateView(
                        icon: "cart.badge.plus", title: "Aún no tienes listas",
                        message: "Crea la primera, por ejemplo «Mercado semanal».",
                        actionTitle: "Crear lista") { isCreating = true }
                        .padding(.top, Theme.Spacing.xl)
                }
            }
        } else {
            ForEach(visibleLists) { list in
                NavigationLink(value: list.id) {
                    ListCard(list: list)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    if canEdit { menu(for: list) }
                }
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
        Button(list.isPinned ? "Quitar de fijadas" : "Fijar al inicio",
               systemImage: list.isPinned ? "pin.slash" : "pin") {
            run { try await lists.setPinned(!list.isPinned, listID: list.id) }
        }
        Button("Editar", systemImage: "pencil") { editingList = list }
        Button("Eliminar", systemImage: "trash", role: .destructive) { deleting = list }
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
