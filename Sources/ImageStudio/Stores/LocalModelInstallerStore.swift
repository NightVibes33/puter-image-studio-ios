import Foundation

// StableDiffusion SPM package is intentionally excluded from the CI build.
// ZIPFoundation is retained for the model download/unzip flow.
// All StableDiffusion usage is behind #if canImport(StableDiffusion) in the generation client.

#if canImport(ZIPFoundation)
import ZIPFoundation
#endif

enum LocalModelInstallState: Equatable {
    case missing
    case downloading
    case unpacking
    case installed
    case failed(String)

    var isBusy: Bool {
        switch self {
        case .downloading, .unpacking:
            return true
        default:
            return false
        }
    }
}

@MainActor
final class LocalModelInstallerStore: ObservableObject {
    static let requiredFreeBytes: Int64 = 10 * 1024 * 1024 * 1024

    @Published private(set) var state: LocalModelInstallState

    private let modelStore: LocalStableDiffusionModelStore
    private let fileManager: FileManager
    private var installTask: Task<Void, Never>?

    init(
        modelStore: LocalStableDiffusionModelStore = LocalStableDiffusionModelStore(),
        fileManager: FileManager = .default
    ) {
        self.modelStore = modelStore
        self.fileManager = fileManager
        self.state = modelStore.isInstalled() ? .installed : .missing
    }

    func refresh() {
        guard !state.isBusy else { return }
        state = modelStore.isInstalled() ? .installed : .missing
    }

    func install() {
        guard !state.isBusy else { return }
        installTask?.cancel()
        installTask = Task {
            do {
                state = .downloading
                try await downloadAndInstall()
                state = .installed
            } catch is CancellationError {
                state = modelStore.isInstalled() ? .installed : .missing
            } catch {
                state = .failed(error.localizedDescription)
            }
        }
    }

    func cancel() {
        installTask?.cancel()
        installTask = nil
        refresh()
    }

    private func downloadAndInstall() async throws {
        #if canImport(ZIPFoundation)
        guard let targetURL = modelStore.applicationSupportResourceURL() else {
            throw GenerationError.localModelMissing
        }
        let parentURL = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try checkAvailableStorage(at: parentURL)

        let stagingURL = parentURL
            .appendingPathComponent(".install-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingURL) }

        let (downloadedArchiveURL, response) = try await URLSession.shared.download(from: LocalStableDiffusionModelStore.downloadURL)
        if let httpResponse = response as? HTTPURLResponse, !(200..<300).contains(httpResponse.statusCode) {
            throw GenerationError.server("Model download failed with HTTP \(httpResponse.statusCode).")
        }
        try Task.checkCancellation()

        await MainActor.run { state = .unpacking }
        let archiveURL = stagingURL.appendingPathComponent("model.zip")
        try fileManager.moveItem(at: downloadedArchiveURL, to: archiveURL)

        let extractedURL = stagingURL.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: archiveURL, to: extractedURL)
        try Task.checkCancellation()

        let sourceURL = try resolvedModelFolder(in: extractedURL)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: sourceURL, to: targetURL)

        guard modelStore.isUsableResourceDirectory(targetURL) else {
            try? fileManager.removeItem(at: targetURL)
            throw GenerationError.localModelMissing
        }
        #else
        throw GenerationError.localEngineUnavailable
        #endif
    }

    private func checkAvailableStorage(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        let generalCapacity = values.volumeAvailableCapacity.map(Int64.init)
        let available = values.volumeAvailableCapacityForImportantUsage ?? generalCapacity ?? 0
        guard available >= Self.requiredFreeBytes else {
            let availableGB = Double(max(available, 0)) / 1_073_741_824
            throw GenerationError.localModelStorageTooLow(
                "Local SDXL needs about 10 GB free. This device currently reports \(String(format: "%.1f", availableGB)) GB available."
            )
        }
    }

    private func resolvedModelFolder(in extractedURL: URL) throws -> URL {
        let expectedURL = extractedURL.appendingPathComponent(LocalStableDiffusionModelStore.modelFolderName, isDirectory: true)
        if modelStore.isUsableResourceDirectory(expectedURL) {
            return expectedURL
        }

        let childURLs = try fileManager.contentsOfDirectory(
            at: extractedURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        if let match = childURLs.first(where: { modelStore.isUsableResourceDirectory($0) }) {
            return match
        }

        for childURL in childURLs {
            let nestedURLs = (try? fileManager.contentsOfDirectory(
                at: childURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            if let match = nestedURLs.first(where: { modelStore.isUsableResourceDirectory($0) }) {
                return match
            }
        }

        throw GenerationError.localModelMissing
    }
}
