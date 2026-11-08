import SwiftUI

struct ListCard: View {
    let list: ShoppingList

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.name)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: Theme.Spacing.sm)
                if list.isComplete {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.brand)
                        .accessibilityLabel("Completa")
                }
            }
            Text("\(list.purchasedCount) de \(list.itemCount) comprados")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            ProgressView(value: list.progress)
                .tint(.brand)
                .animation(.default, value: list.progress)
            HStack {
                if let creator = list.createdBy {
                    Text("Creada por \(creator.name)")
                }
                Spacer()
                Text(list.updatedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.textSecondary)
        }
        .padding(Theme.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .contentShape(.rect(cornerRadius: Theme.Radius.card))
        .accessibilityElement(children: .combine)
    }
}
