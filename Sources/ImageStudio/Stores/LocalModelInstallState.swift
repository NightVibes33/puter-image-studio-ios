import Foundation

// MARK: - Typed install phases and state

enum LocalModelInstallPhase: String, Equatable, Sendable {
    case queued
    case downloading
    case verifyingArchive
    case extracting
    case validatingFiles
    case activating
    case rollingBack
}

enum LocalModelInstallState: Equatable, Sendable {
    case missing
    case active(
        phase: LocalModelInstallPhase,
        progress: Double,           // 0.0–1.0 within the current phase
        overallProgress: Double,    // 0.0–1.0 across all phases
        speedBytesPerSec: Double,
        etaSeconds: Double?
    )
    case installed(version: String)
    case failed(LocalModelInstallError)

    // MARK: - Convenience accessors (safe for view bindings)

    var isBusy: Bool {
        if case .active = self { return true }
        return false
    }

    var isInstalled: Bool {
        if case .installed = self { return true }
        return false
    }

    var installedVersion: String? {
        if case .installed(let v) = self { return v }
        return nil
    }

    var progress: Double {
        if case .active(_, _, let overall, _, _) = self { return overall }
        return 0
    }

    var phaseProgress: Double {
        if case .active(_, let p, _, _, _) = self { return p }
        return 0
    }

    var currentPhase: LocalModelInstallPhase? {
        if case .active(let phase, _, _, _, _) = self { return phase }
        return nil
    }

    var speedBytesPerSec: Double {
        if case .active(_, _, _, let s, _) = self { return s }
        return 0
    }

    var etaSeconds: Double? {
        if case .active(_, _, _, _, let e) = self { return e }
        return nil
    }

    var failureError: LocalModelInstallError? {
        if case .failed(let e) = self { return e }
        return nil
    }

    var phaseDescription: String {
        switch self {
        case .missing: return "Not installed"
        case .active(let phase, _, _, _, _):
            switch phase {
            case .queued:          return "Queued"
            case .downloading:     return "Downloading"
            case .verifyingArchive:return "Verifying archive"
            case .extracting:      return "Extracting"
            case .validatingFiles: return "Validating"
            case .activating:      return "Activating"
            case .rollingBack:     return "Rolling back"
            }
        case .installed: return "Installed"
        case .failed(let e): return e.errorDescription ?? "Failed"
        }
    }
}
