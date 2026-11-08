import SwiftUI

/// Primer paso tras registrarse: crear un grupo familiar o unirse a uno con un código.
struct FamilyGroupSetupView: View {
    private enum Mode: Hashable { case create, join }

    @Environment(SessionStore.self) private var session
    @Environment(GroupStore.self) private var groups
    @State private var mode = Mode.create
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var createdGroup: FamilyGroup?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var isFieldFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                        Text("Hola, \(session.user?.name ?? "")")
                            .font(.screenTitle)
                            .foregroundStyle(.textPrimary)
                        Text("Para empezar, crea tu grupo familiar o únete al de tu familia.")
                            .foregroundStyle(.textSecondary)
                    }

                    if let createdGroup {
                        created(createdGroup)
                    } else {
                        Picker("Modo", selection: $mode) {
                            Text("Crear grupo").tag(Mode.create)
                            Text("Unirme con código").tag(Mode.join)
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: mode) { errorMessage = nil }

                        switch mode {
                        case .create: createForm
                        case .join: joinForm
                        }
                    }
                }
                .padding(Theme.Spacing.lg)
                .animation(.default, value: mode)
                .animation(.default, value: createdGroup)
                .animation(.default, value: errorMessage)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar sesión", role: .destructive) { Task { await session.signOut() } }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var createForm: some View {
        VStack(spacing: Theme.Spacing.md) {
            LabeledField("Nombre del grupo", isFocused: isFieldFocused) {
                TextField("Familia García", text: $groupName)
                    .textContentType(.familyName)
                    .focused($isFieldFocused)
                    .submitLabel(.done)
                    .onSubmit(create)
            }
            FormErrorText(message: errorMessage)
            Button("Crear grupo", action: create)
                .buttonStyle(.primary(isLoading: isSubmitting))
                .disabled(!NameInput.isValid(groupName) || isSubmitting)
        }
    }

    private var joinForm: some View {
        VStack(spacing: Theme.Spacing.md) {
            LabeledField("Código de invitación", isFocused: isFieldFocused) {
                TextField("ABC123", text: $inviteCode)
                    .font(.body.monospaced())
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .focused($isFieldFocused)
                    .submitLabel(.join)
                    .onSubmit(join)
                    .onChange(of: inviteCode) { _, code in
                        let normalized = InviteCode.normalize(code)
                        if normalized != code { inviteCode = normalized }
                    }
            }
            FormErrorText(message: errorMessage)
            Button("Unirme", action: join)
                .buttonStyle(.primary(isLoading: isSubmitting))
                .disabled(!InviteCode.isComplete(inviteCode) || isSubmitting)
        }
    }

    private func created(_ group: FamilyGroup) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.brand)
            Text("¡Grupo creado!")
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
            Text("Comparte este código con tu familia para que se una.")
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
            InviteCodeView(group: group)
            Button("Continuar") { session.joined(group) }
                .buttonStyle(.primary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .transition(.scale(scale: 0.95).combined(with: .opacity))
        .sensoryFeedback(.success, trigger: createdGroup)
    }

    private func create() {
        guard NameInput.isValid(groupName), !isSubmitting else { return }
        submit { createdGroup = try await groups.create(named: groupName) }
    }

    private func join() {
        guard InviteCode.isComplete(inviteCode), !isSubmitting else { return }
        submit { session.joined(try await groups.join(code: inviteCode)) }
    }

    private func submit(_ work: @escaping () async throws -> Void) {
        isFieldFocused = false
        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await work()
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    FamilyGroupSetupView().previewEnvironment(inGroup: false)
}
