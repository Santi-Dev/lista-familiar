import SwiftUI

enum Theme {
    enum Colors {
        static let background = Color(red: 0.965, green: 0.957, blue: 0.933)
        static let surface = Color.white
        static let textPrimary = Color(red: 0.118, green: 0.165, blue: 0.137)
        static let textSecondary = Color(red: 0.373, green: 0.420, blue: 0.392)
        static let brand = Color(red: 0.180, green: 0.490, blue: 0.310)
        static let accent = Color(red: 0.878, green: 0.478, blue: 0.180)
        static let separator = Color(red: 0.894, green: 0.878, blue: 0.839)
        static let destructive = Color.red
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
