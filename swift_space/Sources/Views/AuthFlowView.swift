import SwiftUI

struct AuthFlowView: View {
    var body: some View {
        NavigationStack {
            WelcomeView()
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "carrot.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.Colors.brand)
                Image(systemName: "cart.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.Colors.accent)
                Image(systemName: "basket.fill")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.Colors.brand)
            }
            .padding(Theme.Spacing.lg)
            .background(Circle().fill(Theme.Colors.brand.opacity(0.08)).frame(width: 160, height: 160))

            Text("Lista Familiar")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Haced la compra juntos. Una lista compartida para toda la familia, siempre al día.")
                .font(.body)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.Spacing.xl)
            Spacer()
            VStack(spacing: Theme.Spacing.sm) {
                NavigationLink(destination: RegisterView()) {
                    Text("Crear cuenta")
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.Colors.brand)
                        .cornerRadius(Theme.Radii.button)
                }
                NavigationLink(destination: LoginView()) {
                    Text("Ya tengo cuenta · Iniciar sesión")
                        .font(.headline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.brand)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Theme.Colors.surface)
                        .cornerRadius(Theme.Radii.button)
                        .overlay(RoundedRectangle(cornerRadius: Theme.Radii.button).stroke(Theme.Colors.brand, lineWidth: 1))
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .background(Theme.Colors.background.ignoresSafeArea())
    }
}
