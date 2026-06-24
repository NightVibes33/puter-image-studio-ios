import Foundation

// MARK: - Installer Store (thin UI layer over LocalModelInstallCoordinator)

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
        // Load catalog; fall back to .missing on error rather than crashing
        let loaded = (try? LocalModelCatalog.bundled()) ?? LocalModelCatalog(schemaVersion: 1, models: [])
        self.catalog = loaded
        // Determine initial state
        if let entry = loaded.entry(id: modelID) {
            let store = LocalManifestModelStore(entry: entry)
            if let version = store.installedVersion() {
                self.state = .installed(version: version)
            } else {
                self.state = .missing
            }
        } else {
            self.state = .missing
        }
    }

    // MARK: - Public API

    var modelEntry: LocalModelEntry? { catalog.entry(id: modelID) }

    var hasResumeData: Bool {
        let url = LocalModelDownloadManager.resumeDataURL(modelID: modelID)
        return FileManager.default.fileExists(atPath: url.path)
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
        // Also clear any leftover resume data
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
            if let version = LocalManifestModelStore(entry: entry).installedVersion() {
                self.state = .installed(version: version)
            } else {
                self.state = .installed(version: entry.version)
            }
        }
        coord.onError = { [weak self] error in
            guard let self else { return }
            if error.isRetryable && self.retryCount < Self.maxRetries {
                self.retryCount += 1
                let backoff = pow(2.0, Double(self.retryCount))
                self.state = .active(
                    phase: .downloading,
                    progress: 0,
                    overallProgress: 0,
                    speedBytesPerSec: 0,
                    etaSeconds: backoff
                )
                self.installTask = Task {
                    try? await Task.sleep(for: .seconds(backoff))
                    guard !Task.isCancelled else { return }
                    await coord.install()
                }
            } else {
                self.state = .failed(error)
            }
        }

        installTask = Task {
            await coord.install()
        }
    }
}
