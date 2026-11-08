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
                Text("Crear cuenta")
                    .font(.screenTitle)
                    .foregroundStyle(.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                LabeledField("Nombre", isFocused: focus == .name) {
                    TextField("Tu nombre", text: $name)
                        .textContentType(.givenName)
                        .focused($focus, equals: .name)
                        .submitLabel(.next)
                        .onSubmit { focus = .email }
                }
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
                    SecureField("Mínimo \(Credentials.minimumPasswordLength) caracteres", text: $password)
                        .textContentType(.newPassword)
                        .focused($focus, equals: .password)
                        .submitLabel(.join)
                        .onSubmit(submit)
                }

                FormErrorText(message: errorMessage)

                Button("Registrarme", action: submit)
                    .buttonStyle(.primary(isLoading: isSubmitting))
                    .disabled(!canSubmit)

                Button("¿Ya tienes cuenta? Inicia sesión", action: switchToSignIn)
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
