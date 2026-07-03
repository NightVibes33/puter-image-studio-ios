import SwiftUI

struct RootView: View {
    @State private var isShowingSplash = true

    var body: some View {
        ZStack {
            GenerateView()

            if isShowingSplash {
                SplashView {
                    dismissSplash()
                }
                .transition(.opacity.combined(with: .scale(scale: 1.02)))
                .zIndex(1)
            }
        }
        .dynamicTypeSize(.small ... .large)
    }

    private func dismissSplash() {
        guard isShowingSplash else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            isShowingSplash = false
        }
    }
}
