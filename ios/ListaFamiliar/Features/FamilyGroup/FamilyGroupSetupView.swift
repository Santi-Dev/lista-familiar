import SwiftUI

/// Primer paso tras registrarse: crear un grupo familiar o unirse a uno con un código.
struct FamilyGroupSetupView: View {
    private enum Mode: Hashable { case create, join }

    @Environment(SessionStore.self) private var session
    @Environment(GroupStore.self) private var groups
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var createdGroup: FamilyGroup?
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    /// Formulario al que pertenece el error que se muestra.
    @State private var errorMode: Mode?
    @FocusState private var isNameFocused: Bool
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                    header

                    if let createdGroup {
                        created(createdGroup)
                    } else {
                        createCard
                        separator
                        joinCard
                    }
                }
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.bottom, Theme.Spacing.lg)
                .animation(.default, value: createdGroup)
                .animation(.default, value: errorMessage)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar sesión", role: .destructive) { Task { await session.signOut() } }
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Image(systemName: "house.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 60, height: 60)
                .background(Color.brand, in: .circle)
                .accessibilityHidden(true)
            Text("Hola, \(session.user?.name ?? "")")
                .font(.headlineLarge)
                .foregroundStyle(.textPrimary)
            Text("Para empezar, crea tu grupo familiar o únete al de tu familia.")
                .font(.bodyLarge)
                .foregroundStyle(.textSecondary)
        }
    }

    private var createCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            cardHeader(
                symbol: "plus.circle.fill", tint: .brand,
                title: "Crear un nuevo grupo", subtitle: "Tú lo creas y compartes el código.")
            LabeledField("Nombre del grupo", isFocused: isNameFocused) {
                TextField("Familia García", text: $groupName)
                    .textContentType(.familyName)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit(create)
            }
            if errorMode == .create { FormErrorText(message: errorMessage) }
            Button("Crear grupo", action: create)
                .buttonStyle(.primary(isLoading: isSubmitting && errorMode != .join))
                .disabled(!NameInput.isValid(groupName) || isSubmitting)
        }
        .padding(Theme.Spacing.md)
        .cardSurface()
    }

    private var separator: some View {
        HStack(spacing: Theme.Spacing.md) {
            Rectangle().fill(Color.hairline).frame(height: 1)
            Text("O ÚNETE A UNO EXISTENTE")
                .font(.labelSmall)
                .tracking(0.6)
                .foregroundStyle(.textSecondary)
                .fixedSize()
            Rectangle().fill(Color.hairline).frame(height: 1)
        }
        .accessibilityElement(children: .combine)
    }

    private var joinCard: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            cardHeader(
                symbol: "key.fill", tint: .highlight,
                title: "Tengo un código de invitación",
                subtitle: "Pídele el código de \(InviteCode.length) caracteres a quien creó el grupo.")
            CodeBoxes(code: $inviteCode, isFocused: $isCodeFocused, onSubmit: join)
            if errorMode == .join { FormErrorText(message: errorMessage) }
            Button("Unirme al grupo", action: join)
                .buttonStyle(.primary(isLoading: isSubmitting && errorMode == .join))
                .disabled(!InviteCode.isComplete(inviteCode) || isSubmitting)
        }
        .padding(Theme.Spacing.md)
        .cardSurface()
    }

    private func cardHeader(symbol: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            IconTile(symbol: symbol, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                Text(subtitle)
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)
            }
        }
    }

    private func created(_ group: FamilyGroup) -> some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.brand)
            Text("¡Grupo creado!")
                .font(.headlineMedium)
                .foregroundStyle(.textPrimary)
            Text("Comparte este código con tu familia para que se una.")
                .font(.bodyMedium)
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
        submit(.create) { createdGroup = try await groups.create(named: groupName) }
    }

    private func join() {
        guard InviteCode.isComplete(inviteCode), !isSubmitting else { return }
        submit(.join) { session.joined(try await groups.join(code: inviteCode)) }
    }

    private func submit(_ mode: Mode, _ work: @escaping () async throws -> Void) {
        isNameFocused = false
        isCodeFocused = false
        Task {
            isSubmitting = true
            errorMessage = nil
            errorMode = mode
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
