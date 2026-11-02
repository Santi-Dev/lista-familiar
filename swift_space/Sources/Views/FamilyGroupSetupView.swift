import SwiftUI

struct FamilyGroupSetupView: View {
    @Environment(SessionModel.self) private var session
    @State private var mode = 0 // 0=create, 1=join
    @State private var groupName = ""
    @State private var inviteCode = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var createdGroup: FamilyGroupDto?
    @State private var codeCopied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Theme.Spacing.lg) {
                    Text("Hola, \(session.user?.name ?? "")")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Para empezar, crea tu grupo familiar o únete al de tu familia.")
                        .font(.body)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Picker("", selection: $mode) {
                        Text("Crear grupo").tag(0)
                        Text("Unirme con código").tag(1)
                    }
                    .pickerStyle(.segmented)

                    if mode == 0 {
                        createGroupContent
                    } else {
                        joinGroupContent
                    }
                }
                .padding(Theme.Spacing.lg)
            }
            .background(Theme.Colors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar sesión") { session.logout() }
                        .font(.subheadline)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                }
            }
        }
    }

    @ViewBuilder
    private var createGroupContent: some View {
        if let group = createdGroup {
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.brand)
                Text("¡Grupo creado!")
                    .font(.title2)
                    .fontDesign(.rounded)
                    .bold()
                Text(group.inviteCode)
                    .font(.system(size: 34, weight: .semibold, design: .monospaced))
                    .tracking(6)
                    .foregroundColor(Theme.Colors.textPrimary)
                HStack(spacing: Theme.Spacing.sm) {
                    Button {
                        UIPasteboard.general.string = group.inviteCode
                        codeCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { codeCopied = false }
                    } label: {
                        Label(codeCopied ? "Código copiado" : "Copiar código", systemImage: codeCopied ? "checkmark" : "doc.on.doc")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .sensoryFeedback(.success, trigger: codeCopied)

                    ShareLink(item: "Únete a nuestra lista de la compra en Lista Familiar con el código: \(group.inviteCode)") {
                        Label("Compartir", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                Button("Continuar") {
                    session.setFamilyGroup(id: group.id)
                }
                .buttonStyle(PrimaryButtonStyle())
            }
            .padding(Theme.Spacing.md)
            .background(RoundedRectangle(cornerRadius: Theme.Radii.card).fill(Theme.Colors.surface))
        } else {
            VStack(spacing: Theme.Spacing.md) {
                AppTextField(label: "Nombre del grupo", placeholder: "Familia García", text: $groupName)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .fontDesign(.rounded)
                        .foregroundColor(Theme.Colors.destructive)
                }
                Button("Crear grupo") {
                    Task { await createGroup() }
                }
                .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
                .disabled(groupName.isEmpty || isLoading)
                .opacity(groupName.isEmpty ? 0.6 : 1)
            }
        }
    }

    @ViewBuilder
    private var joinGroupContent: some View {
        VStack(spacing: Theme.Spacing.md) {
            AppTextField(label: "Código de invitación", placeholder: "ABC123", text: $inviteCode, autocap: .characters)
                .onChange(of: inviteCode) { _, newVal in
                    inviteCode = String(newVal.uppercased().prefix(6))
                }
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .fontDesign(.rounded)
                    .foregroundColor(Theme.Colors.destructive)
            }
            Button("Unirme") {
                Task { await joinGroup() }
            }
            .buttonStyle(PrimaryButtonStyle(isLoading: isLoading))
            .disabled(inviteCode.count != 6 || isLoading)
            .opacity(inviteCode.count != 6 ? 0.6 : 1)
        }
    }

    private func createGroup() async {
        isLoading = true
        errorMessage = nil
        do {
            let group = try await APIClient.shared.create(body: CreateGroupDto(name: groupName))
            createdGroup = group
        } catch let error as APIError {
            if case .http(_, let msg) = error { errorMessage = msg ?? "Error" }
            else { errorMessage = "No se pudo conectar." }
        } catch {
            errorMessage = "No se pudo conectar."
        }
        isLoading = false
    }

    private func joinGroup() async {
        isLoading = true
        errorMessage = nil
        do {
            let group = try await APIClient.shared.join(body: JoinGroupDto(inviteCode: inviteCode))
            session.setFamilyGroup(id: group.id)
        } catch let error as APIError {
            if case .http(let status, let msg) = error {
                errorMessage = status == 404 ? "Código no válido. Revisa e inténtalo de nuevo." : (msg ?? "Error")
            } else { errorMessage = "No se pudo conectar." }
        } catch {
            errorMessage = "No se pudo conectar."
        }
        isLoading = false
    }
}
