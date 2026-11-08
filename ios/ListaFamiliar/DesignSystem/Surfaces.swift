import SwiftUI

// Liquid Glass en iOS 26+ con una alternativa clásica para iOS 18-25.

extension View {
    /// Cristal tintado de marca (iOS 26+) o relleno sólido de marca.
    /// Bajo el cristal hay un relleno sólido: el texto blanco mantiene el contraste aunque el cristal
    /// no se dibuje (por ejemplo, en simuladores de Mac Intel o con «Reducir transparencia»).
    @ViewBuilder
    func brandSurface<S: Shape>(in shape: S, interactive: Bool = true) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.tint(.brand).interactive(interactive), in: shape)
                .background(Color.brand, in: shape)
        } else {
            background(Color.brand, in: shape)
        }
    }

    /// Cristal neutro (iOS 26+) o superficie con borde de marca.
    @ViewBuilder
    func neutralSurface<S: InsettableShape>(in shape: S, interactive: Bool = true) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular.interactive(interactive), in: shape)
                .background(Color.surface.opacity(0.7), in: shape)
        } else {
            background(Color.surface, in: shape)
                .overlay(shape.strokeBorder(Color.brand, lineWidth: 1))
        }
    }

    /// Chip de filtro: tintado si está seleccionado.
    @ViewBuilder
    func chipSurface(isSelected: Bool) -> some View {
        if #available(iOS 26, *) {
            glassEffect(isSelected ? .regular.tint(.brand).interactive() : .regular.interactive(), in: .capsule)
                .background(isSelected ? Color.brand : Color.clear, in: .capsule)
        } else {
            background(isSelected ? Color.brand : Color.surface, in: .capsule)
                .overlay(Capsule().strokeBorder(isSelected ? .clear : Color.hairline, lineWidth: 0.5))
        }
    }

    /// Superficie flotante para avisos.
    @ViewBuilder
    func floatingSurface<S: Shape>(in shape: S) -> some View {
        if #available(iOS 26, *) {
            glassEffect(.regular, in: shape)
        } else {
            background(.regularMaterial, in: shape)
        }
    }

    /// Tarjeta sobre el fondo de la app.
    func cardSurface() -> some View {
        background(Color.surface, in: .rect(cornerRadius: Theme.Radius.card))
            .overlay(RoundedRectangle(cornerRadius: Theme.Radius.card).strokeBorder(Color.hairline, lineWidth: 0.5))
    }

    /// Fondo de pantalla de la app.
    func screenBackground() -> some View {
        background(Color.appBackground.ignoresSafeArea())
    }
}
