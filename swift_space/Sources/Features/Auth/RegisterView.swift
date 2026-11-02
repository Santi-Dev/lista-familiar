import SwiftUI

struct RegisterView: View {
    @Environment(SessionModel.self) private var session
    @State private var vm = RegisterViewModel()


    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.md) {
                Text("Crear cuenta")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, Theme.Spacing.lg)

                AppTextField(label: "Nombre", placeholder: "Tu nombre", text: $vm.name, contentType: .name)
                AppTextField(label: "Correo electrónico", placeholder: "correo@ejemplo.com", text: $vm.email, contentType: .emailAddress, keyboardType: .emailAddress, autocap: .never)
                AppTextField(label: "Contraseña", placeholder: "Mínimo 8 caracteres", text: $vm.password, isSecure: true, contentType: .newPassword)

                if let errorMessage = vm.errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button("Registrarme") {
                    Task { await vm.submit(session: session) }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: vm.isLoading))
                .disabled(!vm.canSubmit)
                .opacity(vm.isValid ? 1 : 0.6)

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
}
