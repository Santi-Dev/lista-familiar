import SwiftUI

struct CreateListSheet: View {
    @State private var vm = CreateListViewModel()
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focused: Bool
    var onCreated: (String) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: Theme.Spacing.md) {
                AppTextField(label: "Nombre de la lista", placeholder: "Mercado semanal", text: $vm.name)
                Spacer()
            }
            .padding(Theme.Spacing.lg)
            .navigationTitle("Nueva lista")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                        .fontDesign(.rounded)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") { Task { if let id = await vm.create() { dismiss(); onCreated(id) } } }
                        .fontDesign(.rounded)
                        .fontWeight(.semibold)
                        .disabled(!vm.canCreate)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
