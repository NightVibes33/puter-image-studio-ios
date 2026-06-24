import Foundation
import ZIPFoundation

// Phase weight table — used to compute overall 0–1 progress across all phases
private let phaseWeights: [LocalModelInstallPhase: Double] = [
    .downloading:      0.70,
    .verifyingArchive: 0.02,
    .extracting:       0.20,
    .validatingFiles:  0.04,
    .activating:       0.04
]

/// Orchestrates the full download → verify → extract → validate → activate pipeline
/// for a single `LocalModelEntry`. Communicates progress via `onProgress`.
@MainActor
final class LocalModelInstallCoordinator {
    private let entry: LocalModelEntry
    private let fileManager: FileManager
    private var downloadManager: LocalModelDownloadManager?

    var onProgress: ((LocalModelInstallState) -> Void)?
    var onComplete: (() -> Void)?
    var onError: ((LocalModelInstallError) -> Void)?

    init(entry: LocalModelEntry, fileManager: FileManager = .default) {
        self.entry = entry
        self.fileManager = fileManager
    }

    // MARK: - Install

    func install() async {
        let allURLs = [entry.archiveURL] + entry.mirrorURLs
        let dm = LocalModelDownloadManager(
            modelID: entry.id,
            archiveURLs: allURLs,
            expectedSHA256: entry.sha256.isEmpty ? nil : entry.sha256
        )
        downloadManager = dm

        dm.onProgress = { [weak self] snapshot in
            guard let self else { return }
            let overall = snapshot.fraction * (phaseWeights[.downloading] ?? 0.70)
            self.onProgress?(.active(
                phase: .downloading,
                progress: snapshot.fraction,
                overallProgress: overall,
                speedBytesPerSec: snapshot.speedBytesPerSec,
                etaSeconds: snapshot.etaSeconds
            ))
        }

        do {
            // 1 — Check storage
            let installParent = try installParentURL()
            try checkStorage(at: installParent)

            // 2 — Download (+ checksum inside download manager)
            emit(phase: .downloading, phaseProgress: 0, speed: 0, eta: nil)
            let archiveURL = try await dm.download(to: installParent)

            // 3 — Verify archive (phase announced by download manager; emit here for overall progress)
            emit(phase: .verifyingArchive, phaseProgress: 1, speed: 0, eta: nil)
            try Task.checkCancellation()

            // 4 — Extract
            let extractURL = installParent.appendingPathComponent(".extract-\(entry.id)-\(UUID().uuidString)", isDirectory: true)
            try fileManager.createDirectory(at: extractURL, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: extractURL) }
            try await extract(archive: archiveURL, to: extractURL)
            try? fileManager.removeItem(at: archiveURL)
            try Task.checkCancellation()

            // 5 — Validate
            emit(phase: .validatingFiles, phaseProgress: 0, speed: 0, eta: nil)
            let sourceURL = resolveSourceURL(in: extractURL)
            try validate(at: sourceURL)

            // 6 — Activate (versioned swap)
            emit(phase: .activating, phaseProgress: 0, speed: 0, eta: nil)
            try activate(source: sourceURL, parent: installParent)

            onComplete?()
        } catch is CancellationError {
            onError?(.cancelled)
        } catch let e as LocalModelInstallError {
            onError?(e)
        } catch {
            onError?(.activationFailed(reason: error.localizedDescription))
        }
    }

    func cancel() {
        downloadManager?.cancel()
    }

    // MARK: - Steps

    private func installParentURL() throws -> URL {
        guard let support = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw LocalModelInstallError.activationFailed(reason: "Cannot resolve ApplicationSupport directory")
        }
        let parent = support.appendingPathComponent("LocalModels", isDirectory: true)
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        return parent
    }

    private func checkStorage(at url: URL) throws {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        let available = values.volumeAvailableCapacityForImportantUsage ?? 0
        if available < entry.requiredFreeBytes {
            throw LocalModelInstallError.storageTooLow(
                available: available,
                required: entry.requiredFreeBytes
            )
        }
    }

    private func extract(archive: URL, to destination: URL) async throws {
        emit(phase: .extracting, phaseProgress: 0, speed: 0, eta: nil)
        let progress = Progress(totalUnitCount: 100)
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            Task.detached(priority: .userInitiated) { [weak self] in
                let obs = progress.observe(\.completedUnitCount, options: [.new]) { [weak self] p, _ in
                    guard let self else { return }
                    let fraction = Double(p.completedUnitCount) / Double(max(1, p.totalUnitCount))
                    let phaseStart = phaseWeights[.downloading]! + phaseWeights[.verifyingArchive]!
                    let overall = phaseStart + fraction * (phaseWeights[.extracting] ?? 0.20)
                    Task { @MainActor in
                        self.onProgress?(.active(
                            phase: .extracting,
                            progress: fraction,
                            overallProgress: overall,
                            speedBytesPerSec: 0,
                            etaSeconds: nil
                        ))
                    }
                }
                defer { obs.invalidate() }  // fix: always invalidate, even on throw
                do {
                    try FileManager.default.unzipItem(at: archive, to: destination, progress: progress)
                    cont.resume()
                } catch {
                    cont.resume(throwing: LocalModelInstallError.extractionFailed(reason: error.localizedDescription))
                }
            }
        }
    }

    private func resolveSourceURL(in extractedURL: URL) -> URL {
        let nested = extractedURL.appendingPathComponent(entry.installFolderName)
        return fileManager.fileExists(atPath: nested.path) ? nested : extractedURL
    }

    private func validate(at url: URL) throws {
        let missing = entry.requiredFiles.filter { name in
            !fileManager.fileExists(atPath: url.appendingPathComponent(name).path)
        }
        guard missing.isEmpty else {
            throw LocalModelInstallError.validationFailed(missingFiles: missing)
        }
    }

    /// Versioned atomic activation:
    /// Installs to `LocalModels/<model-id>/<version>/` then writes a
    /// `LocalModels/<model-id>/current` symlink. Old version is kept as rollback.
    private func activate(source: URL, parent: URL) throws {
        let modelRoot = parent.appendingPathComponent(entry.id, isDirectory: true)
        let versionedDest = modelRoot.appendingPathComponent(entry.version, isDirectory: true)
        let currentLink = modelRoot.appendingPathComponent("current")

        try fileManager.createDirectory(at: modelRoot, withIntermediateDirectories: true)

        // Remove any previous version at this exact path
        if fileManager.fileExists(atPath: versionedDest.path) {
            try fileManager.removeItem(at: versionedDest)
        }
        do {
            try fileManager.moveItem(at: source, to: versionedDest)
        } catch {
            throw LocalModelInstallError.activationFailed(reason: error.localizedDescription)
        }

        // Atomic symlink swap
        let tempLink = modelRoot.appendingPathComponent("current.tmp")
        do {
            if fileManager.fileExists(atPath: tempLink.path) {
                try fileManager.removeItem(at: tempLink)
            }
            try fileManager.createSymbolicLink(at: tempLink, withDestinationURL: versionedDest)
            // `replaceItem` for atomic swap
            _ = try fileManager.replaceItemAt(currentLink, withItemAt: tempLink)
        } catch {
            // Fallback: direct rename
            if fileManager.fileExists(atPath: currentLink.path) {
                try? fileManager.removeItem(at: currentLink)
            }
            try fileManager.createSymbolicLink(at: currentLink, withDestinationURL: versionedDest)
        }

        emit(phase: .activating, phaseProgress: 1, speed: 0, eta: nil)
    }

    // MARK: - Helpers

    private func emit(
        phase: LocalModelInstallPhase,
        phaseProgress: Double,
        speed: Double,
        eta: Double?
    ) {
        let baseProgress = phaseWeights
            .filter { $0.key.rawValue < phase.rawValue }
            .reduce(0) { $0 + $1.value }
        let overall = baseProgress + phaseProgress * (phaseWeights[phase] ?? 0)
        onProgress?(.active(
            phase: phase,
            progress: phaseProgress,
            overallProgress: min(overall, 1.0),
            speedBytesPerSec: speed,
            etaSeconds: eta
        ))
    }
}
