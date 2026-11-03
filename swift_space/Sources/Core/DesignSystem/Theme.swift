import SwiftUI

enum Theme {
    enum Colors {
        static let background = dynamic(light: (0.965, 0.957, 0.933), dark: (0.071, 0.082, 0.073))
        static let surface = dynamic(light: (1, 1, 1), dark: (0.110, 0.129, 0.114))
        static let textPrimary = dynamic(light: (0.118, 0.165, 0.137), dark: (0.933, 0.949, 0.933))
        static let textSecondary = dynamic(light: (0.373, 0.420, 0.392), dark: (0.604, 0.647, 0.616))
        static let brand = dynamic(light: (0.180, 0.490, 0.310), dark: (0.263, 0.627, 0.420))
        static let accent = dynamic(light: (0.878, 0.478, 0.180), dark: (0.910, 0.545, 0.259))
        static let separator = dynamic(light: (0.894, 0.878, 0.839), dark: (0.165, 0.196, 0.173))
        static let destructive = Color.red

        /// Color que cambia con el modo claro/oscuro del sistema.
        private static func dynamic(light: (CGFloat, CGFloat, CGFloat), dark: (CGFloat, CGFloat, CGFloat)) -> Color {
            Color(uiColor: UIColor { traits in
                let c = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
            })
        }
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    enum Radii {
        static let card: CGFloat = 16
        static let button: CGFloat = 14
        static let field: CGFloat = 12
        static let chip: CGFloat = 20
    }
}

// MARK: - Liquid Glass (iOS 26+) con alternativa clásica para iOS 18-25

extension View {
    /// Botón principal: cristal tintado de marca en iOS 26+, relleno sólido antes.
    @ViewBuilder
    func primaryControlSurface(interactive: Bool = true) -> some View {
        let base = self
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        if #available(iOS 26, *) {
            base.glassEffect(.regular.tint(Theme.Colors.brand).interactive(interactive), in: Capsule())
        } else {
            base
                .background(Theme.Colors.brand)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.button))
        }
    }

    /// Botón secundario: cristal neutro en iOS 26+, superficie con borde antes.
    @ViewBuilder
    func secondaryControlSurface(interactive: Bool = true) -> some View {
        let base = self
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(Theme.Colors.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
        if #available(iOS 26, *) {
            base.glassEffect(.regular.interactive(interactive), in: Capsule())
        } else {
            base
                .background(Theme.Colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radii.button))
                .overlay(RoundedRectangle(cornerRadius: Theme.Radii.button).stroke(Theme.Colors.brand, lineWidth: 1))
        }
    }

    /// Chip de filtro: cristal (tintado si está seleccionado) en iOS 26+.
    @ViewBuilder
    func chipSurface(isSelected: Bool) -> some View {
        if #available(iOS 26, *) {
            self
                .foregroundStyle(isSelected ? Color.white : Theme.Colors.textPrimary)
                .glassEffect(isSelected ? .regular.tint(Theme.Colors.brand).interactive() : .regular.interactive(), in: Capsule())
        } else {
            self
                .foregroundStyle(isSelected ? Color.white : Theme.Colors.textPrimary)
                .background(Capsule().fill(isSelected ? Theme.Colors.brand : Theme.Colors.surface))
                .overlay(Capsule().stroke(isSelected ? Color.clear : Theme.Colors.separator, lineWidth: 0.5))
        }
    }

    /// Superficie flotante (avisos, barras): cristal en iOS 26+, material antes.
    @ViewBuilder
    func floatingSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView().tint(.white)
            }
            configuration.label
        }
        .primaryControlSurface()
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .secondaryControlSurface()
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
