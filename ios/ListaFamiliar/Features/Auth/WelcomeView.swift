import SwiftUI

struct WelcomeView: View {
    let open: (AuthRoute) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.Spacing.lg) {
                hero
                VStack(spacing: Theme.Spacing.sm) {
                    benefit(
                        symbol: "arrow.triangle.2.circlepath", tint: .brand,
                        title: "Sincronización instantánea",
                        text: "Si alguien añade la leche mientras estás en caja, aparece en tu pantalla al instante.")
                    benefit(
                        symbol: "square.grid.2x2.fill", tint: .highlight,
                        title: "Orden por categorías",
                        text: "Frutas, lácteos, limpieza y despensa agrupados para recorrer el súper a la primera.")
                    benefit(
                        symbol: "person.2.fill", tint: Color(hex: 0x2A75D3),
                        title: "Invita con un código",
                        text: "Comparte un código de 6 caracteres y tu familia se une a tus listas en segundos.")
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.xl)
            .padding(.bottom, Theme.Spacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Theme.Spacing.sm) {
                Button { open(.signUp) } label: {
                    HStack(spacing: Theme.Spacing.sm) {
                        Text("Empezar ahora")
                        Image(systemName: "arrow.right")
                    }
                }
                .buttonStyle(.primary)
                Button("Ya tengo cuenta · Iniciar sesión") { open(.signIn) }
                    .buttonStyle(.secondary)
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.top, Theme.Spacing.sm)
            .padding(.bottom, Theme.Spacing.md)
            .background(Color.appBackground.opacity(0.92))
        }
        .frame(maxWidth: .infinity)
        .screenBackground()
    }

    private var hero: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "basket.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 88, height: 88)
                .background(Color.brand, in: .rect(cornerRadius: 26))
                .accessibilityHidden(true)
            VStack(spacing: Theme.Spacing.sm) {
                Text("Lista Familiar")
                    .font(.labelLarge)
                    .foregroundStyle(.brand)
                Text("La compra de casa, sin olvidos ni duplicados.")
                    .font(.headlineLarge)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.center)
                Text("Listas compartidas en tiempo real con tu familia, organizadas por categorías.")
                    .font(.bodyLarge)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func benefit(symbol: String, tint: Color, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            IconTile(symbol: symbol, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headlineSmall)
                    .foregroundStyle(.textPrimary)
                Text(text)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
            }
            Spacer(minLength: 0)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    WelcomeView(open: { _ in }).appStyle()
}
