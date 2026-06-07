import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum GenerationError: LocalizedError, Equatable, Sendable {
    case emptyPrompt
    case promptTooLong(maxCharacters: Int)
    case invalidEndpoint
    case invalidResponse
    case invalidImageURL
    case downloadFailed
    case networkUnavailable
    case requestTimedOut
    case rateLimited
    case unauthorized
    case moderationRejected
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
        case .promptTooLong(let maxCharacters):
            return "Keep prompts under \(maxCharacters) characters."
        case .invalidEndpoint:
            return "The image service URL is not configured correctly."
        case .invalidResponse:
            return "The image service returned an unreadable response."
        case .invalidImageURL:
            return "The generated image link was missing or invalid."
        case .downloadFailed:
            return "The image was created, but the download failed. Try again."
        case .networkUnavailable:
            return "The network is unavailable. Check your connection and retry."
        case .requestTimedOut:
            return "Generation is taking too long. Try again in a moment."
        case .rateLimited:
            return "You have reached the current generation limit. Try again later."
        case .unauthorized:
            return "The image service is not authorized. Contact support."
        case .moderationRejected:
            return "That prompt could not be generated. Try changing the wording."
        case .unsupportedModel(let message):
            return message.isEmpty ? "That model is not available yet." : message
        case .providerUnavailable:
            return "The image provider is temporarily unavailable. Try again."
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
        case .moderationRejected:
            return "Keep the idea, but remove wording that might be read as unsafe or explicit."
        case .rateLimited:
            return "Lower quality or wait for the limit window to reset."
        case .providerUnavailable, .networkUnavailable, .requestTimedOut:
            return "Your prompt is preserved so you can retry."
        default:
            return nil
        }
    }
}
