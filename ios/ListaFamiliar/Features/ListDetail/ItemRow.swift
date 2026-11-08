import SwiftUI

struct ItemRow: View {
    let item: ListItem
    /// Los lectores ven el artículo, pero no lo marcan ni lo editan.
    var isEditable = true
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
            .disabled(!isEditable)
            .accessibilityLabel(item.isPurchased ? "Marcar \(item.name) como pendiente" : "Marcar \(item.name) como comprado")
            .sensoryFeedback(.impact(weight: .light), trigger: item.isPurchased)

            Button(action: onEdit) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                        Text(item.name)
                            .font(.bodyLarge)
                            .strikethrough(item.isPurchased)
                            .foregroundStyle(item.isPurchased ? Color.textSecondary : Color.textPrimary)
                        if item.isUrgent && !item.isPurchased {
                            StatusChip(text: "Urgente", symbol: "flame.fill", tint: .red)
                        }
                        Spacer(minLength: 0)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.bodySmall)
                            .foregroundStyle(item.isPurchased ? Color.brand : Color.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if let assignee = item.assignee, !item.isPurchased {
                        HStack(spacing: Theme.Spacing.xs) {
                            AvatarView(name: assignee.name, size: 18)
                            Text("Para \(assignee.name)")
                                .font(.labelSmall)
                                .foregroundStyle(.highlight)
                        }
                    }
                    if let note = item.note {
                        Text(note)
                            .font(.bodySmall.italic())
                            .foregroundStyle(.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .disabled(!isEditable)
            .accessibilityHint(isEditable ? "Editar artículo" : "")
        }
        .padding(.vertical, Theme.Spacing.xs)
        .frame(minHeight: Theme.controlHeight)
    }

    /// «1 kg · Añadido por Lucía». Si ya está comprado: «1 kg · Comprado por Lucía».
    private var subtitle: String? {
        let parts = [item.quantity, item.attribution].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
