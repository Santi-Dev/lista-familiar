import SwiftUI

/// Campo con etiqueta y estilo de la app. El contenido es el `TextField`/`SecureField`
/// con sus propios modificadores (`.textContentType`, `.focused`…); `isFocused` resalta el borde.
struct LabeledField<Field: View>: View {
    let label: String
    var icon: String?
    var isFocused: Bool
    @ViewBuilder var field: Field

    init(_ label: String, icon: String? = nil, isFocused: Bool = false, @ViewBuilder field: () -> Field) {
        self.label = label
        self.icon = icon
        self.isFocused = isFocused
        self.field = field()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(label)
                .font(.labelMedium)
                .foregroundStyle(.textPrimary)
            HStack(spacing: Theme.Spacing.sm) {
                if let icon {
                    Image(systemName: icon)
                        .foregroundStyle(.textSecondary)
                        .frame(width: 22)
                        .accessibilityHidden(true)
                }
                field
            }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 14)
                .background(Color.surface, in: .rect(cornerRadius: Theme.Radius.field))
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.Radius.field)
                        .strokeBorder(isFocused ? Color.brand : Color.hairline, lineWidth: 1)
                }
                .animation(.easeOut(duration: 0.15), value: isFocused)
        }
    }
}

/// Mensaje de error de un formulario (no ocupa sitio si no hay error).
struct FormErrorText: View {
    let message: String?

    var body: some View {
        if let message {
            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.opacity)
        }
    }
}

/// Pantalla vacía con icono, texto y una acción opcional.
struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 52))
                .foregroundStyle(.brand)
                .frame(width: 96, height: 96)
                .background(Color.brand.opacity(0.12), in: .circle)
            Text(title)
                .font(.headlineSmall)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
            if let message {
                Text(message)
                    .font(.bodyMedium)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.primary)
                    .frame(maxWidth: 220)
            }
        }
        .padding(Theme.Spacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Error de carga con botón de reintento.
struct ErrorStateView: View {
    let message: String
    var retry: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundStyle(.highlight)
            Text(message)
                .foregroundStyle(.textPrimary)
                .multilineTextAlignment(.center)
            if let retry {
                Button("Reintentar", action: retry)
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 180)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Contador naranja de pendientes.
struct CountBadge: View {
    let count: Int

    var body: some View {
        Text(count, format: .number)
            .font(.labelSmall)
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.highlight, in: .capsule)
    }
}

/// Esqueleto de carga.
struct PlaceholderRows: View {
    var count = 4
    var height: CGFloat = 52

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<count, id: \.self) { _ in
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .fill(Color.surface)
                    .frame(height: height)
            }
        }
        .padding(Theme.Spacing.lg)
        .frame(maxHeight: .infinity, alignment: .top)
        .accessibilityLabel("Cargando")
    }
}

// MARK: - Aviso flotante

extension View {
    /// Muestra `message` en un aviso flotante abajo durante 2 segundos y después lo borra.
    func toast(_ message: Binding<String?>) -> some View {
        modifier(ToastModifier(message: message))
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: String?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if let message {
                    Text(message)
                        .font(.bodyMedium)
                        .foregroundStyle(.textPrimary)
                        .padding(.horizontal, Theme.Spacing.md)
                        .padding(.vertical, Theme.Spacing.sm)
                        .floatingSurface(in: .capsule)
                        .padding(.bottom, Theme.Spacing.md)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .animation(.spring(duration: 0.3), value: message)
            .task(id: message) {
                guard message != nil else { return }
                try? await Task.sleep(for: .seconds(2))
                message = nil
            }
    }
}
