import Foundation

enum LocalModelInstallError: Error, Equatable, Sendable {
    case unknownModelID(String)
    case insufficientDiskSpace(requiredBytes: Int64)
    case downloadFailed(String)
    case checksumMismatch
    case extractionFailed(String)
    case validationFailed(String)
    case activationFailed(String)
    case cancelled
    case unknown(String)

    // MARK: - LocalizedError

    var errorDescription: String? {
        switch self {
        case .unknownModelID(let id):              return "Unknown model: \(id)"
        case .insufficientDiskSpace(let bytes):    return "Not enough storage (need \(formatBytes(bytes)))"
        case .downloadFailed(let msg):             return "Download failed: \(msg)"
        case .checksumMismatch:                    return "Download verification failed"
        case .extractionFailed(let msg):           return "Extraction failed: \(msg)"
        case .validationFailed(let msg):           return "Validation failed: \(msg)"
        case .activationFailed(let msg):           return "Activation failed: \(msg)"
        case .cancelled:                           return "Installation cancelled"
        case .unknown(let msg):                    return msg
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .insufficientDiskSpace(let needed):
            return "Free at least \(formatBytes(needed)) and tap Retry."
        case .checksumMismatch:
            return "The file may be corrupted. Tap Retry to re-download."
        case .downloadFailed:
            return "Check your internet connection and tap Retry."
        case .cancelled:
            return nil
        default:
            return "Tap Retry to try again."
        }
    }

    var isRetryable: Bool {
        switch self {
        case .insufficientDiskSpace, .cancelled: return false
        default: return true
        }
    }

    // MARK: - Helpers

    private func formatBytes(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
