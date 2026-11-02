import SwiftUI

struct LoginView: View {
    @Environment(SessionModel.self) private var session
    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Iniciar sesión")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                AppTextField(label: "Correo electrónico", placeholder: "correo@ejemplo.com", text: $email, contentType: .emailAddress, keyboardType: .emailAddress, autocap: .never)
                AppTextField(label: "Contraseña", placeholder: "", text: $password, isSecure: true, contentType: .password)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Entrar") {
                    Task { await doLogin() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                .disabled(email.isEmpty || password.isEmpty || isLoading)
                .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)

                NavigationLink(destination: RegisterView()) {
                    Text("¿No tienes cuenta? Regístrate")
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

    private func doLogin() async {
        isLoading = true
        errorMessage = nil
        do {
            try await session.login(email: email, password: password)
        } catch let error as APIError {
            if case .http(let status, let msg) = error {
                errorMessage = status == 401 ? "Correo o contraseña incorrectos" : (msg ?? "Error desconocido")
            } else {
                errorMessage = "No se pudo conectar. Inténtalo de nuevo."
            }
        } catch {
            errorMessage = "No se pudo conectar. Inténtalo de nuevo."
        }
        isLoading = false
    }
}
