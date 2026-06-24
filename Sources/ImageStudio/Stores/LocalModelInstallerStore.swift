import Foundation
import ZIPFoundation

// MARK: - State

enum LocalModelInstallPhase: Equatable, Sendable {
    case download
    case unzip
    case move
}

enum LocalModelInstallState: Equatable, Sendable {
    case missing
    case active(phase: LocalModelInstallPhase, progress: Double, speedBytesPerSec: Double, etaSeconds: Double?)
    case installed
    case failed(String)

    // Convenience shims kept for SettingsView compatibility
    var isDownloading: Bool {
        if case .active(let p, _, _, _) = self { return p == .download }
        return false
    }
    var isUnpacking: Bool {
        if case .active(let p, _, _, _) = self { return p == .unzip || p == .move }
        return false
    }
    var isBusy: Bool {
        if case .active = self { return true }
        return false
    }
    var progress: Double {
        if case .active(_, let p, _, _) = self { return p }
        return 0
    }
    var speedBytesPerSec: Double {
        if case .active(_, _, let s, _) = self { return s }
        return 0
    }
    var etaSeconds: Double? {
        if case .active(_, _, _, let e) = self { return e }
        return nil
    }
}

// MARK: - Installer

@MainActor
final class LocalModelInstallerStore: NSObject, ObservableObject {
    static let requiredFreeBytes: Int64 = 10 * 1024 * 1024 * 1024
    private static let maxRetries = 3
    private static let resumeDataKey = "localModelResumeData"

    @Published private(set) var state: LocalModelInstallState

    private let modelStore: LocalStableDiffusionModelStore
    private let fileManager: FileManager
    private var installTask: Task<Void, Never>?

    // Download progress tracking
    private var downloadContinuation: CheckedContinuation<URL, Error>?
    private var backgroundSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var bytesWritten: Int64 = 0
    private var bytesExpected: Int64 = 0
    private var speedSamples: [(date: Date, bytes: Int64)] = []
    private var currentSpeed: Double = 0
    private var currentETA: Double? = nil
    private var retryCount = 0

    init(
        modelStore: LocalStableDiffusionModelStore = LocalStableDiffusionModelStore(),
        fileManager: FileManager = .default
    ) {
        self.modelStore = modelStore
        self.fileManager = fileManager
        self.state = modelStore.isInstalled() ? .installed : .missing
        super.init()
    }

    func refresh() {
        guard !state.isBusy else { return }
        state = modelStore.isInstalled() ? .installed : .missing
    }

    func install() {
        guard !state.isBusy else { return }
        retryCount = 0
        startInstallTask()
    }

    func cancel() {
        installTask?.cancel()
        installTask = nil
        downloadTask?.cancel(cancelingByProducingResumeData: { [weak self] data in
            if let data { UserDefaults.standard.set(data, forKey: Self.resumeDataKey) }
        })
        downloadTask = nil
        backgroundSession?.invalidateAndCancel()
        backgroundSession = nil
        speedSamples = []
        refresh()
    }

    // MARK: - Private

    private func startInstallTask() {
        installTask?.cancel()
        installTask = Task {
            do {
                try await downloadAndInstall()
                state = .installed
                UserDefaults.standard.removeObject(forKey: Self.resumeDataKey)
            } catch is CancellationError {
                state = modelStore.isInstalled() ? .installed : .missing
            } catch let error as GenerationError {
                await handleError(error)
            } catch {
                await handleError(.server(error.localizedDescription))
            }
        }
    }

    private func handleError(_ error: GenerationError) async {
        let isRetryable: Bool
        switch error {
        case .networkUnavailable, .requestTimedOut, .downloadFailed:
            isRetryable = true
        default:
            isRetryable = false
        }
        if isRetryable && retryCount < Self.maxRetries {
            retryCount += 1
            let backoff = pow(2.0, Double(retryCount))
            state = .active(phase: .download,
                            progress: 0,
                            speedBytesPerSec: 0,
                            etaSeconds: backoff)
            try? await Task.sleep(nanoseconds: UInt64(backoff * 1_000_000_000))
            guard !Task.isCancelled else { return }
            startInstallTask()
        } else {
            state = .failed(userFacingMessage(for: error))
        }
    }

    private func userFacingMessage(for error: GenerationError) -> String {
        switch error {
        case .networkUnavailable:
            return "No internet connection. Check your network and try again."
        case .requestTimedOut:
            return "Download timed out. Make sure you have a stable Wi-Fi connection."
        case .localModelStorageTooLow(let msg):
            return msg
        case .server(let msg):
            return msg
        case .downloadFailed:
            if retryCount >= Self.maxRetries {
                return "Download failed after \(Self.maxRetries) attempts. Try again later."
            }
            return "Download failed. Retrying\u2026"
        default:
            return error.localizedDescription
        }
    }

    private func downloadAndInstall() async throws {
        guard let targetURL = modelStore.applicationSupportResourceURL() else {
            throw GenerationError.localModelMissing
        }
        let parentURL = targetURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: parentURL, withIntermediateDirectories: true)
        try checkAvailableStorage(at: parentURL)

        // ── 1. Download with progress ──────────────────────────────────────
        let archiveURL = try await downloadWithProgress(to: parentURL)
        try Task.checkCancellation()

        // ── 2. Unzip with progress ─────────────────────────────────────────
        let extractedURL = parentURL.appendingPathComponent(".extracted-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: extractedURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: extractedURL) }

        try await unzipWithProgress(archive: archiveURL, destination: extractedURL)
        try? fileManager.removeItem(at: archiveURL)
        try Task.checkCancellation()

        // ── 3. Atomic move ─────────────────────────────────────────────────
        await MainActor.run {
            state = .active(phase: .move, progress: 1.0, speedBytesPerSec: 0, etaSeconds: nil)
        }
        let expectedNested = extractedURL.appendingPathComponent(LocalStableDiffusionModelStore.modelFolderName)
        let sourceURL = fileManager.fileExists(atPath: expectedNested.path) ? expectedNested : extractedURL
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: sourceURL, to: targetURL)
    }

    // MARK: - Download

    private func downloadWithProgress(to directory: URL) async throws -> URL {
        state = .active(phase: .download, progress: 0, speedBytesPerSec: 0, etaSeconds: nil)
        bytesWritten = 0
        bytesExpected = 0
        speedSamples = []

        let config = URLSessionConfiguration.background(withIdentifier:
            "com.nightvibes.imagestudio.modeldownload.\(UUID().uuidString)")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        backgroundSession = session

        let destinationURL = directory.appendingPathComponent("model-\(UUID().uuidString).zip")

        let task: URLSessionDownloadTask
        if let resumeData = UserDefaults.standard.data(forKey: Self.resumeDataKey) {
            task = session.downloadTask(withResumeData: resumeData)
            UserDefaults.standard.removeObject(forKey: Self.resumeDataKey)
        } else {
            task = session.downloadTask(with: LocalStableDiffusionModelStore.downloadURL)
        }
        downloadTask = task

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.downloadContinuation = continuation
                self._pendingDestination = destinationURL
                task.resume()
            }
        } onCancel: { [weak self] in
            self?.downloadTask?.cancel(cancelingByProducingResumeData: { data in
                if let data { UserDefaults.standard.set(data, forKey: Self.resumeDataKey) }
            })
        }
    }

    // Stored so the URLSession delegate (off-MainActor) can move the file
    nonisolated(unsafe) private var _pendingDestination: URL?

    // MARK: - Unzip

    private func unzipWithProgress(archive: URL, destination: URL) async throws {
        await MainActor.run {
            state = .active(phase: .unzip, progress: 0, speedBytesPerSec: 0, etaSeconds: nil)
        }
        // Run unzip on a background thread and update progress periodically
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            Task.detached(priority: .userInitiated) {
                do {
                    let fm = FileManager.default
                    // ZIPFoundation 0.9.x exposes `totalUnitCount` via Progress if requested
                    let progress = Progress(totalUnitCount: 100)
                    let obs = progress.observe(\.completedUnitCount, options: [.new]) { [weak self] p, _ in
                        guard let self else { return }
                        let fraction = Double(p.completedUnitCount) / Double(max(1, p.totalUnitCount))
                        Task { @MainActor in
                            self.state = .active(phase: .unzip, progress: fraction,
                                                 speedBytesPerSec: 0, etaSeconds: nil)
                        }
                    }
                    try fm.unzipItem(at: archive, to: destination, progress: progress)
                    obs.invalidate()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Speed + ETA

    private func updateSpeed(totalBytes: Int64) {
        let now = Date()
        speedSamples.append((date: now, bytes: totalBytes))
        if speedSamples.count > 6 { speedSamples.removeFirst() }
        guard speedSamples.count >= 2,
              let first = speedSamples.first else { return }
        let elapsed = now.timeIntervalSince(first.date)
        guard elapsed > 0 else { return }
        let bytesDelta = totalBytes - first.bytes
        currentSpeed = Double(bytesDelta) / elapsed
        if bytesExpected > 0 && currentSpeed > 0 {
            let remaining = Double(bytesExpected - totalBytes)
            currentETA = remaining / currentSpeed
        } else {
            currentETA = nil
        }
    }

    // MARK: - Storage check

    private func checkAvailableStorage(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        if available < Self.requiredFreeBytes {
            let gb = String(format: "%.1f GB", Double(available) / 1_073_741_824)
            throw GenerationError.localModelStorageTooLow(
                "Not enough storage. \(gb) free, 10 GB required."
            )
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension LocalModelInstallerStore: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let destination = _pendingDestination else {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: GenerationError.downloadFailed)
                self.downloadContinuation = nil
            }
            return
        }
        do {
            try FileManager.default.moveItem(at: location, to: destination)
            Task { @MainActor in
                self.downloadContinuation?.resume(returning: destination)
                self.downloadContinuation = nil
            }
        } catch {
            Task { @MainActor in
                self.downloadContinuation?.resume(throwing: GenerationError.downloadFailed)
                self.downloadContinuation = nil
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        Task { @MainActor in
            self.bytesWritten = totalBytesWritten
            if totalBytesExpectedToWrite > 0 {
                self.bytesExpected = totalBytesExpectedToWrite
            }
            self.updateSpeed(totalBytes: totalBytesWritten)
            let progress = totalBytesExpectedToWrite > 0
                ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
                : 0
            self.state = .active(
                phase: .download,
                progress: progress,
                speedBytesPerSec: self.currentSpeed,
                etaSeconds: self.currentETA
            )
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        let resumeData = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data
        if let resumeData {
            UserDefaults.standard.set(resumeData, forKey: LocalModelInstallerStore.resumeDataKey)
        }
        let mapped: GenerationError
        let urlError = error as? URLError
        switch urlError?.code {
        case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
            mapped = .networkUnavailable
        case .timedOut:
            mapped = .requestTimedOut
        case .cancelled:
            return // handled by cancel()
        default:
            mapped = .downloadFailed
        }
        Task { @MainActor in
            self.downloadContinuation?.resume(throwing: mapped)
            self.downloadContinuation = nil
        }
    }
}
