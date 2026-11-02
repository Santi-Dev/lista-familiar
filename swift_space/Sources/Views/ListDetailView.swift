import SwiftUI
import os

private let logger = Logger(subsystem: "com.app.familyshoppinglists", category: "ListDetail")

struct ListDetailView: View {
    let listId: String
    @Environment(SessionModel.self) private var session
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var listInfo: ShoppingListSummaryDto?
    @State private var items: [ListItemDto] = []
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var selectedCategory: ItemCategoryHelper? = nil
    @State private var showAddSheet = false
    @State private var editingItem: ListItemDto?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var toastMessage: String?

    private var filteredItems: [ListItemDto] {
        guard let cat = selectedCategory else { return items }
        return items.filter { $0.category == cat.rawValue }
    }

    private var groupedItems: [(ItemCategoryHelper, [ListItemDto])] {
        let grouped = Dictionary(grouping: filteredItems) { ItemCategoryHelper.from($0.category) }
        return ItemCategoryHelper.allCases.compactMap { cat in
            guard let catItems = grouped[cat], !catItems.isEmpty else { return nil }
            return (cat, catItems)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            addButton
            toastOverlay
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle(listInfo?.name ?? "Lista")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { renameText = listInfo?.name ?? ""; showRenameAlert = true } label: {
                        Label("Renombrar lista", systemImage: "pencil")
                    }
                    Button { Task { await toggleArchive() } } label: {
                        Label(listInfo?.isArchived == true ? "Desarchivar lista" : "Archivar lista", systemImage: "archivebox")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Eliminar lista", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .alert("Renombrar lista", isPresented: $showRenameAlert) {
            TextField("Nombre", text: $renameText)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") { Task { await doRename() } }
        }
        .confirmationDialog("¿Eliminar la lista? Se borrarán todos sus artículos.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await doDelete() } }
        }
        .sheet(isPresented: $showAddSheet) {
            ItemFormSheet(listId: listId, preselectedCategory: selectedCategory ?? .OTROS, onSaved: { name in
                showToast("Añadido: \(name)")
                Task { await loadItems() }
            })
        }
        .sheet(item: $editingItem) { item in
            ItemFormSheet(listId: listId, editItem: item, preselectedCategory: ItemCategoryHelper.from(item.category), onSaved: { _ in
                Task { await loadItems() }
            })
        }
        .task { await loadItems() }
        .task { for await _ in APIClient.shared.changes(tables: ["shopping_lists", "list_items"]) { await loadItems() } }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard scenePhase == .active else { continue }
                await loadItems()
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        if isLoading && items.isEmpty {
            VStack {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(Theme.Colors.surface).frame(height: 52)
                }
            }
            .padding(Theme.Spacing.lg)
            .redacted(reason: .placeholder)
        } else if let errorMsg {
            ErrorStateView(message: errorMsg) { Task { await loadItems() } }
        } else {
            VStack(spacing: 0) {
                if let info = listInfo {
                    HStack {
                        Text("\(Int(info.purchasedCount))/\(Int(info.itemCount)) comprados")
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.sm)

                    if info.isArchived {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Lista archivada")
                            Spacer()
                            Button("Desarchivar") { Task { await toggleArchive() } }
                                .font(.subheadline).fontDesign(.rounded)
                        }
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.accent)
                        .padding(Theme.Spacing.sm)
                        .padding(.horizontal, Theme.Spacing.sm)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.Colors.accent.opacity(0.12)))
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.xs)
                    }
                }

                categoryChips

                if filteredItems.isEmpty {
                    Spacer()
                    if selectedCategory != nil {
                        EmptyStateView(icon: "magnifyingglass", title: "No hay artículos en \(selectedCategory!.label)", subtitle: "")
                    } else {
                        EmptyStateView(icon: "basket", title: "La lista está vacía", subtitle: "Añade lo que necesitáis comprar.", buttonTitle: "Añadir artículo") {
                            showAddSheet = true
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(groupedItems, id: \.0) { cat, catItems in
                            Section {
                                ForEach(catItems, id: \.id) { item in
                                    itemRow(item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task { await deleteItem(item.id) }
                                            } label: {
                                                Label("Eliminar", systemImage: "trash")
                                            }
                                        }
                                }
                            } header: {
                                HStack(spacing: Theme.Spacing.xs) {
                                    Image(systemName: cat.symbol)
                                        .foregroundColor(Theme.Colors.brand)
                                    Text(cat.label)
                                        .fontDesign(.rounded)
                                    let pending = catItems.filter { !$0.isPurchased }.count
                                    if pending > 0 {
                                        Text("\(pending)")
                                            .font(.caption2)
                                            .fontDesign(.rounded)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Theme.Colors.accent))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                    .padding(.bottom, 70)
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                chipButton(label: "Todas", icon: nil, isSelected: selectedCategory == nil) {
                    selectedCategory = nil
                }
                ForEach(ItemCategoryHelper.allCases, id: \.self) { cat in
                    let count = items.filter { $0.category == cat.rawValue && !$0.isPurchased }.count
                    chipButton(label: cat.label, icon: cat.symbol, isSelected: selectedCategory == cat, badge: count) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
    }

    private func chipButton(label: String, icon: String?, isSelected: Bool, badge: Int = 0, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon).font(.caption)
                }
                Text(label).font(.caption).fontDesign(.rounded)
                if badge > 0 {
                    Text("\(badge)")
                        .font(.caption2).fontDesign(.rounded)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(Theme.Colors.accent))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Theme.Colors.brand : Theme.Colors.surface))
            .foregroundColor(isSelected ? .white : Theme.Colors.textPrimary)
            .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.Colors.separator, lineWidth: 0.5))
        }
    }

    private func itemRow(_ item: ListItemDto) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Task { await togglePurchased(item) }
                } label: {
                    Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(item.isPurchased ? Theme.Colors.brand : Theme.Colors.textSecondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.body)
                        .fontDesign(.rounded)
                        .strikethrough(item.isPurchased)
                        .foregroundColor(item.isPurchased ? Theme.Colors.textSecondary : Theme.Colors.textPrimary)
                    if item.isPurchased, let buyer = item.purchasedBy?.asUserPublic {
                        Text("Comprado por \(buyer.name)")
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                    } else if let adder = item.addedBy?.asUserPublic {
                        Text("Añadido por \(adder.name)")
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                Spacer()
                if let qty = item.quantity, !qty.isEmpty {
                    Text(qty)
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.textSecondary)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(minHeight: 52)
        .sensoryFeedback(.impact(weight: .light), trigger: item.isPurchased)
    }

    private var addButton: some View {
        Button { showAddSheet = true } label: {
            Label("Añadir artículo", systemImage: "plus")
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Theme.Colors.brand)
                .cornerRadius(Theme.Radii.button)
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = toastMessage {
            Text(msg)
                .font(.subheadline)
                .fontDesign(.rounded)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .background(Capsule().fill(Theme.Colors.surface).shadow(radius: 4))
                .foregroundColor(Theme.Colors.textPrimary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, 70)
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastMessage = nil }
        }
    }

    private func loadItems() async {
        do {
            let response = try await APIClient.shared.getListItems(id: listId)
            items = response.items
            listInfo = response.list
            errorMsg = nil
        } catch let error as APIError {
            if case .http(let status, _) = error, status == 404 || status == 403 {
                dismiss()
                return
            }
            if items.isEmpty { errorMsg = "No se pudo cargar la lista" }
        } catch {
            if items.isEmpty { errorMsg = "No se pudo cargar la lista" }
        }
        isLoading = false
    }

    private func togglePurchased(_ item: ListItemDto) async {
        do {
            _ = try await APIClient.shared.updateItem(id: item.id, body: UpdateItemDto(isPurchased: !item.isPurchased))
            await loadItems()
        } catch {
            showToast("No se pudo actualizar")
        }
    }

    private func deleteItem(_ itemId: String) async {
        _ = try? await APIClient.shared.deleteItem(id: itemId)
        await loadItems()
    }

    private func toggleArchive() async {
        guard let info = listInfo else { return }
        _ = try? await APIClient.shared.update(id: listId, body: UpdateListDto(isArchived: !info.isArchived))
        await loadItems()
    }

    private func doRename() async {
        guard !renameText.isEmpty else { return }
        _ = try? await APIClient.shared.update(id: listId, body: UpdateListDto(name: renameText))
        await loadItems()
    }

    private func doDelete() async {
        _ = try? await APIClient.shared.delete(id: listId)
        dismiss()
    }
}
