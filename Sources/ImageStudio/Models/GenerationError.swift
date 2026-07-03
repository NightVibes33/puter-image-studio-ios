import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum GenerationError: LocalizedError, Equatable, Sendable {
    case emptyPrompt
    case invalidResponse
    case downloadFailed
    case networkUnavailable
    case requestTimedOut
    case unsupportedDevice(String)
    case localModelMissing
    case localModelStorageTooLow(String)
    case localEngineUnavailable
    case photosAccessDenied
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt before generating."
        case .invalidResponse:
            return "The local engine returned an unreadable image."
        case .downloadFailed:
            return "The generated image could not be saved locally."
        case .networkUnavailable:
            return "A required download could not start because the network is unavailable."
        case .requestTimedOut:
            return "The current operation took too long. Try again."
        case .unsupportedDevice(let message):
            return message.isEmpty ? "This device does not meet the requirements for local SDXL." : message
        case .localModelMissing:
            return "Install the local SDXL model before generating."
        case .localModelStorageTooLow(let message):
            return message
        case .localEngineUnavailable:
            return "This build does not include the local Core ML Stable Diffusion engine."
        case .photosAccessDenied:
            return "Allow photo access to save images to Photos."
        case .cancelled:
            return "Generation was cancelled."
        case .unknown(let message):
            return message.isEmpty ? "Something went wrong. Try again." : message
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .localModelMissing:
            return "Open Settings and install Local SDXL."
        case .localModelStorageTooLow:
            return "Free up storage, then retry the local model install."
        case .unsupportedDevice:
            return "Use a supported physical device with enough RAM for on-device generation."
        case .localEngineUnavailable:
            return "Add the StableDiffusion Swift package to this build."
        case .networkUnavailable, .requestTimedOut:
            return "Retry after checking local storage, connectivity for model downloads, and device state."
        case .photosAccessDenied:
            return "Enable Photos access in Settings to export images."
        default:
            return nil
        }
    }
}
