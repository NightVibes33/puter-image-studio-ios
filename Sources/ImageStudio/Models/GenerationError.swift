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
    case missingLocalConnection
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
            return "API not configured."
        case .invalidResponse:
            return "The image service returned an unreadable response."
        case .invalidImageURL:
            return "The generated image link was missing or invalid."
        case .downloadFailed:
            return "The image was created, but the download failed. Try again."
        case .networkUnavailable:
            return "Network unavailable."
        case .requestTimedOut:
            return "Generation is taking too long. Try again in a moment."
        case .rateLimited:
            return "You have reached the current generation limit. Try again later."
        case .unauthorized:
            return "The image service is not authorized. Contact support."
        case .missingLocalConnection:
            return "Connect Local before using cloud image models."
        case .localModelMissing:
            return "Install the local SDXL model before generating offline."
        case .localModelStorageTooLow(let message):
            return message
        case .localEngineUnavailable:
            return "This build does not include the local Core ML Stable Diffusion engine."
        case .insufficientCredits(let message):
            return message.isEmpty ? "The Local account for this build has insufficient credits." : message
        case .unsupportedModel(let message):
            return message.isEmpty ? "That model is not available yet." : message
        case .providerUnavailable(let message):
            return message.isEmpty ? "The image provider is temporarily unavailable. Try again." : message
        case .server(let message):
            return message.isEmpty ? "The image service had a problem. Try again." : message
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
        case .rateLimited:
            return "Lower quality or wait for the limit window to reset."
        case .missingLocalConnection:
            return "Open Settings and connect Local, or switch back to Local SDXL."
        case .localModelMissing:
            return "Open Settings and install Local SDXL."
        case .localModelStorageTooLow:
            return "Free up storage, then retry the local model install."
        case .localEngineUnavailable:
            return "Add the StableDiffusion Swift package to this build."
        case .insufficientCredits:
            return "Use a Local account/session with available credits."
        case .invalidEndpoint:
            return "Install a build with the deployed image API URL."
        case .providerUnavailable, .networkUnavailable, .requestTimedOut:
            return "Check the API URL or connection, then retry."
        default:
            return nil
        }
    }
}
