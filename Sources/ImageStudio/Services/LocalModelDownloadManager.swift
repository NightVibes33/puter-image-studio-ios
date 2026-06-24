import Foundation
import CryptoKit

// MARK: - Progress snapshot

struct DownloadProgressSnapshot: Sendable {
    var bytesWritten: Int64
    var bytesExpected: Int64
    var speedBytesPerSec: Double
    var etaSeconds: Double?

    var fraction: Double {
        bytesExpected > 0 ? Double(bytesWritten) / Double(bytesExpected) : 0
    }
}

// MARK: - Download manager

/// Handles a single resumable background download for a local model archive.
/// Uses a stable per-model session identifier so relaunch can reconnect to an
/// in-flight download. Resume data is persisted as a file, not in UserDefaults.
final class LocalModelDownloadManager: NSObject {
    // MARK: - Static helpers

    static func resumeDataURL(modelID: String) -> URL {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first ?? FileManager.default.temporaryDirectory
        return support
            .appendingPathComponent("LocalModels", isDirectory: true)
            .appendingPathComponent("\(modelID)-resume.dat")
    }

    static func sessionIdentifier(modelID: String) -> String {
        "com.nightvibes.imagestudio.modeldownload.\(modelID)"
    }

    // MARK: - Properties

    private let modelID: String
    private let archiveURLs: [URL]   // primary + mirrors
    private let expectedSHA256: String?
    private let fileManager: FileManager

    private var backgroundSession: URLSession?
    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<URL, Error>?
    private var pendingDestination: URL?

    private var bytesWritten: Int64 = 0
    private var bytesExpected: Int64 = 0
    private var speedSamples: [(date: Date, bytes: Int64)] = []
    private var currentMirrorIndex = 0

    var onProgress: ((DownloadProgressSnapshot) -> Void)?
    var onStateChange: ((LocalModelInstallPhase) -> Void)?

    // MARK: - Init

    init(
        modelID: String,
        archiveURLs: [URL],
        expectedSHA256: String?,
        fileManager: FileManager = .default
    ) {
        precondition(!archiveURLs.isEmpty, "Must provide at least one archive URL")
        self.modelID = modelID
        self.archiveURLs = archiveURLs
        self.expectedSHA256 = expectedSHA256
        self.fileManager = fileManager
    }

    // MARK: - Public API

    /// Downloads the archive to `directory`, verifies checksum if `expectedSHA256` is set.
    /// Returns the local URL of the verified archive file.
    func download(to directory: URL) async throws -> URL {
        let destURL = directory.appendingPathComponent("model-\(modelID).zip")
        pendingDestination = destURL
        bytesWritten = 0
        bytesExpected = 0
        speedSamples = []
        currentMirrorIndex = 0

        let sessionID = Self.sessionIdentifier(modelID: modelID)
        let config = URLSessionConfiguration.background(withIdentifier: sessionID)
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        backgroundSession = session

        onStateChange?(.downloading)

        let downloadedURL: URL = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                self.continuation = cont
                let task: URLSessionDownloadTask
                let resumeDataURL = Self.resumeDataURL(modelID: modelID)
                if let data = try? Data(contentsOf: resumeDataURL) {
                    task = session.downloadTask(withResumeData: data)
                    try? fileManager.removeItem(at: resumeDataURL)
                } else {
                    task = session.downloadTask(with: archiveURLs[currentMirrorIndex])
                }
                self.downloadTask = task
                task.resume()
            }
        } onCancel: { [weak self] in
            self?.saveResumeDataAndCancel()
        }

        // Verify checksum
        if let expected = expectedSHA256, !expected.isEmpty {
            onStateChange?(.verifyingArchive)
            try verifyChecksum(at: downloadedURL, expected: expected)
        }

        return downloadedURL
    }

    func cancel() {
        saveResumeDataAndCancel()
    }

    // MARK: - Private

    private func saveResumeDataAndCancel() {
        downloadTask?.cancel(cancelingByProducingResumeData: { [weak self] data in
            guard let self, let data else { return }
            let url = Self.resumeDataURL(modelID: self.modelID)
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url)
        })
        downloadTask = nil
        backgroundSession?.invalidateAndCancel()
        backgroundSession = nil
    }

    private func verifyChecksum(at url: URL, expected: String) throws {
        let data = try Data(contentsOf: url)
        let digest = SHA256.hash(data: data)
        let actual = digest.map { String(format: "%02x", $0) }.joined()
        guard actual.lowercased() == expected.lowercased() else {
            throw LocalModelInstallError.checksumMismatch(expected: expected, actual: actual)
        }
    }

    private func updateSpeed(totalBytes: Int64) {
        let now = Date()
        speedSamples.append((now, totalBytes))
        // Keep a rolling 10-second window with a minimum 3-second floor
        speedSamples = speedSamples.filter { now.timeIntervalSince($0.date) <= 10 }
        guard speedSamples.count >= 2 else { return }
        guard let first = speedSamples.first else { return }
        let elapsed = now.timeIntervalSince(first.date)
        guard elapsed >= 3 else { return }
        let bytesDelta = max(0, totalBytes - first.bytes)
        let speed = Double(bytesDelta) / elapsed
        let snapshot = DownloadProgressSnapshot(
            bytesWritten: totalBytes,
            bytesExpected: bytesExpected,
            speedBytesPerSec: speed,
            etaSeconds: speed > 0 && bytesExpected > 0
                ? Double(bytesExpected - totalBytes) / speed
                : nil
        )
        onProgress?(snapshot)
    }
}

// MARK: - URLSessionDownloadDelegate

extension LocalModelDownloadManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let dest = pendingDestination else {
            continuation?.resume(throwing: LocalModelInstallError.downloadFailed(reason: "Missing destination"))
            continuation = nil
            return
        }
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            continuation?.resume(returning: dest)
            continuation = nil
        } catch {
            continuation?.resume(throwing: LocalModelInstallError.downloadFailed(reason: error.localizedDescription))
            continuation = nil
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWrittenDelta: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        bytesWritten = totalBytesWritten
        if totalBytesExpectedToWrite > 0 { bytesExpected = totalBytesExpectedToWrite }
        updateSpeed(totalBytes: totalBytesWritten)
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        if let data = nsError.userInfo[NSURLSessionDownloadTaskResumeData] as? Data {
            let url = LocalModelDownloadManager.resumeDataURL(modelID: modelID)
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? data.write(to: url)
        }
        let mapped: LocalModelInstallError
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotConnectToHost:
                mapped = .networkUnavailable
            case .timedOut:
                mapped = .timedOut
            case .cancelled:
                return
            default:
                // Try next mirror
                currentMirrorIndex += 1
                if currentMirrorIndex < archiveURLs.count,
                   let session = backgroundSession {
                    let nextTask = session.downloadTask(with: archiveURLs[currentMirrorIndex])
                    downloadTask.resume()
                    _ = nextTask
                    return
                }
                mapped = .downloadFailed(reason: urlError.localizedDescription)
            }
        } else {
            mapped = .downloadFailed(reason: error.localizedDescription)
        }
        continuation?.resume(throwing: mapped)
        continuation = nil
    }

    nonisolated func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        guard continuation != nil else { return }
        continuation?.resume(throwing: LocalModelInstallError.downloadFailed(
            reason: error?.localizedDescription ?? "Session invalidated"
        ))
        continuation = nil
    }
}

extension LocalModelDownloadManager: @unchecked Sendable {}
