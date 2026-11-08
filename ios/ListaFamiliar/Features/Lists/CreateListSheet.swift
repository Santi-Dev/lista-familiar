import SwiftUI

struct CreateListSheet: View {
    /// Recibe la lista creada (la pantalla de listas la abre directamente).
    let onCreated: (ShoppingList) -> Void

    @Environment(GroupStore.self) private var groups
    @Environment(SessionStore.self) private var session
    @Environment(ListsStore.self) private var lists
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    private var canCreate: Bool { NameInput.isValid(name) && !isSubmitting }

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                LabeledField("Nombre de la lista", isFocused: isFocused) {
                    TextField("Mercado semanal", text: $name)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .onSubmit(create)
                }
                FormErrorText(message: errorMessage)
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView()
                    } else {
                        Button("Crear", action: create)
                            .fontWeight(.semibold)
                            .disabled(!canCreate)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() {
        guard canCreate else { return }
        guard let groupID = groups.group?.id ?? session.user?.familyGroupID else {
            errorMessage = AppError.notInGroup.localizedDescription
            return
        }
        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                let list = try await lists.createList(named: name, groupID: groupID)
                dismiss()
                onCreated(list)
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    Text("Mis listas")
        .sheet(isPresented: .constant(true)) { CreateListSheet { _ in } }
        .previewEnvironment()
}
