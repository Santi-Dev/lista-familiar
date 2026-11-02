import SwiftUI

struct AppTextField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure = false
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocap: TextInputAutocapitalization = .sentences
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textSecondary)
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .textContentType(contentType)
                        .focused($focused)
                } else {
                    TextField(placeholder, text: $text)
                        .textContentType(contentType)
                        .keyboardType(keyboardType)
                        .textInputAutocapitalization(autocap)
                        .focused($focused)
                }
            }
            .font(.body)
            .fontDesign(.rounded)
            .padding()
            .background(RoundedRectangle(cornerRadius: Theme.Radii.field).fill(Theme.Colors.surface))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radii.field).stroke(focused ? Theme.Colors.brand : Theme.Colors.separator, lineWidth: 1))
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    var buttonTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundColor(Theme.Colors.brand)
                .padding(Theme.Spacing.md)
                .background(Circle().fill(Theme.Colors.brand.opacity(0.12)))
            Text(title)
                .font(.headline)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textPrimary)
            Text(subtitle)
                .font(.body)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 200)
            }
        }
        .padding(Theme.Spacing.xl)
    }
}

struct ErrorStateView: View {
    let message: String
    var retryAction: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title)
                .foregroundColor(Theme.Colors.accent)
            Text(message)
                .font(.body)
                .fontDesign(.rounded)
                .foregroundColor(Theme.Colors.textPrimary)
                .multilineTextAlignment(.center)
            if let retryAction {
                Button("Reintentar", action: retryAction)
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 160)
            }
        }
        .padding(Theme.Spacing.lg)
    }
}
