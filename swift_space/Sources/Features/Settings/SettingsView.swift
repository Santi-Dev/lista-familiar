import SwiftUI

struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    @State private var vm = SettingsViewModel()
    @State private var codeCopied = false
    @State private var showLeaveConfirm = false
    @State private var showLogoutConfirm = false
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading {
                    ProgressView()
                } else if let errorMsg = vm.errorMsg {
                    ErrorStateView(message: errorMsg) { Task { await vm.load() } }
                } else {
                    settingsForm
                }
            }
            .navigationTitle("Ajustes")
            .task { await vm.load() }
        }
    }

    @ViewBuilder
    private var settingsForm: some View {
        Form {
            Section("Perfil") {
                LabeledContent("Nombre", value: session.user?.name ?? "")
                LabeledContent("Correo", value: session.user?.email ?? "")
            }
            .fontDesign(.rounded)

            if let group = vm.group {
                Section("Grupo familiar") {
                    LabeledContent("Grupo", value: group.name)
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Código de invitación")
                            .font(.caption)
                            .fontDesign(.rounded)
                            .foregroundColor(Theme.Colors.textSecondary)
                        Text(group.inviteCode)
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))
                            .tracking(6)
                            .foregroundColor(Theme.Colors.textPrimary)
                        HStack(spacing: Theme.Spacing.sm) {
                            Button {
                                UIPasteboard.general.string = group.inviteCode
                                codeCopied = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
                            } label: {
                                Label(codeCopied ? "Copiado" : "Copiar", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                                    .font(.subheadline).fontDesign(.rounded)
                            }
                            .sensoryFeedback(.success, trigger: codeCopied)

                            ShareLink(item: "Únete a nuestra lista de la compra en Lista Familiar con el código: \(group.inviteCode)") {
                                Label("Compartir", systemImage: "square.and.arrow.up")
                                    .font(.subheadline).fontDesign(.rounded)
                            }
                        }
                    }
                }
                .fontDesign(.rounded)

                Section("Miembros") {
                    ForEach(group.members, id: \.id) { member in
                        HStack {
                            Text(member.name)
                                .fontDesign(.rounded)
                            if member.id == session.user?.id {
                                Text("(tú)")
                                    .font(.caption)
                                    .fontDesign(.rounded)
                                    .foregroundColor(Theme.Colors.textSecondary)
                            }
                            Spacer()
                            if member.id == group.createdById {
                                Text("Creador")
                                    .font(.caption)
                                    .fontDesign(.rounded)
                                    .foregroundColor(Theme.Colors.brand)
                            }
                        }
                    }
                }
            }

            Section {
                Button("Salir del grupo") { showLeaveConfirm = true }
                    .foregroundColor(Theme.Colors.destructive)
                    .fontDesign(.rounded)
                Button("Cerrar sesión") { showLogoutConfirm = true }
                    .foregroundColor(Theme.Colors.destructive)
                    .fontDesign(.rounded)
            }

            Section {
                Button("Eliminar mi cuenta") { showDeleteConfirm = true }
                    .foregroundColor(Theme.Colors.destructive)
                    .fontDesign(.rounded)
                    .disabled(vm.isDeleting)
            } footer: {
                Text("Se borrarán tus datos de forma permanente. Si eres el último miembro de tu grupo, también se borrarán sus listas.")
                    .fontDesign(.rounded)
            }
        }
        .confirmationDialog("¿Salir del grupo? Dejarás de ver sus listas.", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Salir", role: .destructive) { Task { await vm.leaveGroup(); session.setFamilyGroup(id: nil) } }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { session.logout() }
        }
        .confirmationDialog("¿Eliminar tu cuenta? Esta acción no se puede deshacer.", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Eliminar mi cuenta", role: .destructive) {
                Task { if await vm.deleteAccount() { session.logout() } }
            }
        }
        .alert("No se pudo eliminar la cuenta", isPresented: Binding(get: { vm.deleteError != nil }, set: { if !$0 { vm.deleteError = nil } })) {
            Button("Entendido", role: .cancel) {}
        } message: {
            Text(vm.deleteError ?? "")
        }
    }
}
