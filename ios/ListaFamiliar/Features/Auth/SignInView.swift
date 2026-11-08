import SwiftUI

struct SignInView: View {
    let switchToSignUp: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var notice: String?
    @State private var isResetting = false
    @State private var resetEmail = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool { Credentials.canSignIn(email: email, password: password) && !isSubmitting }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                header

                LabeledField("Correo electrónico", icon: "envelope", isFocused: focus == .email) {
                    TextField("Correo electrónico", text: $email, prompt: Text(verbatim: "nombre@ejemplo.com"))
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
                        placeholder: "Introduce tu contraseña", text: $password,
                        focus: $focus, field: .password, submitLabel: .go, onSubmit: submit)
                }

                Button("¿Olvidaste tu contraseña?") {
                    resetEmail = email
                    isResetting = true
                }
                .font(.labelMedium)
                .foregroundStyle(.brand)
                .frame(maxWidth: .infinity, alignment: .trailing)

                FormErrorText(message: errorMessage)
                if let notice {
                    Label(notice, systemImage: "envelope.badge")
                        .font(.bodyMedium)
                        .foregroundStyle(.brand)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: submit) {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Iniciar sesión")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.primary(isLoading: isSubmitting))
                .disabled(!canSubmit)

                HStack(spacing: Theme.Spacing.xs) {
                    Text("¿Aún no tienes cuenta?")
                        .foregroundStyle(.textSecondary)
                    Button("Regístrate gratis", action: switchToSignUp)
                        .foregroundStyle(.brand)
                        .font(.labelLarge)
                }
                .font(.bodyMedium)
                .padding(.top, Theme.Spacing.xs)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.lg)
            .animation(.default, value: errorMessage)
            .animation(.default, value: notice)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .alert("Restablecer contraseña", isPresented: $isResetting) {
            TextField("Correo electrónico", text: $resetEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancelar", role: .cancel) {}
            Button("Enviar enlace", action: sendReset)
        } message: {
            Text("Te enviaremos un enlace para crear una contraseña nueva.")
        }
    }

    private func sendReset() {
        guard Credentials.isPlausibleEmail(resetEmail) else {
            errorMessage = "Escribe un correo válido."
            return
        }
        let email = resetEmail
        Task {
            errorMessage = nil
            notice = nil
            do {
                try await session.sendPasswordReset(email: email)
                notice = "Si ese correo tiene cuenta, te hemos enviado un enlace para restablecer la contraseña."
            } catch {
                errorMessage = error.userMessage
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            Image(systemName: "basket.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Color.brand, in: .circle)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("¡Hola de nuevo!")
                    .font(.headlineLarge)
                    .foregroundStyle(.textPrimary)
                Text("Accede a las listas de tu hogar y colabora sin esfuerzo.")
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
                try await session.signIn(email: email, password: password)
            } catch {
                errorMessage = error.userMessage
            }
        }
    }
}

#Preview {
    NavigationStack { SignInView(switchToSignUp: {}) }
        .previewEnvironment(signedIn: false)
}
