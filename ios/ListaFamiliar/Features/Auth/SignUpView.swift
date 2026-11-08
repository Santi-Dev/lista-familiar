import SwiftUI

struct SignUpView: View {
    let switchToSignIn: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case name, email, password }

    private var canSubmit: Bool {
        Credentials.canSignUp(name: name, email: email, password: password) && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                header

                LabeledField("Nombre", icon: "person", isFocused: focus == .name) {
                    TextField("Tu nombre", text: $name)
                        .textContentType(.givenName)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                }
                LabeledField("Correo electrónico", icon: "envelope", isFocused: focus == .email) {
                    TextField("nombre@ejemplo.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                LabeledField("Contraseña", icon: "lock", isFocused: focus == .password) {
                    PasswordField(
                        placeholder: "Mínimo \(Credentials.minimumPasswordLength) caracteres", text: $password,
                        isNew: true, focus: $focus, field: .password, submitLabel: .join, onSubmit: submit)
                }

                FormErrorText(message: errorMessage)

                Button(action: submit) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Crear mi cuenta")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.primary(isLoading: isSubmitting))
                .disabled(!canSubmit)

                HStack(spacing: Theme.Spacing.xs) {
                    Text("¿Ya tienes cuenta?")
                        .foregroundStyle(.textSecondary)
                    Button("Inicia sesión", action: switchToSignIn)
                        .foregroundStyle(.brand)
                        .font(.labelLarge)
                }
                .font(.bodyMedium)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
            .animation(.default, value: errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "house.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.brand, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Únete a tu hogar")
                    .font(.headlineLarge)
                    .foregroundStyle(.textPrimary)
                Text("Crea tu cuenta para compartir las compras con tu familia en tiempo real.")
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, Theme.Spacing.sm)
        .padding(.bottom, Theme.Spacing.sm)
    }

    private func submit() {
        guard canSubmit else { return }
        Task {
            isSubmitting = true
            errorMessage = nil
            defer { isSubmitting = false }
            do {
                try await session.signUp(name: name, email: email, password: password)
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    NavigationStack { SignUpView(switchToSignIn: {}) }
        .previewEnvironment(signedIn: false)
}
