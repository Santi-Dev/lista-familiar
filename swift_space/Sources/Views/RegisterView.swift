import SwiftUI

struct RegisterView: View {
    @Environment(SessionModel.self) private var session
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var isValid: Bool {
        !name.isEmpty && email.contains("@") && password.count >= 8
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Crear cuenta")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                AppTextField(label: "Nombre", placeholder: "Tu nombre", text: $name, contentType: .name)
                AppTextField(label: "Correo electrónico", placeholder: "correo@ejemplo.com", text: $email, contentType: .emailAddress, keyboardType: .emailAddress, autocap: .never)
                AppTextField(label: "Contraseña", placeholder: "Mínimo 8 caracteres", text: $password, isSecure: true, contentType: .newPassword)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Registrarme") {
                    Task { await doSignup() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                .disabled(!isValid || isLoading)
                .opacity(!isValid ? 0.6 : 1)

                NavigationLink(destination: LoginView()) {
                    Text("¿Ya tienes cuenta? Inicia sesión")
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.brand)
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func doSignup() async {
        isLoading = true
        errorMessage = nil
        do {
            try await session.signup(email: email, password: password, name: name)
        } catch let error as APIError {
            if case .http(let status, let msg) = error {
                errorMessage = status == 409 ? "Este correo ya está registrado" : (msg ?? "Error desconocido")
            } else {
                errorMessage = "No se pudo conectar. Inténtalo de nuevo."
            }
        } catch {
            errorMessage = "No se pudo conectar. Inténtalo de nuevo."
        }
        isLoading = false
    }
}
