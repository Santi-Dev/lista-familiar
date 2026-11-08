import SwiftUI

struct SettingsView: View {
    private enum Confirmation: Identifiable {
        case leaveGroup, signOut, deleteAccount
        var id: Self { self }
    }

    @Environment(SessionStore.self) private var session
    @Environment(GroupStore.self) private var groups
    @State private var confirmation: Confirmation?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                profileSection
                groupSections
                accountSections
            }
            .navigationTitle("Ajustes")
            .disabled(isWorking)
            .refreshable { await groups.load() }
            .confirmationDialog(title(for: confirmation), isPresented: $confirmation.isPresent(),
                                titleVisibility: .visible, presenting: confirmation) { action in
                Button(buttonTitle(for: action), role: .destructive) { perform(action) }
            }
            .alert("No se pudo completar", isPresented: $errorMessage.isPresent(), presenting: errorMessage) { _ in
                Button("Entendido", role: .cancel) {}
            } message: { message in
                Text(message)
            }
        }
    }

    private var profileSection: some View {
        Section("Perfil") {
            LabeledContent("Nombre", value: session.user?.name ?? "")
            LabeledContent("Correo", value: session.user?.email ?? "")
        }
    }

    @ViewBuilder
    private var groupSections: some View {
        switch (groups.group, groups.state) {
        case (let group?, _):
            Section("Grupo familiar") {
                LabeledContent("Grupo", value: group.name)
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Código de invitación")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                    InviteCodeView(group: group, codeFont: .system(size: 28, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                }
                .padding(.vertical, Theme.Spacing.xs)
            }
            Section("Miembros") {
                ForEach(group.members) { member in
                    HStack {
                        Text(member.name)
                        if member.id == session.user?.id {
                            Text("(tú)").font(.caption).foregroundStyle(.textSecondary)
                        }
                        Spacer()
                        if group.isCreator(member) {
                            Text("Creador").font(.caption).foregroundStyle(.brand)
                        }
                    }
                }
            }
        case (nil, .failed(let message)):
            Section("Grupo familiar") {
                Text(message).foregroundStyle(.textSecondary)
                Button("Reintentar") { Task { await groups.load() } }
            }
        case (nil, _):
            Section("Grupo familiar") {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
    }

    @ViewBuilder
    private var accountSections: some View {
        Section {
            Button("Salir del grupo") { confirmation = .leaveGroup }
            Button("Cerrar sesión") { confirmation = .signOut }
        }
        .foregroundStyle(.red)

        Section {
            Button("Eliminar mi cuenta") { confirmation = .deleteAccount }
                .foregroundStyle(.red)
        } footer: {
            Text("Se borrarán tus datos de forma permanente. Si eres el último miembro de tu grupo, también se borrarán sus listas.")
        }
    }

    private func title(for action: Confirmation?) -> String {
        switch action {
        case .leaveGroup: "¿Salir del grupo? Dejarás de ver sus listas."
        case .signOut: "¿Cerrar sesión?"
        case .deleteAccount: "¿Eliminar tu cuenta? Esta acción no se puede deshacer."
        case nil: ""
        }
    }

    private func buttonTitle(for action: Confirmation) -> String {
        switch action {
        case .leaveGroup: "Salir del grupo"
        case .signOut: "Cerrar sesión"
        case .deleteAccount: "Eliminar mi cuenta"
        }
    }

    private func perform(_ action: Confirmation) {
        Task {
            isWorking = true
            defer { isWorking = false }
            do {
                switch action {
                case .leaveGroup:
                    try await groups.leave()
                    session.leftGroup()
                case .signOut:
                    await session.signOut()
                case .deleteAccount:
                    try await session.deleteAccount()
                }
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}
