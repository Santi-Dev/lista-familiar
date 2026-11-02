import SwiftUI

struct SettingsView: View {
    @Environment(SessionModel.self) private var session
    @State private var group: FamilyGroupDto?
    @State private var isLoading = true
    @State private var errorMsg: String?
    @State private var codeCopied = false
    @State private var showLeaveConfirm = false
    @State private var showLogoutConfirm = false

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if let errorMsg {
                    ErrorStateView(message: errorMsg) { Task { await loadGroup() } }
                } else {
                    settingsForm
                }
            }
            .navigationTitle("Ajustes")
            .task { await loadGroup() }
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

            if let group {
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
        }
        .confirmationDialog("¿Salir del grupo? Dejarás de ver sus listas.", isPresented: $showLeaveConfirm, titleVisibility: .visible) {
            Button("Salir", role: .destructive) { Task { await leaveGroup() } }
        }
        .confirmationDialog("¿Cerrar sesión?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Cerrar sesión", role: .destructive) { session.logout() }
        }
    }

    private func loadGroup() async {
        isLoading = true
        do {
            let g: FamilyGroupDto = try await APIClient.shared.request(path: "/api/family-groups/me", method: "GET")
            group = g
            errorMsg = nil
        } catch {
            errorMsg = "No se pudo cargar la información"
        }
        isLoading = false
    }

    private func leaveGroup() async {
        _ = try? await APIClient.shared.leave()
        session.setFamilyGroup(id: nil)
    }
}
