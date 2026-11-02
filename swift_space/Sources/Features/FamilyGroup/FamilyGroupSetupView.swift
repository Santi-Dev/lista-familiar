import SwiftUI

struct FamilyGroupSetupView: View {
    @Environment(SessionModel.self) private var session
    @State private var vm = FamilyGroupSetupViewModel()
    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Hola, \(session.user?.name ?? "")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Para empezar, crea tu grupo familiar o únete al de tu familia.")
                        .font(.body)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("", selection: $vm.mode) {
                        Text("Crear grupo").tag(FamilyGroupSetupViewModel.Mode.create)
                        Text("Unirme con código").tag(FamilyGroupSetupViewModel.Mode.join)
                    }
                    .pickerStyle(.segmented)

                    if vm.mode == .create {
                        createGroupContent
                    } else {
                        joinGroupContent
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar sesión") { session.logout() }
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                }
            }
        }
    }

    @ViewBuilder
    private var createGroupContent: some View {
        if let group = vm.createdGroup {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.brand)
                Text("¡Grupo creado!")
                    .font(.title2)
                    .fontDesign(.rounded)
                    .bold()
                Text(group.inviteCode)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .tracking(6)
                    .foregroundColor(Theme.Colors.textPrimary)
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        UIPasteboard.general.string = group.inviteCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
                    } label: {
                        Label(codeCopied ? "Código copiado" : "Copiar código", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .sensoryFeedback(.success, trigger: codeCopied)

                    ShareLink(item: "Únete a nuestra lista de la compra en Lista Familiar con el código: \(group.inviteCode)") {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("Continuar") {
                    session.setFamilyGroup(id: group.id)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radii.card).fill(Theme.Colors.surface))
        } else {
            VStack(spacing: Theme.Spacing.md) {
                AppTextField(label: "Nombre del grupo", placeholder: "Familia García", text: $vm.groupName)
                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                }
                Button("Crear grupo") {
                    Task { await vm.create() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
                .disabled(!vm.canCreate)
                .opacity(vm.canCreate ? 1 : 0.6)
            }
        }
    }

    @ViewBuilder
    private var joinGroupContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            AppTextField(label: "Código de invitación", placeholder: "ABC123", text: $vm.inviteCode, autocap: .characters)
                .onChange(of: vm.inviteCode) { _, _ in
                    vm.normalizeInviteCode()
                }
            if let errorMessage = vm.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(Theme.Colors.destructive)
            }
            Button("Unirme") {
                Task { if let group = await vm.join() { session.setFamilyGroup(id: group.id) } }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
            .disabled(!vm.canJoin)
            .opacity(vm.canJoin ? 1 : 0.6)
        }
    }
}
