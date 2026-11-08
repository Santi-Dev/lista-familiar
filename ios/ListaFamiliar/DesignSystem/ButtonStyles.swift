import SwiftUI

/// Botón principal a todo el ancho. Muestra un indicador mientras `isLoading`
/// y se atenúa solo cuando está desactivado (`.disabled`).
struct PrimaryButtonStyle: ButtonStyle {
    var isLoading = false

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, isLoading: isLoading)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        let isLoading: Bool
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            HStack(spacing: Theme.Spacing.sm) {
                if isLoading { ProgressView().tint(.white) }
                configuration.label
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
            .brandSurface(in: .capsule)
            .opacity(isEnabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
    }
}

/// Botón secundario a todo el ancho.
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        let configuration: Configuration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.headline)
                .foregroundStyle(.brand)
                .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
                .neutralSurface(in: .capsule)
                .opacity(isEnabled ? 1 : 0.5)
                .scaleEffect(configuration.isPressed ? 0.97 : 1)
                .animation(.snappy(duration: 0.15), value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
    static func primary(isLoading: Bool) -> PrimaryButtonStyle { PrimaryButtonStyle(isLoading: isLoading) }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
