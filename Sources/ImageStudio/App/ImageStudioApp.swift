import SwiftUI

@main
struct ImageStudioApp: App {
    @StateObject private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(environment)
                .environmentObject(environment.historyStore)
                .environmentObject(environment.settingsStore)
                .environmentObject(environment.localModelInstallerStore)
        }
    }
}
