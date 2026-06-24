import Foundation
import ZIPFoundation

// StableDiffusion SPM package is intentionally excluded from the CI build.
// ZIPFoundation is a real SPM dependency — import it directly, not via canImport.
// All StableDiffusion usage remains behind #if canImport(StableDiffusion) in the generation client.

enum LocalModelInstallState: Equatable, Sendable {
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

        await MainActor.run { self.state = .unpacking }
        let archiveURL = stagingURL.appendingPathComponent("model.zip")
        try fileManager.moveItem(at: downloadedArchiveURL, to: archiveURL)

        let extractedURL = stagingURL.appendingPathComponent("extracted", isDirectory: true)
        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        try fileManager.unzipItem(at: archiveURL, to: extractedURL)
        try Task.checkCancellation()

        // Find the compiled model folder inside the zip
        let expectedNested = extractedURL
            .appendingPathComponent(LocalStableDiffusionModelStore.modelFolderName, isDirectory: true)
        let sourceURL: URL
        if fileManager.fileExists(atPath: expectedNested.path) {
            sourceURL = expectedNested
        } else {
            // Zip may place contents at root level
            sourceURL = extractedURL
        }

        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: sourceURL, to: targetURL)
    }

    private func checkAvailableStorage(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        if available < Self.requiredFreeBytes {
            let gb = String(format: "%.1f GB", Double(available) / 1_073_741_824)
            throw GenerationError.localModelStorageTooLow(
                "Not enough storage to install the local model. \(gb) available, 10 GB required."
            )
        }
    }
}
