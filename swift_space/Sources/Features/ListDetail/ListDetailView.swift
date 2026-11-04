import SwiftUI


struct ListDetailView: View {
    let listId: String
    @State private var vm: ListDetailViewModel

    init(listId: String) {
        self.listId = listId
        _vm = State(initialValue: ListDetailViewModel(listId: listId))
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss

    @State private var showAddSheet = false
    @State private var editingItem: ListItemDto?
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    var body: some View {
        ZStack(alignment: .bottom) {
            mainContent
            toastOverlay
        }
        .safeAreaInset(edge: .bottom) { addButton }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { renameText = vm.listInfo?.name ?? ""; showRenameAlert = true } label: {
                        Label("Renombrar lista", systemImage: "pencil")
                    }
                    Button { Task { await vm.toggleArchive() } } label: {
                        Label(vm.listInfo?.isArchived == true ? "Desarchivar lista" : "Archivar lista", systemImage: "archivebox")
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
            Button("Guardar") { Task { await vm.rename(to: renameText) } }
        }
        .confirmationDialog("¿Eliminar la lista? Se borrarán todos sus artículos.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) { Task { await vm.deleteList() } }
        }
        .sheet(isPresented: $showAddSheet) {
            ItemFormSheet(listId: listId, preselectedCategory: vm.selectedCategory ?? .OTROS, onSaved: { name in
                vm.showToast("Añadido: \(name)")
                Task { await vm.load() }
            })
        }
        .sheet(item: $editingItem) { item in
            ItemFormSheet(listId: listId, editItem: item, preselectedCategory: ItemCategory.from(item.category), onSaved: { _ in
                Task { await vm.load() }
            })
        }
        .task { await vm.load() }
        .task { await vm.observeChanges() }
        .task { await vm.poll(isActive: { scenePhase == .active }) }
        .onChange(of: vm.isGone) { _, gone in if gone { dismiss() } }
    }

    @ViewBuilder
    private var mainContent: some View {
        if vm.isLoading && vm.items.isEmpty {
            VStack {
                ForEach(0..<5, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 8).fill(Theme.Colors.surface).frame(height: 52)
                }
            }
            .padding(Theme.Spacing.lg)
            .redacted(reason: .placeholder)
        } else if let errorMsg = vm.errorMsg {
            ErrorStateView(message: errorMsg) { Task { await vm.load() } }
        } else {
            VStack(spacing: 0) {
                if let info = vm.listInfo {
                    Text(info.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .padding(.top, Theme.Spacing.sm)
                    HStack {
                        Text("\(Int(info.purchasedCount))/\(Int(info.itemCount)) comprados")
                            .font(.subheadline)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Spacer()
                    }
                    .padding(.horizontal, Theme.Spacing.lg)
                    .padding(.top, Theme.Spacing.xs)

                    if info.isArchived {
                        HStack {
                            Image(systemName: "archivebox.fill")
                            Text("Lista archivada")
                            Spacer()
                            Button("Desarchivar") { Task { await vm.toggleArchive() } }
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

                if vm.filteredItems.isEmpty {
                    Spacer()
                    if vm.selectedCategory != nil {
                        EmptyStateView(icon: "magnifyingglass", title: "No hay artículos en \(vm.selectedCategory!.label)", subtitle: "")
                    } else {
                        EmptyStateView(icon: "basket", title: "La lista está vacía", subtitle: "Añade lo que necesitas comprar.", buttonTitle: "Añadir artículo") {
                            showAddSheet = true
                        }
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(vm.groupedItems, id: \.0) { cat, catItems in
                            Section {
                                ForEach(catItems, id: \.id) { item in
                                    itemRow(item)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task { await vm.deleteItem(item.id) }
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
                }
            }
        }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Theme.Spacing.sm) {
                chipButton(label: "Todas", icon: nil, isSelected: vm.selectedCategory == nil) {
                    vm.selectedCategory = nil
                }
                ForEach(ItemCategory.allCases, id: \.self) { cat in
                    let count = vm.pendingCount(in: cat)
                    chipButton(label: cat.label, icon: cat.symbol, isSelected: vm.selectedCategory == cat, badge: count) {
                        vm.selectedCategory = cat
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
            .chipSurface(isSelected: isSelected)
        }
    }

    private func itemRow(_ item: ListItemDto) -> some View {
        Button {
            editingItem = item
        } label: {
            HStack(spacing: Theme.Spacing.sm) {
                Button {
                    Task { await vm.togglePurchased(item) }
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
        }
        .buttonStyle(PrimaryButtonStyle())
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.sm)
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if let msg = vm.toastMessage {
            Text(msg)
                .font(.subheadline)
                .fontDesign(.rounded)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.sm)
                .floatingSurface(in: Capsule())
                .foregroundColor(Theme.Colors.textPrimary)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, Theme.Spacing.md)
        }
    }
}
