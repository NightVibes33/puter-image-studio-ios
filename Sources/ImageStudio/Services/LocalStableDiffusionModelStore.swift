import Foundation

struct LocalStableDiffusionModelStore {
    static let backendModelID = "local-coreml-sdxl"
    static let modelFolderName = "coreml-stable-diffusion-xl-base-ios_split_einsum_compiled"
    static let downloadURL = URL(string: "https://huggingface.co/apple/coreml-stable-diffusion-xl-base-ios/resolve/main/coreml-stable-diffusion-xl-base-ios_split_einsum_compiled.zip")!

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var expectedFreeSpaceDescription: String {
        "10 GB"
    }

    func installedResourceURL() -> URL? {
        let candidates = [bundledResourceURL(), applicationSupportResourceURL()].compactMap { $0 }
        return candidates.first { isUsableResourceDirectory($0) }
    }

    func applicationSupportResourceURL() -> URL? {
        guard let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        return supportURL
            .appendingPathComponent("LocalModels", isDirectory: true)
            .appendingPathComponent(Self.modelFolderName, isDirectory: true)
    }

    func bundledResourceURL() -> URL? {
        Bundle.main.url(forResource: Self.modelFolderName, withExtension: nil)
    }

    func isInstalled() -> Bool {
        installedResourceURL() != nil
    }

    func isUsableResourceDirectory(_ url: URL) -> Bool {
        let requiredNames = [
            "VAEDecoder.mlmodelc",
            "vocab.json"
        ]
        let hasRequired = requiredNames.allSatisfy { name in
            fileManager.fileExists(atPath: url.appendingPathComponent(name).path)
        }
        let hasTokenizerMerge = fileManager.fileExists(atPath: url.appendingPathComponent("merges.txt").path) ||
            fileManager.fileExists(atPath: url.appendingPathComponent("merges.text").path)
        let hasUnet = fileManager.fileExists(atPath: url.appendingPathComponent("Unet.mlmodelc").path) ||
            (fileManager.fileExists(atPath: url.appendingPathComponent("UnetChunk1.mlmodelc").path) &&
             fileManager.fileExists(atPath: url.appendingPathComponent("UnetChunk2.mlmodelc").path))
        let hasTextEncoder = fileManager.fileExists(atPath: url.appendingPathComponent("TextEncoder.mlmodelc").path) ||
            fileManager.fileExists(atPath: url.appendingPathComponent("TextEncoder2.mlmodelc").path)

        return hasRequired && hasTokenizerMerge && hasUnet && hasTextEncoder
    }
}
