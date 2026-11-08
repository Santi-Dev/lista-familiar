import SwiftUI

/// Alta o edición de un artículo. Al añadir, «Guardar» deja el formulario listo para el siguiente.
struct ItemFormSheet: View {
    enum Mode: Hashable {
        case add(category: ItemCategory)
        case edit(ListItem)
    }

    let listID: UUID
    let mode: Mode
    /// Recibe el nombre guardado.
    let onSaved: (String) -> Void

    @Environment(ListsStore.self) private var lists
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ItemDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var toast: String?
    @FocusState private var focus: Field?

    private enum Field { case name, quantity }

    init(listID: UUID, mode: Mode, onSaved: @escaping (String) -> Void) {
        self.listID = listID
        self.mode = mode
        self.onSaved = onSaved
        switch mode {
        case .add(let category): _draft = State(initialValue: ItemDraft(category: category))
        case .edit(let item): _draft = State(initialValue: ItemDraft(item: item))
        }
    }

    private var editingItem: ListItem? {
        if case .edit(let item) = mode { return item }
        return nil
    }

    private var canSave: Bool { draft.isValid && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    LabeledField("Nombre", isFocused: focus == .name) {
                        TextField("Leche", text: $draft.name)
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .quantity }
                    }
                    LabeledField("Cantidad (opcional)", isFocused: focus == .quantity) {
                        TextField("2 litros", text: $draft.quantity)
                            .focused($focus, equals: .quantity)
                            .submitLabel(.done)
                            .onSubmit { save(close: editingItem != nil) }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Categoría")
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                        CategoryPicker(selection: $draft.category)
                    }

                    FormErrorText(message: errorMessage)

                    if let item = editingItem {
                        Button("Eliminar artículo", systemImage: "trash", role: .destructive) { delete(item) }
                            .font(.headline)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
                    } else {
                        Button("Guardar y cerrar") { save(close: true) }
                            .buttonStyle(.secondary)
                            .disabled(!canSave)
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(editingItem == nil ? "Nuevo artículo" : "Editar artículo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save(close: editingItem != nil) }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .toast($toast)
        }
        .presentationDetents([.medium, .large])
    }

    private func save(close: Bool) {
        guard canSave else { return }
        let draft = draft
        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }
            do {
                if let item = editingItem {
                    try await lists.updateItem(item, with: draft)
                } else {
                    try await lists.addItem(draft, to: listID)
                }
                onSaved(draft.cleanName)
                if close {
                    dismiss()
                } else {
                    // Listo para añadir otro artículo de la misma categoría.
                    self.draft = ItemDraft(category: draft.category)
                    toast = "Añadido: \(draft.cleanName)"
                    focus = .name
                }
            } catch {
                errorMessage = error.userMessage
            }
        }
    }

    private func delete(_ item: ListItem) {
        Task {
            do {
                try await lists.deleteItem(item)
                dismiss()
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

/// Rejilla de categorías de dos columnas.
private struct CategoryPicker: View {
    @Binding var selection: ItemCategory

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            ForEach(ItemCategory.allCases) { category in
                let isSelected = selection == category
                Button { selection = category } label: {
                    Label(category.title, systemImage: category.symbol)
                        .font(.subheadline)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundStyle(isSelected ? Color.brand : Color.textPrimary)
                        .background(isSelected ? Color.brand.opacity(0.12) : Color.surface,
                                    in: .rect(cornerRadius: Theme.Radius.tile))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.tile)
                                .strokeBorder(isSelected ? Color.brand : Color.hairline, lineWidth: isSelected ? 2 : 0.5)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

#Preview("Nuevo") {
    Text("Detalle")
        .sheet(isPresented: .constant(true)) {
            ItemFormSheet(listID: SampleData.firstListID, mode: .add(category: .produce)) { _ in }
        }
        .previewEnvironment()
}
