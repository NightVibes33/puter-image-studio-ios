import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum GenerationError: LocalizedError, Equatable, Sendable {
    case emptyPrompt
    case invalidEndpoint
    case invalidResponse
    case invalidImageURL
    case downloadFailed
    case networkUnavailable
    case requestTimedOut
    case rateLimited
    case unauthorized
    case localModelMissing
    case localModelStorageTooLow(String)
    case localEngineUnavailable
    case insufficientCredits(String)
    case unsupportedModel(String)
    case providerUnavailable(String)
    case server(String)
    case photosAccessDenied
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .emptyPrompt:
            return "Enter a prompt before generating."
        case .invalidEndpoint:
            return "The local generation configuration is invalid."
        case .invalidResponse:
            return "The local engine returned an unreadable image."
        case .invalidImageURL:
            return "The generated image could not be opened."
        case .downloadFailed:
            return "The generated image could not be saved locally."
        case .networkUnavailable:
            return "A required download could not start because the network is unavailable."
        case .requestTimedOut:
            return "The current operation took too long. Try again."
        case .rateLimited:
            return "The device is temporarily too busy to continue. Try again in a moment."
        case .unauthorized:
            return "This build is not authorized to access the required local resources."
        case .localModelMissing:
            return "Install the local SDXL model before generating."
        case .localModelStorageTooLow(let message):
            return message
        case .localEngineUnavailable:
            return "This build does not include the local Core ML Stable Diffusion engine."
        case .insufficientCredits(let message):
            return message.isEmpty ? "The current local configuration cannot complete this request." : message
        case .unsupportedModel(let message):
            return message.isEmpty ? "That local model is not available in this build." : message
        case .providerUnavailable(let message):
            return message.isEmpty ? "The local generation engine is temporarily unavailable. Try again." : message
        case .server(let message):
            return message.isEmpty ? "A local runtime error occurred. Try again." : message
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
        case .localEngineUnavailable:
            return "Add the StableDiffusion Swift package to this build."
        case .insufficientCredits:
            return "Reduce resolution or retry after freeing device resources."
        case .providerUnavailable, .networkUnavailable, .requestTimedOut:
            return "Retry after checking local storage, connectivity for model downloads, and device state."
        case .photosAccessDenied:
            return "Enable Photos access in Settings to export images."
        default:
            return nil
        }
    }
}
