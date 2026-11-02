import SwiftUI

struct ItemFormSheet: View {
    let listId: String
    var editItem: ListItemDto? = nil
    var preselectedCategory: ItemCategoryHelper
    var onSaved: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var quantity = ""
    @State private var category: ItemCategoryHelper = .OTROS
    @State private var isLoading = false
    @State private var errorMsg: String?

    private var isEdit: Bool { editItem != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    AppTextField(label: "Nombre", placeholder: "Leche", text: $name)
                    AppTextField(label: "Cantidad (opcional)", placeholder: "2 litros", text: $quantity)

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Categoría")
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                        categoryGrid
                    }

                    if let errorMsg {
                        Text(errorMsg)
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.destructive)
                    }

                    if !isEdit {
                        Button("Guardar y cerrar") {
                            Task { await save(close: true) }
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                    }

                    if isEdit {
                        Button(role: .destructive) {
                            Task { await deleteItem() }
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
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle(isEdit ? "Editar artículo" : "Nuevo artículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .fontDesign(.rounded)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        Task { await save(close: isEdit) }
                    }
                    .fontDesign(.rounded)
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
            .onAppear {
                category = preselectedCategory
                if let item = editItem {
                    name = item.name
                    quantity = item.quantity ?? ""
                    category = ItemCategoryHelper.from(item.category)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var categoryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            ForEach(ItemCategoryHelper.allCases, id: \.self) { cat in
                Button {
                    category = cat
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
                    .background(RoundedRectangle(cornerRadius: 10).fill(category == cat ? Theme.Colors.brand.opacity(0.12) : Theme.Colors.surface))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(category == cat ? Theme.Colors.brand : Theme.Colors.separator, lineWidth: category == cat ? 2 : 0.5))
                    .foregroundColor(category == cat ? Theme.Colors.brand : Theme.Colors.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func save(close: Bool) async {
        isLoading = true
        errorMsg = nil
        do {
            if let editItem {
                _ = try await APIClient.shared.updateItem(id: editItem.id, body: UpdateItemDto(
                    name: name.trimmingCharacters(in: .whitespaces),
                    quantity: quantity.isEmpty ? nil : quantity,
                    category: category.rawValue
                ))
                onSaved(name)
                if close { dismiss() }
            } else {
                _ = try await APIClient.shared.createItem(id: listId, body: CreateItemDto(
                    name: name.trimmingCharacters(in: .whitespaces),
                    quantity: quantity.isEmpty ? nil : quantity,
                    category: category.rawValue
                ))
                onSaved(name)
                if close {
                    dismiss()
                } else {
                    name = ""
                    quantity = ""
                }
            }
        } catch {
            errorMsg = "No se pudo guardar"
        }
        isLoading = false
    }

    private func deleteItem() async {
        guard let item = editItem else { return }
        _ = try? await APIClient.shared.deleteItem(id: item.id)
        onSaved("")
        dismiss()
    }
}
