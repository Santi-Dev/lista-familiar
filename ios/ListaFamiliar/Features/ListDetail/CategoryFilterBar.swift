import SwiftUI

/// Chips horizontales para filtrar por categoría, con el número de pendientes de cada una.
struct CategoryFilterBar: View {
    @Binding var selection: ItemCategory?
    let items: [ListItem]

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: Theme.Spacing.sm) {
                chip("Todas", symbol: nil, pending: 0, isSelected: selection == nil) { selection = nil }
                ForEach(ItemCategory.allCases) { category in
                    chip(category.title, symbol: category.symbol, pending: items.pendingCount(in: category),
                         isSelected: selection == category) { selection = category }
                }
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.sm)
        }
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(_ title: String, symbol: String?, pending: Int, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.xs) {
                if let symbol { Image(systemName: symbol) }
                Text(title)
                if pending > 0 { CountBadge(count: pending) }
            }
            .font(.caption)
            .foregroundStyle(isSelected ? Color.white : Color.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, Theme.Spacing.sm)
            .chipSurface(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
