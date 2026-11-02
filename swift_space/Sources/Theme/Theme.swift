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

struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            if isLoading {
                ProgressView().tint(.white)
            }
            configuration.label
        }
        .font(.headline)
        .fontDesign(.rounded)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Theme.Colors.brand)
        .cornerRadius(Theme.Radii.button)
        .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
        .opacity(configuration.isPressed ? 0.9 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundColor(Theme.Colors.brand)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Theme.Colors.surface)
            .cornerRadius(Theme.Radii.button)
            .overlay(RoundedRectangle(cornerRadius: Theme.Radii.button).stroke(Theme.Colors.brand, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
    }
}
