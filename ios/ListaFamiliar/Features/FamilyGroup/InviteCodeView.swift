import SwiftUI

/// Código de invitación grande, seleccionable, con botón para compartirlo
/// (la hoja de compartir incluye «Copiar»).
struct InviteCodeView: View {
    let group: FamilyGroup
    var codeFont: Font = .inviteCode

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Text(group.inviteCode)
                .font(codeFont)
                .tracking(6)
                .foregroundStyle(.textPrimary)
                .textSelection(.enabled)
                .accessibilityLabel("Código de invitación \(group.inviteCode.map(String.init).joined(separator: " "))")
            ShareLink(item: group.invitationMessage) {
                Label("Compartir código", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.secondary)
        }
    }
}

#Preview {
    InviteCodeView(group: FamilyGroup(
        id: UUID(), name: "Familia García", inviteCode: "ABC123", createdByID: nil, members: [], createdAt: .now))
        .padding()
        .appStyle()
}
