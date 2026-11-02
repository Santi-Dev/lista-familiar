import SwiftUI
import os

private let logger = Logger(subsystem: "com.app.familyshoppinglists", category: "ListsHome")

struct ListsHomeView: View {
    @Environment(SessionModel.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @State private var lists: [ShoppingListSummaryDto] = []
    @State private var group: FamilyGroupDto?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var showArchived = false
    @State private var showCreateSheet = false
    @State private var navPath = NavigationPath()
    @State private var renameListId: String?
    @State private var renameText = ""
    @State private var deleteListId: String?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack(path: $navPath) {
            ZStack(alignment: .bottomTrailing) {
                mainContent
                fab
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(group?.name ?? "Mis Listas")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { listId in
                ListDetailView(listId: listId)
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateListSheet { newId in
                    navPath.append(newId)
                }
            }
            .alert("Renombrar lista", isPresented: Binding(get: { renameListId != nil }, set: { if !$0 { renameListId = nil } })) {
                TextField("Nombre", text: $renameText)
                Button("Cancelar", role: .cancel) { renameListId = nil }
                Button("Guardar") { Task { await doRename() } }
            }
            .confirmationDialog("¿Eliminar esta lista? Se borrarán todos sus artículos.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) { Task { await doDelete() } }
                Button("Cancelar", role: .cancel) { deleteListId = nil }
            }
            .refreshable { await loadData() }
            .task { await loadGroup(); await loadData() }
            .task(id: showArchived) { await loadData() }
            .task { for await _ in APIClient.shared.changes(tables: ["shopping_lists", "list_items"]) { await loadData() } }
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(30))
                    guard scenePhase == .active else { continue }
                    await loadData()
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(spacing: 0) {
            if let memberCount = group?.members.count {
                Text("\(memberCount) miembros")
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.Spacing.lg)
            }
            Picker("", selection: $showArchived) {
                Text("Activas").tag(false)
                Text("Archivadas").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)

            if isLoading && lists.isEmpty {
                skeletonCards
            } else if let errorMsg {
                Spacer()
                ErrorStateView(message: errorMsg) { Task { await loadData() } }
                Spacer()
            } else if lists.isEmpty {
                Spacer()
                if showArchived {
                    EmptyStateView(icon: "archivebox", title: "No hay listas archivadas", subtitle: "")
                } else {
                    EmptyStateView(icon: "cart.badge.plus", title: "Aún no hay listas", subtitle: "Crea la primera, por ejemplo 'Mercado semanal'.", buttonTitle: "Crear lista") {
                        showCreateSheet = true
                    }
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.Spacing.sm) {
                        ForEach(lists, id: \.id) { list in
                            listCard(list)
                        }
                    }
                    .padding(Theme.Spacing.lg)
                    .padding(.bottom, 80)
                }
            }
        }
    }

    private func listCard(_ list: ShoppingListSummaryDto) -> some View {
        Button {
            navPath.append(list.id)
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(list.name)
                    .font(.headline)
                    .fontDesign(.rounded)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text("\(Int(list.purchasedCount)) de \(Int(list.itemCount)) comprados")
                    .font(.subheadline)
                    .fontDesign(.rounded)
                    .foregroundColor(Theme.Colors.textSecondary)
                ProgressView(value: list.itemCount > 0 ? list.purchasedCount / list.itemCount : 0)
                    .tint(Theme.Colors.brand)
                HStack {
                    if let createdBy = list.createdBy?.asUserPublic {
                        Text("Creada por \(createdBy.name)")
                    }
                    Spacer()
                    Text(relativeDate(list.updatedAt))
                }
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textSecondary)
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radii.card).fill(Theme.Colors.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radii.card).stroke(Theme.Colors.separator, lineWidth: 0.5))
        }
        .contextMenu {
            Button { Task { await toggleArchive(list) } } label: {
                Label(list.isArchived ? "Desarchivar" : "Archivar", systemImage: list.isArchived ? "tray.and.arrow.up" : "archivebox")
            }
            Button {
                renameText = list.name
                renameListId = list.id
            } label: {
                Label("Renombrar", systemImage: "pencil")
            }
            Button(role: .destructive) {
                deleteListId = list.id
                showDeleteConfirm = true
            } label: {
                Label("Eliminar", systemImage: "trash")
            }
        }
    }

    private var fab: some View {
        Button { showCreateSheet = true } label: {
            Image(systemName: "plus")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Circle().fill(Theme.Colors.brand))
                .shadow(color: .black.opacity(0.15), radius: 12, x: 0, y: 4)
        }
        .padding(Theme.Spacing.lg)
    }

    private var skeletonCards: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.Radii.card)
                    .fill(Theme.Colors.surface)
                    .frame(height: 100)
                    .redacted(reason: .placeholder)
            }
        }
        .padding(Theme.Spacing.lg)
    }

    private func loadGroup() async {
        do {
            let g: FamilyGroupDto = try await APIClient.shared.myGroup()
            group = g
        } catch {
            logger.error("loadGroup: \(error.localizedDescription)")
        }
    }

    private func loadData() async {
        do {
            let response = try await APIClient.shared.getLists(archived: showArchived ? "true" : "false")
            lists = response.items
            errorMsg = nil
        } catch {
            if lists.isEmpty { errorMsg = "No se pudieron cargar las listas" }
        }
        isLoading = false
    }

    private func toggleArchive(_ list: ShoppingListSummaryDto) async {
        _ = try? await APIClient.shared.update(id: list.id, body: UpdateListDto(isArchived: !list.isArchived))
        await loadData()
    }

    private func doRename() async {
        guard let id = renameListId, !renameText.isEmpty else { return }
        _ = try? await APIClient.shared.update(id: id, body: UpdateListDto(name: renameText))
        renameListId = nil
        await loadData()
    }

    private func doDelete() async {
        guard let id = deleteListId else { return }
        _ = try? await APIClient.shared.delete(id: id)
        deleteListId = nil
        await loadData()
    }

    private func relativeDate(_ iso: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return "" }
        let rel = RelativeDateTimeFormatter()
        rel.locale = Locale(identifier: "es_ES")
        return rel.localizedString(for: date, relativeTo: Date())
    }
}
