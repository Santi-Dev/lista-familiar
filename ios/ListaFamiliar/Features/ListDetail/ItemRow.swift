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
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name)
                            .strikethrough(item.isPurchased)
                            .foregroundStyle(item.isPurchased ? Color.textSecondary : Color.textPrimary)
                        if let attribution = item.attribution {
                            Text(attribution)
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    if let quantity = item.quantity {
                        Text(quantity)
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Editar artículo")
        }
        .frame(minHeight: Theme.controlHeight)
    }
}
