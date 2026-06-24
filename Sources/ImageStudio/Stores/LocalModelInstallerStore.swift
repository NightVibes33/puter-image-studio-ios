import Foundation

// MARK: - Installer Store

@MainActor
final class LocalModelInstallerStore: ObservableObject {
    @Published private(set) var state: LocalModelInstallState

    private let modelID: String
    private let catalog: LocalModelCatalog
    private var coordinator: LocalModelInstallCoordinator?
    private var installTask: Task<Void, Never>?
    private var retryCount = 0
    private static let maxRetries = 3

    // MARK: - Init

    init(modelID: String = "local-sdxl-base") {
        self.modelID = modelID
        let loaded = (try? LocalModelCatalog.bundled()) ?? LocalModelCatalog(schemaVersion: 1, models: [])
        self.catalog = loaded

        // Determine initial state — never crash even if catalog is empty
        if let entry = loaded.entry(id: modelID) {
            let store = LocalManifestModelStore(entry: entry)
            if let version = store.installedVersion() {
                self.state = .installed(version: version)
            } else {
                // Check if an install was interrupted (resume data exists)
                let resumeURL = LocalModelDownloadManager.resumeDataURL(modelID: modelID)
                if FileManager.default.fileExists(atPath: resumeURL.path) {
                    // Resume data present but install not complete — treat as missing
                    // so the user can tap Retry and we pick up the download
                    self.state = .missing
                } else {
                    self.state = .missing
                }
            }
        } else {
            self.state = .missing
        }
    }

    // MARK: - Public API

    var modelEntry: LocalModelEntry? { catalog.entry(id: modelID) }

    var hasResumeData: Bool {
        FileManager.default.fileExists(
            atPath: LocalModelDownloadManager.resumeDataURL(modelID: modelID).path
        )
    }

    /// Returns nil if there is enough space, or the required bytes if not.
    var insufficientSpaceBytes: Int64? {
        guard let entry = catalog.entry(id: modelID) else { return nil }
        let required = entry.requiredBytes
        guard let available = availableDiskBytes() else { return nil }
        // Require at least 2x the compressed size as working room (download + extract)
        let needed = Int64(Double(required) * 2.2)
        return available < needed ? needed : nil
    }

    func refresh() {
        guard !state.isBusy else { return }
        if let entry = catalog.entry(id: modelID) {
            let store = LocalManifestModelStore(entry: entry)
            if let version = store.installedVersion() {
                state = .installed(version: version)
            } else {
                state = .missing
            }
        } else {
            state = .missing
        }
    }

    func install() {
        guard !state.isBusy else { return }
        guard let entry = catalog.entry(id: modelID) else {
            state = .failed(.unknownModelID(modelID))
            return
        }
        // Disk space pre-check — fail fast with a clear error rather than crashing mid-download
        if let needed = insufficientSpaceBytes {
            let gb = String(format: "%.1f", Double(needed) / 1_000_000_000)
            state = .failed(.insufficientDiskSpace(requiredBytes: needed))
            return
        }
        retryCount = 0
        startInstall(entry: entry)
    }

    func cancel() {
        installTask?.cancel()
        installTask = nil
        coordinator?.cancel()
        coordinator = nil
        Task { @MainActor in self.refresh() }
    }

    func deleteInstall() {
        guard !state.isBusy, let entry = catalog.entry(id: modelID) else { return }
        let store = LocalManifestModelStore(entry: entry)
        store.deleteInstall()
        try? FileManager.default.removeItem(
            at: LocalModelDownloadManager.resumeDataURL(modelID: modelID)
        )
        state = .missing
    }

    // MARK: - Private

    private func startInstall(entry: LocalModelEntry) {
        installTask?.cancel()
        let coord = LocalModelInstallCoordinator(entry: entry)
        coordinator = coord

        coord.onProgress = { [weak self] newState in
            self?.state = newState
        }
        coord.onComplete = { [weak self] in
            guard let self else { return }
            self.retryCount = 0
            let version = LocalManifestModelStore(entry: entry).installedVersion() ?? entry.version
            self.state = .installed(version: version)
        }
        coord.onError = { [weak self] error in
            guard let self else { return }
            // Don't retry disk-space or non-retryable errors
            if error.isRetryable && self.retryCount < Self.maxRetries {
                self.retryCount += 1
                let backoff = pow(2.0, Double(self.retryCount))
                self.installTask = Task {
                    try? await Task.sleep(for: .seconds(backoff))
                    guard !Task.isCancelled else { return }
                    await coord.install()
                }
            } else {
                self.coordinator = nil
                self.state = .failed(error)
            }
        }

        installTask = Task { await coord.install() }
    }

    // MARK: - Helpers

    private func availableDiskBytes() -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ) else { return nil }
        return (attrs[.systemFreeSize] as? NSNumber)?.int64Value
    }
}
