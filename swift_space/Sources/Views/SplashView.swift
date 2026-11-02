import SwiftUI

struct SplashView: View {
    var body: some View {
        ZStack {
            Theme.Colors.brand.ignoresSafeArea()
            VStack(spacing: Theme.Spacing.md) {
                Image(systemName: "cart.fill")
                    .font(.system(size: 48))
                    .foregroundColor(Theme.Colors.brand)
                    .padding(Theme.Spacing.lg)
                    .background(RoundedRectangle(cornerRadius: 20).fill(.white))
                Text("Lista Familiar")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                ProgressView()
                    .tint(.white)
            }
        }
    }
}
