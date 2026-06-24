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
        guard url.scheme == "imagestudio", url.host == "puter-auth" else { return }
        let values = authValues(from: url)
        guard let token = values["token"], !token.isEmpty else { return }
        settingsStore.connectPuter(token: token, username: values["username"])
        dismissSplash()
    }

    private func authValues(from url: URL) -> [String: String] {
        var values: [String: String] = [:]
        if let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems {
            for item in items {
                values[item.name] = item.value
            }
        }
        if let fragment = url.fragment {
            let fragmentItems = fragment.split(separator: "&")
            for item in fragmentItems {
                let parts = item.split(separator: "=", maxSplits: 1).map(String.init)
                guard parts.count == 2 else { continue }
                values[parts[0]] = parts[1].removingPercentEncoding ?? parts[1]
            }
        }
        return values
    }

    private func dismissSplash() {
        guard isShowingSplash else { return }
        withAnimation(.easeInOut(duration: 0.42)) {
            isShowingSplash = false
        }
    }
}
