import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
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
        let installerStore = LocalModelInstallerStore(modelID: "local-sdxl-base")

        // Resolve the manifest entry for the primary local model
        let localEntry = (try? LocalModelCatalog.bundled())?.entry(id: "local-sdxl-base")
            ?? LocalModelEntry(
                id: "local-sdxl-base",
                version: "1.0.0",
                title: "SDXL Base",
                subtitle: "On-device · No credits",
                archiveURL: URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip")!,
                sha256: "",
                installFolderName: "coreml-stable-diffusion-xl-base-ios_split_einsum_compiled",
                requiredFreeBytes: 10_737_418_240,
                requiredFiles: [
                    "VAEDecoder.mlmodelc", "VAEEncoder.mlmodelc",
                    "TextEncoder.mlmodelc", "TextEncoder2.mlmodelc",
                    "vocab.json", "merges.txt"
                ],
                minimumChip: .a14,
                minimumRAMBytes: 6_442_450_944,
                mirrorURLs: []
            )

        let localSDClient = LocalStableDiffusionImageGenerationClient(
            entry: localEntry,
            imageDownloadClient: imageDownloadClient
        )

        return AppEnvironment(
            imageClient: localSDClient,
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore,
            localModelInstallerStore: installerStore
        )
    }

    static func preview() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        // Use an ephemeral UserDefaults suite so previews don't touch real storage
        let previewDefaults = UserDefaults(suiteName: "preview-\(UUID().uuidString)") ?? .standard
        let settingsStore = AppSettingsStore(userDefaults: previewDefaults)
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let installerStore = LocalModelInstallerStore(modelID: "local-sdxl-base")
        return AppEnvironment(
            imageClient: MockImageGenerationClient(imageDownloadClient: imageDownloadClient),
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            settingsStore: settingsStore,
            localModelInstallerStore: installerStore
        )
    }
}
