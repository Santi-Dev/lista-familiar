import SwiftUI

/// Círculo con la inicial de una persona. El color sale del nombre, así que siempre es el mismo.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 36

    private static let palette: [(background: Color, foreground: Color)] = [
        (Color(hex: 0xABF3BF), Color(hex: 0x00210F)),
        (Color(hex: 0xFFDCC3), Color(hex: 0x2F1500)),
        (Color(hex: 0xD6E3FF), Color(hex: 0x001B3D)),
        (Color(hex: 0xE1E3E1), Color(hex: 0x191C1B)),
    ]

    private var colors: (background: Color, foreground: Color) {
        let sum = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        return Self.palette[sum % Self.palette.count]
    }

    private var initial: String {
        String(name.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.42, weight: .bold))
            .foregroundStyle(colors.foreground)
            .frame(width: size, height: size)
            .background(colors.background, in: .circle)
            .accessibilityHidden(true)
    }
}

/// Avatares superpuestos con un «+N» si hay más de los que caben.
struct AvatarStack: View {
    let names: [String]
    var maxVisible = 3
    var size: CGFloat = 28

    var body: some View {
        HStack(spacing: -size * 0.3) {
            ForEach(Array(names.prefix(maxVisible).enumerated()), id: \.offset) { _, name in
                AvatarView(name: name, size: size)
                    .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
            }
            if names.count > maxVisible {
                Text("+\(names.count - maxVisible)")
                    .font(.system(size: size * 0.38, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: size, height: size)
                    .background(Color.brand, in: .circle)
                    .overlay(Circle().strokeBorder(Color.surface, lineWidth: 2))
            }
        }
        .accessibilityHidden(true)
    }
}

/// Icono dentro de un cuadrado redondeado con el tinte suave del color.
struct IconTile: View {
    let symbol: String
    var tint: Color = .brand
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.45, weight: .semibold))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(tint.opacity(0.14), in: .rect(cornerRadius: size * 0.3))
            .accessibilityHidden(true)
    }
}

/// Etiqueta pequeña en forma de píldora («Completa», «3 pendientes»…).
struct StatusChip: View {
    let text: String
    var symbol: String? = nil
    var tint: Color = .brand

    var body: some View {
        HStack(spacing: 4) {
            if let symbol { Image(systemName: symbol) }
            Text(text)
        }
        .font(.labelSmall)
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

/// Barra de progreso de 0 a 1.
struct ProgressBar: View {
    let value: Double
    var tint: Color = .brand
    var height: CGFloat = 8

    private var clamped: Double { min(max(value, 0), 1) }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.hairline)
                if clamped > 0 {
                    Capsule()
                        .fill(tint)
                        .frame(width: max(height, proxy.size.width * clamped))
                }
            }
        }
        .frame(height: height)
        .animation(.default, value: clamped)
        .accessibilityElement()
        .accessibilityLabel("Progreso")
        .accessibilityValue(Text(clamped, format: .percent.precision(.fractionLength(0))))
    }
}
