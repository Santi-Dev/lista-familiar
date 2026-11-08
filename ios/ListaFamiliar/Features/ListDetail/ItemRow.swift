import SwiftUI

struct ItemRow: View {
    let item: ListItem
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Button(action: onToggle) {
                Image(systemName: item.isPurchased ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(item.isPurchased ? Color.brand : Color.textSecondary)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(item.isPurchased ? "Marcar \(item.name) como pendiente" : "Marcar \(item.name) como comprado")
            .sensoryFeedback(.impact(weight: .light), trigger: item.isPurchased)

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.bodyLarge)
                        .strikethrough(item.isPurchased)
                        .foregroundStyle(item.isPurchased ? Color.textSecondary : Color.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if let subtitle {
                        Text(subtitle)
                            .font(.bodySmall)
                            .foregroundStyle(item.isPurchased ? Color.brand : Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Editar artículo")
        }
        .frame(minHeight: Theme.controlHeight)
    }

    /// «1 kg · Añadido por Lucía». Si ya está comprado: «1 kg · Comprado por Lucía».
    private var subtitle: String? {
        let parts = [item.quantity, item.attribution].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
