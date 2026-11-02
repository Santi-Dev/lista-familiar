import SwiftUI

struct CreateListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var isLoading = false
    @FocusState private var focused: Bool
    var onCreated: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                AppTextField(label: "Nombre de la lista", placeholder: "Mercado semanal", text: $name)
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .background(Theme.Colors.background.ignoresSafeArea())
            .navigationTitle("Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .fontDesign(.rounded)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { Task { await create() } }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func create() async {
        isLoading = true
        do {
            let list = try await APIClient.shared.create(body: CreateListDto(name: name))
            dismiss()
            onCreated(list.id)
        } catch {
            isLoading = false
        }
    }
}
