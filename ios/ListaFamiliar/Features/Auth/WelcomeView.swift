import SwiftUI

struct WelcomeView: View {
    let open: (AuthRoute) -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.lg) {
            Spacer()
            HStack(spacing: Theme.Spacing.md) {
                Image(systemName: "carrot.fill").foregroundStyle(.brand)
                Image(systemName: "cart.fill").foregroundStyle(.highlight)
                Image(systemName: "basket.fill").foregroundStyle(.brand)
            }
            .font(.system(size: 36))
            .frame(width: 160, height: 160)
            .background(Color.brand.opacity(0.08), in: .circle)
            .accessibilityHidden(true)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Lista Familiar")
                    .font(.heroTitle)
                    .foregroundStyle(.textPrimary)
                Text("Todas tus compras en una sola lista, compartida con tu familia y siempre al día.")
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Theme.Spacing.xl)
            }
            Spacer()

            VStack(spacing: Theme.Spacing.sm) {
                Button("Crear cuenta") { open(.signUp) }
                    .buttonStyle(.primary)
                Button("Ya tengo cuenta · Iniciar sesión") { open(.signIn) }
                    .buttonStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.bottom, Theme.Spacing.xl)
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
    }
}

#Preview {
    WelcomeView(open: { _ in }).appStyle()
}
