import SwiftUI

struct ListCard: View {
    let list: ShoppingList

    private var tint: Color { list.isComplete ? .brand : list.icon.tint }
    private var pending: Int { list.itemCount - list.purchasedCount }

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Spacing.md) {
            IconTile(symbol: list.icon.symbol, tint: list.icon.tint, size: 48)

            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: Theme.Spacing.sm) {
                    Text(list.name)
                        .font(.headlineSmall)
                        .foregroundStyle(.textPrimary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if list.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.footnote)
                            .foregroundStyle(.textSecondary)
                            .accessibilityLabel("Fijada")
                    }
                }

                HStack(spacing: Theme.Spacing.sm) {
                    status
                    if let store = list.store {
                        StatusChip(text: store, symbol: "storefront", tint: .textSecondary)
                    }
                }

                Text("\(list.purchasedCount) de \(list.itemCount) comprados")
                    .font(.bodySmall)
                    .foregroundStyle(.textSecondary)

                ProgressBar(value: list.progress, tint: tint)

                HStack {
                    if let creator = list.createdBy {
                        Text("Creada por \(creator.name)")
                    }
                    Spacer(minLength: Theme.Spacing.sm)
                    Text(list.updatedAt, format: .relative(presentation: .named))
                }
                .font(.bodySmall)
                .foregroundStyle(.textSecondary)
            }
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if list.isArchived {
            StatusChip(text: "Archivada", symbol: "archivebox.fill", tint: .textSecondary)
        } else if list.isComplete {
            StatusChip(text: "Completa", symbol: "checkmark.seal.fill", tint: .brand)
        } else if list.itemCount == 0 {
            StatusChip(text: "Vacía", tint: .textSecondary)
        } else {
            StatusChip(text: pending == 1 ? "1 pendiente" : "\(pending) pendientes", tint: .highlight)
        }
    }
}
