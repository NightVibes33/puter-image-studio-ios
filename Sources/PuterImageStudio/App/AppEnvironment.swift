import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let imageClient: ImageGenerationClient
    let imageDownloadClient: ImageDownloadClient
    let photoLibrarySaver: PhotoLibrarySaver
    let historyStore: GenerationHistoryStore
    let settingsStore: AppSettingsStore

    init(
        imageClient: ImageGenerationClient,
        imageDownloadClient: ImageDownloadClient,
        photoLibrarySaver: PhotoLibrarySaver,
        historyStore: GenerationHistoryStore,
        settingsStore: AppSettingsStore
    ) {
        self.imageClient = imageClient
        self.imageDownloadClient = imageDownloadClient
        self.photoLibrarySaver = photoLibrarySaver
        self.historyStore = historyStore
        self.settingsStore = settingsStore
    }

    static func live() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let settingsStore = AppSettingsStore()
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let remoteClient: ImageGenerationClient
        if let baseURL = AppEnvironment.imageAPIBaseURL() {
            remoteClient = PuterAPIImageGenerationClient(
                baseURL: baseURL,
                imageDownloadClient: imageDownloadClient
            )
        } else {
            remoteClient = UnavailableImageGenerationClient(error: .invalidEndpoint)
        }
        let localClient = LocalStableDiffusionImageGenerationClient(imageDownloadClient: imageDownloadClient)
        let client = HybridImageGenerationClient(localClient: localClient, remoteClient: remoteClient)

        return AppEnvironment(
            imageClient: client,
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore
        )
    }

    static func preview() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let settingsStore = AppSettingsStore(userDefaults: .standard)
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        return AppEnvironment(
            imageClient: MockImageGenerationClient(imageDownloadClient: imageDownloadClient),
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore
        )
    }

    private static func imageAPIBaseURL() -> URL? {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "IMAGE_API_BASE_URL") as? String,
           let url = validatedBaseURL(rawValue) {
            return url
        }

        #if DEBUG
        return URL(string: "http://127.0.0.1:8787")!
        #else
        return nil
        #endif
    }

    private static func validatedBaseURL(_ rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let unresolvedBuildSettingPrefix = "$" + String(UnicodeScalar(40)!)
        guard !trimmed.isEmpty,
              !trimmed.contains(unresolvedBuildSettingPrefix),
              !trimmed.contains(".example"),
              !trimmed.contains(".invalid"),
              let url = URL(string: trimmed),
              url.scheme == "http" || url.scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }

        return url
    }
}
