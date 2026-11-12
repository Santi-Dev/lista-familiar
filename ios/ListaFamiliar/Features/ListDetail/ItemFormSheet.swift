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
    @Environment(GroupStore.self) private var groups
    @Environment(SessionStore.self) private var session
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ItemDraft
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var toast: String?
    @FocusState private var focus: Field?

    private enum Field { case name, quantity, note }

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

    private var members: [Member] { groups.group?.members ?? [] }
    private var kind: ListKind { lists.list(listID)?.kind ?? .market }
    private var canSave: Bool { draft.isValid && !isSaving }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.md) {
                    LabeledField("Nombre", icon: draft.category.symbol, isFocused: focus == .name) {
                        TextField("Leche", text: $draft.name)
                            .focused($focus, equals: .name)
                            .submitLabel(.next)
                            .onSubmit { focus = .note }
                    }

                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Categoría")
                            .font(.labelMedium)
                            .foregroundStyle(.textPrimary)
                        CategoryPicker(selection: $draft.category, categories: kind.categories)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    quantitySection
                    if members.count > 1 { assigneeSection }

                    Toggle(isOn: $draft.isUrgent) {
                        Label {
                            Text("Marcar como urgente")
                                .foregroundStyle(.textPrimary)
                        } icon: {
                            Image(systemName: "flame.fill").foregroundStyle(.highlight)
                        }
                        .font(.labelLarge)
                    }
                    .tint(.highlight)
                    .padding(Theme.Spacing.md)
                    .cardSurface()

                    LabeledField("Nota (opcional)", icon: "text.alignleft", isFocused: focus == .note) {
                        TextField("Marca Oatly o Hacendado", text: $draft.note, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($focus, equals: .note)
                            .onChange(of: draft.note) { _, value in
                                if value.count > ItemDraft.maxNoteLength {
                                    draft.note = String(value.prefix(ItemDraft.maxNoteLength))
                                }
                            }
                    }

                    FormErrorText(message: errorMessage)

                    if let item = editingItem {
                        Button("Eliminar artículo", systemImage: "trash", role: .destructive) { delete(item) }
                            .font(.headlineSmall)
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
            .screenBackground()
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

    // MARK: - Cantidad

    private var quantityParts: QuantityParts? { QuantityParts(text: draft.quantity) }
    /// Cantidad escrita a mano que el selector no entiende (por ejemplo, «3 bolsas»): se edita como texto.
    private var hasCustomQuantity: Bool { draft.cleanQuantity != nil && quantityParts == nil }

    private var quantitySection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            HStack {
                Text("Cantidad")
                    .font(.labelMedium)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Opcional")
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
            if hasCustomQuantity {
                HStack {
                    TextField("2 litros", text: $draft.quantity)
                        .focused($focus, equals: .quantity)
                    Button("Usar selector") { draft.quantity = "" }
                        .font(.labelMedium)
                        .foregroundStyle(.brand)
                }
            } else {
                HStack(spacing: Theme.Spacing.md) {
                    Button { adjustQuantity(by: -1) } label: {
                        Image(systemName: "minus")
                            .frame(width: 40, height: 40)
                            .background(Color.appBackground, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Menos cantidad")
                    Text(quantityParts?.amountText ?? "–")
                        .font(.headlineMedium)
                        .foregroundStyle(.textPrimary)
                        .frame(minWidth: 44)
                        .contentTransition(.numericText())
                    Button { adjustQuantity(by: 1) } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Color.brand, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Más cantidad")
                    Spacer(minLength: 0)
                }
                .animation(.default, value: draft.quantity)
                .sensoryFeedback(.selection, trigger: draft.quantity)

                ScrollView(.horizontal) {
                    HStack(spacing: Theme.Spacing.sm) {
                        ForEach(QuantityParts.units) { unit in
                            let isSelected = quantityParts?.unit == unit.symbol
                            Button { selectUnit(unit.symbol) } label: {
                                Text(unit.symbol)
                                    .font(.labelMedium)
                                    .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 9)
                                    .chipSurface(isSelected: isSelected)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isSelected ? .isSelected : [])
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
    }

    private func adjustQuantity(by direction: Double) {
        let current = quantityParts ?? QuantityParts(amount: 0, unit: nil)
        let amount = max(0, current.amount + direction * current.step)
        draft.quantity = amount == 0 ? "" : QuantityParts(amount: amount, unit: current.unit).text
    }

    private func selectUnit(_ symbol: String) {
        var current = quantityParts ?? QuantityParts(amount: 1, unit: nil)
        current.unit = current.unit == symbol ? nil : symbol
        draft.quantity = current.text
    }

    // MARK: - Asignar a

    private var assigneeSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Asignar a")
                    .font(.labelMedium)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Quién lo compra")
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    assigneeChip(title: "Todos", name: nil, id: nil)
                    ForEach(members) { member in
                        assigneeChip(
                            title: member.id == session.user?.id ? "\(member.name) (tú)" : member.name,
                            name: member.name, id: member.id)
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.horizontal, -Theme.Spacing.lg)
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func assigneeChip(title: String, name: String?, id: UUID?) -> some View {
        let isSelected = draft.assigneeID == id
        return Button { draft.assigneeID = id } label: {
            HStack(spacing: Theme.Spacing.sm) {
                if let name {
                    AvatarView(name: name, size: 22)
                } else {
                    Image(systemName: "person.2.fill")
                }
                Text(title)
            }
            .font(.labelMedium)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .chipSurface(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Acciones

    private func save(close: Bool) {
        guard canSave else { return }
        let draft = draft
        let members = members
        Task {
            isSaving = true
            errorMessage = nil
            defer { isSaving = false }
            do {
                if let item = editingItem {
                    try await lists.updateItem(item, with: draft, members: members)
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
    let categories: [ItemCategory]

    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: Theme.Spacing.sm) {
            ForEach(categories) { category in
                let isSelected = selection == category
                Button { selection = category } label: {
                    Label(category.title, systemImage: category.symbol)
                        .font(.labelMedium)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .foregroundStyle(isSelected ? Color.white : category.tint)
                        .background(isSelected ? category.tint : category.tint.opacity(0.12),
                                    in: .rect(cornerRadius: Theme.Radius.tile))
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
