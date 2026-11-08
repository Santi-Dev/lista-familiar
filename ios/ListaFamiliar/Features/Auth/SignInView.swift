import SwiftUI

struct SignInView: View {
    let switchToSignUp: () -> Void

    @Environment(SessionStore.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    private var canSubmit: Bool { Credentials.canSignIn(email: email, password: password) && !isSubmitting }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Iniciar sesión")
                    .font(.screenTitle)
                    .foregroundStyle(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                LabeledField("Correo electrónico", isFocused: focus == .email) {
                    TextField("correo@ejemplo.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($focus, equals: .email)
                        .submitLabel(.next)
                        .onSubmit { focus = .password }
                }
                LabeledField("Contraseña", isFocused: focus == .password) {
                    SecureField("Tu contraseña", text: $password)
                        .textContentType(.password)
                        .focused($focus, equals: .password)
                        .submitLabel(.go)
                        .onSubmit(submit)
                }

                FormErrorText(message: errorMessage)

                Button("Entrar", action: submit)
                    .buttonStyle(.primary(isLoading: isSubmitting))
                    .disabled(!canSubmit)

                Button("¿No tienes cuenta? Regístrate", action: switchToSignUp)
                    .font(.subheadline)
                    .foregroundStyle(.brand)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .animation(.default, value: errorMessage)
        }
        .scrollDismissesKeyboard(.interactively)
        .screenBackground()
        .navigationBarTitleDisplayMode(.inline)
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
