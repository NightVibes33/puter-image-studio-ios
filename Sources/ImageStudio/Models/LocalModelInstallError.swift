import Foundation

/// Typed errors for the local model install pipeline.
/// Replaces the old `GenerationError` cases and `LocalModelInstallState.failed(String)`.
enum LocalModelInstallError: LocalizedError, Equatable, Sendable {
    case manifestNotFound
    case unknownModelID(String)
    case storageTooLow(available: Int64, required: Int64)
    case networkUnavailable
    case timedOut
    case downloadFailed(reason: String)
    case checksumMismatch(expected: String, actual: String)
    case extractionFailed(reason: String)
    case validationFailed(missingFiles: [String])
    case activationFailed(reason: String)
    case rollbackFailed(reason: String)
    case deviceNotSupported(reason: String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "The local model catalog is missing from the app."
        case .unknownModelID(let id):
            return "No model found with ID \"\(id)\"."
        case .storageTooLow(let available, let required):
            let fmt = ByteCountFormatter()
            fmt.countStyle = .file
            return "Not enough storage. \(fmt.string(fromByteCount: available)) free, \(fmt.string(fromByteCount: required)) required."
        case .networkUnavailable:
            return "Network unavailable. Check your connection and try again."
        case .timedOut:
            return "Download timed out. Use a stable Wi-Fi connection."
        case .downloadFailed(let reason):
            return reason.isEmpty ? "Download failed. Tap Retry." : reason
        case .checksumMismatch:
            return "The downloaded archive is corrupted. Tap Retry to download again."
        case .extractionFailed(let reason):
            return reason.isEmpty ? "Extraction failed." : reason
        case .validationFailed(let files):
            let list = files.prefix(3).joined(separator: ", ")
            return "Install validation failed — missing: \(list)."
        case .activationFailed(let reason):
            return reason.isEmpty ? "Could not activate the installed model." : reason
        case .rollbackFailed(let reason):
            return "Rollback failed: \(reason)."
        case .deviceNotSupported(let reason):
            return reason
        case .cancelled:
            return "Installation was cancelled."
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .storageTooLow:
            return "Free up storage in Settings → General → iPhone Storage, then retry."
        case .networkUnavailable, .timedOut, .downloadFailed:
            return "Connect to Wi-Fi and tap Retry."
        case .checksumMismatch, .extractionFailed:
            return "The download will restart from scratch."
        case .validationFailed:
            return "Tap Reinstall to re-download the model."
        case .deviceNotSupported:
            return "This model requires a newer device."
        default:
            return nil
        }
    }

    /// True if the error is worth auto-retrying with exponential backoff.
    var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .timedOut, .downloadFailed:
            return true
        default:
            return false
        }
    }
}
