import SwiftUI

struct ItemFormSheet: View {
    let listId: String
    var editItem: ListItemDto? = nil
    var preselectedCategory: ItemCategory
    var onSaved: (String) -> Void
    @State private var vm: ItemFormViewModel

    init(listId: String, editItem: ListItemDto? = nil, preselectedCategory: ItemCategory, onSaved: @escaping (String) -> Void) {
        self.listId = listId
        self.editItem = editItem
        self.preselectedCategory = preselectedCategory
        self.onSaved = onSaved
        _vm = State(initialValue: ItemFormViewModel(listId: listId, editItem: editItem, preselectedCategory: preselectedCategory))
    }

    @Environment(\.dismiss) private var dismiss


    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    AppTextField(label: "Nombre", placeholder: "Leche", text: $vm.name)
                    AppTextField(label: "Cantidad (opcional)", placeholder: "2 litros", text: $vm.quantity)

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Categoría")
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                        categoryGrid
                    }

                    if let errorMsg = vm.errorMsg {
                        Text(errorMsg)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.destructive)
                    }

                    if !vm.isEdit {
                        Button("Guardar y cerrar") {
                            Task { await saveAndMaybeClose(resetAfter: false, close: true) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(!vm.canSave)
                    }

                    if vm.isEdit {
                        Button(role: .destructive) {
                            Task { await vm.delete(); onSaved(""); dismiss() }
                        } label: {
                            Label("Eliminar artículo", systemImage: "trash")
                                .font(.headline)
                                .fontDesign(.rounded)
                                .foregroundColor(Theme.Colors.destructive)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .navigationTitle(vm.isEdit ? "Editar artículo" : "Nuevo artículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .fontDesign(.rounded)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await saveAndMaybeClose(resetAfter: !vm.isEdit, close: vm.isEdit) }
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .disabled(!vm.canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            ForEach(ItemCategory.allCases, id: \.self) { cat in
                Button {
                    vm.category = cat
                } label: {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: cat.symbol)
                            .font(.body)
                        Text(cat.label)
                            .font(.subheadline)
                            .fontDesign(.rounded)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 10).fill(vm.category == cat ? Theme.Colors.brand.opacity(0.12) : Theme.Colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(vm.category == cat ? Theme.Colors.brand : Theme.Colors.separator, lineWidth: vm.category == cat ? 2 : 0.5))
                    .foregroundColor(vm.category == cat ? Theme.Colors.brand : Theme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saveAndMaybeClose(resetAfter: Bool, close: Bool) async {
        guard let saved = await vm.save(resetAfter: resetAfter) else { return }
        onSaved(saved)
        if close { dismiss() }
    }
}
