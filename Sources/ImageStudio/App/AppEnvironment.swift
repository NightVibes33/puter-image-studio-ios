import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    // Bound to Sendable so Swift 6 is satisfied when imageClient crosses actor boundaries
    let imageClient: any ImageGenerationClient & Sendable
    let imageDownloadClient: ImageDownloadClient
    let photoLibrarySaver: PhotoLibrarySaver
    let historyStore: GenerationHistoryStore
    let settingsStore: AppSettingsStore
    let localModelInstallerStore: LocalModelInstallerStore

    init(
        imageClient: any ImageGenerationClient & Sendable,
        imageDownloadClient: ImageDownloadClient,
        photoLibrarySaver: PhotoLibrarySaver,
        historyStore: GenerationHistoryStore,
        settingsStore: AppSettingsStore,
        localModelInstallerStore: LocalModelInstallerStore
    ) {
        self.imageClient = imageClient
        self.imageDownloadClient = imageDownloadClient
        self.photoLibrarySaver = photoLibrarySaver
        self.historyStore = historyStore
        self.settingsStore = settingsStore
        self.localModelInstallerStore = localModelInstallerStore
    }

    static func live() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let settingsStore = AppSettingsStore()
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let localModelInstallerStore = LocalModelInstallerStore()

        let localClient = LocalStableDiffusionImageGenerationClient(imageDownloadClient: imageDownloadClient)
        let client = LocalImageStudioClient(localClient: localClient)

        return AppEnvironment(
            imageClient: client,
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore,
            localModelInstallerStore: localModelInstallerStore
        )
    }

    static func preview() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let settingsStore = AppSettingsStore(userDefaults: .standard)
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let localModelInstallerStore = LocalModelInstallerStore()
        return AppEnvironment(
            imageClient: MockImageGenerationClient(imageDownloadClient: imageDownloadClient),
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore,
            localModelInstallerStore: localModelInstallerStore
        )
    }
}
