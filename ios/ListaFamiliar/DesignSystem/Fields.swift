import SwiftUI

/// Campo de contraseña con ojo para mostrarla u ocultarla.
/// El foco lo gobierna la pantalla: `focus` es su `@FocusState` y `field` el valor que corresponde a este campo.
struct PasswordField<F: Hashable>: View {
    let placeholder: String
    @Binding var text: String
    var isNew = false
    var focus: FocusState<F?>.Binding
    var field: F
    var submitLabel: SubmitLabel = .done
    var onSubmit: () -> Void = {}

    @State private var isRevealed = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            input
                .focused(focus, equals: field)
                .submitLabel(submitLabel)
                .onSubmit(onSubmit)

            Button {
                isRevealed.toggle()
            } label: {
                Image(systemName: isRevealed ? "eye.slash" : "eye")
                    .foregroundStyle(.textSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isRevealed ? "Ocultar contraseña" : "Mostrar contraseña")
        }
    }

    @ViewBuilder
    private var input: some View {
        if isRevealed {
            typed(TextField(placeholder, text: $text).textInputAutocapitalization(.never).autocorrectionDisabled())
        } else {
            typed(SecureField(placeholder, text: $text))
        }
    }

    @ViewBuilder
    private func typed<V: View>(_ view: V) -> some View {
        if isNew {
            view.textContentType(.newPassword)
        } else {
            view.textContentType(.password)
        }
    }
}

/// Código de invitación en casillas (una por carácter). Debajo hay un campo de texto invisible
/// que recibe el teclado y normaliza lo escrito (`InviteCode.normalize`).
struct CodeBoxes: View {
    @Binding var code: String
    var isFocused: FocusState<Bool>.Binding
    var length = InviteCode.length
    var onSubmit: () -> Void = {}

    var body: some View {
        ZStack {
            TextField("", text: $code)
                .focused(isFocused)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .keyboardType(.asciiCapable)
                .submitLabel(.join)
                .onSubmit(onSubmit)
                .onChange(of: code) { _, newValue in
                    let normalized = InviteCode.normalize(newValue)
                    if normalized != newValue { code = normalized }
                }
                .opacity(0.011)
                .accessibilityLabel("Código de invitación")

            HStack(spacing: Theme.Spacing.sm) {
                ForEach(0..<length, id: \.self) { index in box(at: index) }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .contentShape(.rect)
        .onTapGesture { isFocused.wrappedValue = true }
        .animation(.easeOut(duration: 0.12), value: code)
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let character = index < characters.count ? String(characters[index]) : ""
        let isCurrent = isFocused.wrappedValue && index == min(characters.count, length - 1)
        return Text(character)
            .font(.system(size: 22, weight: .semibold, design: .monospaced))
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, minHeight: Theme.controlHeight)
            .background(Color.appBackground, in: .rect(cornerRadius: Theme.Radius.field))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.Radius.field)
                    .strokeBorder(isCurrent ? Color.brand : Color.hairline, lineWidth: isCurrent ? 2 : 1)
            }
    }
}
