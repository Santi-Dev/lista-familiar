import SwiftUI

struct LoginView: View {
    @Environment(SessionModel.self) private var session
    @State private var vm = LoginViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Iniciar sesión")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                AppTextField(label: "Correo electrónico", placeholder: "correo@ejemplo.com", text: $vm.email, contentType: .emailAddress, keyboardType: .emailAddress, autocap: .never)
                AppTextField(label: "Contraseña", placeholder: "", text: $vm.password, isSecure: true, contentType: .password)

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Entrar") {
                    Task { await vm.submit(session: session) }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
                .disabled(!vm.canSubmit)
                .opacity(vm.canSubmit ? 1 : 0.6)

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
}
