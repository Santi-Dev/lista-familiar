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

    private var myRole: MemberRole { groups.role(of: session.user?.id) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                    Text("Ajustes")
                        .font(.headlineLarge)
                        .foregroundStyle(.textPrimary)
                        .accessibilityAddTraits(.isHeader)

                    profileCard
                    groupCards
                    accountCard
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.top, Theme.Spacing.sm)
                .padding(.bottom, Theme.Spacing.lg)
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
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

    // MARK: - Perfil

    private var profileCard: some View {
        HStack(spacing: Theme.Spacing.md) {
            AvatarView(name: session.user?.name ?? "", size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.user?.name ?? "")
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                Text(session.user?.email ?? "")
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
            if groups.group != nil {
                StatusChip(text: myRole.title, tint: myRole.tint)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }

    // MARK: - Grupo

    @ViewBuilder
    private var groupCards: some View {
        switch (groups.group, groups.state) {
        case (let group?, _):
            sectionTitle("Grupo familiar")
            VStack(alignment: .leading, spacing: Theme.Spacing.md) {
                HStack(spacing: Theme.Spacing.md) {
                    IconTile(symbol: "house.fill", size: 44)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(group.name)
                            .font(.headlineSmall)
                            .foregroundStyle(.textPrimary)
                        Text(group.members.count == 1 ? "1 miembro" : "\(group.members.count) miembros")
                            .font(.bodySmall)
                            .foregroundStyle(.textSecondary)
                    }
                    Spacer(minLength: 0)
                }
                Divider()
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text("Código de invitación")
                        .font(.labelMedium)
                        .foregroundStyle(.textPrimary)
                    InviteCodeView(group: group, codeFont: .system(size: 28, weight: .semibold, design: .monospaced))
                        .frame(maxWidth: .infinity)
                    Text("Quien lo use se une como editor.")
                        .font(.bodySmall)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()

            sectionTitle("Miembros")
            VStack(spacing: 0) {
                ForEach(Array(group.members.enumerated()), id: \.element.id) { index, member in
                    if index > 0 { Divider().padding(.leading, 68) }
                    memberRow(member, in: group)
                }
            }
            .frame(maxWidth: .infinity)
            .cardSurface()
        case (nil, .failed(let message)):
            sectionTitle("Grupo familiar")
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                Text(message)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                Button("Reintentar") { Task { await groups.load() } }
                    .font(.labelLarge)
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        case (nil, _):
            sectionTitle("Grupo familiar")
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(Theme.Spacing.lg)
                .cardSurface()
        }
    }

    private func memberRow(_ member: Member, in group: FamilyGroup) -> some View {
        let role = group.role(of: member.id)
        let options = myRole.assignableRoles(to: role)
        return HStack(spacing: Theme.Spacing.md) {
            AvatarView(name: member.name, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.Spacing.xs) {
                    Text(member.name)
                        .font(.bodyLarge)
                        .foregroundStyle(.textPrimary)
                    if member.id == session.user?.id {
                        Text("(tú)")
                            .font(.bodySmall)
                            .foregroundStyle(.textSecondary)
                    }
                }
                Text(role.summary)
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: Theme.Spacing.sm)
            if options.isEmpty || member.id == session.user?.id {
                StatusChip(text: role.title, tint: role.tint)
            } else {
                Menu {
                    ForEach(options) { option in
                        Button { setRole(option, for: member) } label: {
                            if option == role {
                                Label(option.title, systemImage: "checkmark")
                            } else {
                                Text(option.title)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        StatusChip(text: role.title, tint: role.tint)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .accessibilityLabel("Cambiar el rol de \(member.name)")
            }
        }
        .padding(Theme.Spacing.md)
        .accessibilityElement(children: .contain)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.labelMedium)
            .foregroundStyle(.textSecondary)
            .textCase(.uppercase)
            .padding(.top, Theme.Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Cuenta

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            VStack(spacing: 0) {
                accountRow("Salir del grupo", symbol: "rectangle.portrait.and.arrow.right") { confirmation = .leaveGroup }
                Divider().padding(.leading, 52)
                accountRow("Cerrar sesión", symbol: "person.crop.circle.badge.xmark") { confirmation = .signOut }
                Divider().padding(.leading, 52)
                accountRow("Eliminar mi cuenta", symbol: "trash") { confirmation = .deleteAccount }
            }
            .cardSurface()

            Text("Eliminar tu cuenta borra tus datos de forma permanente. Si eres el último miembro de tu grupo, también se borrarán sus listas.")
                .font(.bodySmall)
                .foregroundStyle(.textSecondary)
        }
        .padding(.top, Theme.Spacing.md)
    }

    private func accountRow(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: symbol)
                    .frame(width: 24)
                Text(title)
                    .font(.bodyLarge)
                Spacer(minLength: 0)
            }
            .foregroundStyle(.red)
            .padding(Theme.Spacing.md)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Acciones

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

    private func setRole(_ role: MemberRole, for member: Member) {
        Task {
            do { try await groups.setRole(role, for: member.id) } catch { errorMessage = error.userMessage }
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
