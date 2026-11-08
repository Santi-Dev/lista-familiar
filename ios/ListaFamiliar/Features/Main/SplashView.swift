import SwiftUI

struct SplashView: View {
    var body: some View {
        VStack(spacing: Theme.Spacing.md) {
            Image(systemName: "cart.fill")
                .font(.system(size: 48))
                .foregroundStyle(.brand)
                .padding(Theme.Spacing.lg)
                .background(.white, in: .rect(cornerRadius: 20))
            Text("Lista Familiar")
                .font(.heroTitle)
                .foregroundStyle(.white)
            ProgressView()
                .tint(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.brand.ignoresSafeArea())
    }
}

#Preview {
    SplashView().appStyle()
}
