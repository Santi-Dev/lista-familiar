import SwiftUI

/// Alta o edición de una lista: nombre, icono, tienda y «fijar al inicio».
struct ListFormSheet: View {
    enum Mode {
        /// Recibe la lista creada (la pantalla de listas la abre directamente).
        case create(onCreated: (ShoppingList) -> Void)
        case edit(ShoppingList)
    }

    let mode: Mode

    @Environment(GroupStore.self) private var groups
    @Environment(SessionStore.self) private var session
    @Environment(ListsStore.self) private var lists
    @Environment(\.dismiss) private var dismiss
    @State private var draft: ListDraft
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case name, store }

    init(mode: Mode) {
        self.mode = mode
        switch mode {
        case .create: _draft = State(initialValue: ListDraft())
        case .edit(let list): _draft = State(initialValue: ListDraft(list: list))
        }
    }

    init(onCreated: @escaping (ShoppingList) -> Void) {
        self.init(mode: .create(onCreated: onCreated))
    }

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool { draft.isValid && !isSubmitting }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    LabeledField("Nombre de la lista", icon: draft.icon.symbol, isFocused: focus == .name) {
                        TextField("Mercado semanal", text: $draft.name)
                            .focused($focus, equals: .name)
                            .submitLabel(.done)
                            .onSubmit(save)
                    }

                    iconPicker
                    storePicker

                    Toggle(isOn: $draft.isPinned) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fijar al inicio")
                                .font(.labelLarge)
                                .foregroundStyle(.textPrimary)
                            Text("Mantenerla siempre arriba en «Mis listas»")
                                .font(.bodySmall)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    .tint(.brand)
                    .padding(Theme.Spacing.md)
                    .cardSurface()

                    FormErrorText(message: errorMessage)

                    Button(isEditing ? "Guardar cambios" : "Crear lista", action: save)
                        .buttonStyle(.primary(isLoading: isSubmitting))
                        .disabled(!canSave)
                }
                .padding(Theme.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle(isEditing ? "Editar lista" : "Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var iconPicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Icono")
                .font(.labelMedium)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Theme.Spacing.sm) {
                ForEach(ListIcon.allCases) { icon in
                    let isSelected = draft.icon == icon
                    Button { draft.icon = icon } label: {
                        Image(systemName: icon.symbol)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.white : icon.tint)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(isSelected ? icon.tint : icon.tint.opacity(0.14), in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(icon.title)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .sensoryFeedback(.selection, trigger: draft.icon)
        }
    }

    private var storePicker: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack {
                Text("Tienda")
                    .font(.labelMedium)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("Opcional")
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
            ScrollView(.horizontal) {
                HStack(spacing: Theme.Spacing.sm) {
                    ForEach(ListDraft.suggestedStores, id: \.self) { store in
                        let isSelected = draft.cleanStore == store
                        Button {
                            draft.store = isSelected ? "" : store
                        } label: {
                            Text(store)
                                .font(.labelMedium)
                                .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 9)
                                .chipSurface(isSelected: isSelected)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
            }
            .padding(.horizontal, -Theme.Spacing.lg)
            .scrollIndicators(.hidden)

            LabeledField("Otra tienda", icon: "storefront", isFocused: focus == .store) {
                TextField("Nombre de la tienda", text: $draft.store)
                    .focused($focus, equals: .store)
                    .submitLabel(.done)
                    .onChange(of: draft.store) { _, value in
                        if value.count > ListDraft.maxStoreLength {
                            draft.store = String(value.prefix(ListDraft.maxStoreLength))
                        }
                    }
            }
        }
    }

    private func save() {
        guard canSave else { return }
        let draft = draft
        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                switch mode {
                case .create(let onCreated):
                    guard let groupID = groups.group?.id ?? session.user?.familyGroupID else {
                        errorMessage = AppError.notInGroup.localizedDescription
                        return
                    }
                    let list = try await lists.createList(draft, groupID: groupID)
                    dismiss()
                    onCreated(list)
                case .edit(let list):
                    try await lists.update(list.id, with: draft)
                    dismiss()
                }
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    Text("Mis listas")
        .sheet(isPresented: .constant(true)) { ListFormSheet { _ in } }
        .previewEnvironment()
}
