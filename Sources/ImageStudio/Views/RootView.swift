import SwiftUI

struct RootView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
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
        .onOpenURL(perform: handleOpenURL)
    }

    private func handleOpenURL(_ url: URL) {
        return
        dismissSplash()
    }

    

    private func dismissSplash() {
        guard isShowingSplash else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            isShowingSplash = false
        }
    }
}
