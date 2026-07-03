import Foundation
import SwiftUI

@MainActor
final class AppEnvironment: ObservableObject {
    let imageGenerator: any LocalImageGenerator & Sendable
    let imageDownloadClient: ImageDownloadClient
    let photoLibrarySaver: PhotoLibrarySaver
    let historyStore: GenerationHistoryStore
    let localModelInstallerStore: LocalModelInstallerStore

    init(
        imageGenerator: any LocalImageGenerator & Sendable,
        imageDownloadClient: ImageDownloadClient,
        photoLibrarySaver: PhotoLibrarySaver,
        historyStore: GenerationHistoryStore,
        localModelInstallerStore: LocalModelInstallerStore
    ) {
        self.imageGenerator = imageGenerator
        self.imageDownloadClient = imageDownloadClient
        self.photoLibrarySaver = photoLibrarySaver
        self.historyStore = historyStore
        self.localModelInstallerStore = localModelInstallerStore
    }

    static func live() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let installerStore = LocalModelInstallerStore(modelID: "local-sdxl-base")

        let localEntry = (try? LocalModelCatalog.bundled())?.entry(id: "local-sdxl-base")
            ?? LocalModelEntry(
                id: "local-sdxl-base",
                version: "1.0.0",
                title: "SDXL Base",
                subtitle: "On-device · No internet after install",
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

        let localGenerator = LocalStableDiffusionImageGenerationClient(
            entry: localEntry,
            imageDownloadClient: imageDownloadClient
        )

        return AppEnvironment(
            imageGenerator: localGenerator,
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            localModelInstallerStore: installerStore
        )
    }

    static func preview() -> AppEnvironment {
        let imageDownloadClient = ImageDownloadClient()
        let historyStore = GenerationHistoryStore(imageDownloadClient: imageDownloadClient)
        let installerStore = LocalModelInstallerStore(modelID: "local-sdxl-base")
        return AppEnvironment(
            imageGenerator: MockImageGenerationClient(imageDownloadClient: imageDownloadClient),
            imageDownloadClient: imageDownloadClient,
            photoLibrarySaver: PhotoLibrarySaver(),
            historyStore: historyStore,
            localModelInstallerStore: installerStore
        )
    }
}
