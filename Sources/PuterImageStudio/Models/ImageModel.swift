import Foundation

struct ImageModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var backendModel: String
    var defaultQuality: ImageQuality?
    var supportedQualities: [ImageQuality]

    var supportsQuality: Bool {
        !supportedQualities.isEmpty
    }

    var isLocal: Bool {
        backendModel == LocalStableDiffusionModelStore.backendModelID
    }

    static let presets: [ImageModel] = [
        ImageModel(
            id: "local-sdxl",
            title: "Local SDXL",
            subtitle: "On-device, no credits",
            backendModel: LocalStableDiffusionModelStore.backendModelID,
            defaultQuality: nil,
            supportedQualities: []
        ),
        ImageModel(
            id: "auto",
            title: "Cloud Auto",
            subtitle: "Online fallback",
            backendModel: "gpt-image-2",
            defaultQuality: .low,
            supportedQualities: [.low]
        ),
        ImageModel(
            id: "gpt-image-2",
            title: "GPT Image 2",
            subtitle: "Balanced detail",
            backendModel: "gpt-image-2",
            defaultQuality: .low,
            supportedQualities: [.low, .medium, .high]
        ),
        ImageModel(
            id: "gemini-image",
            title: "Gemini Image",
            subtitle: "Fast creative draft",
            backendModel: "gemini-2.5-flash-image-preview",
            defaultQuality: nil,
            supportedQualities: []
        ),
        ImageModel(
            id: "flux-schnell",
            title: "Flux Schnell",
            subtitle: "Quick stylized output",
            backendModel: "black-forest-labs/flux-schnell",
            defaultQuality: nil,
            supportedQualities: []
        ),
        ImageModel(
            id: "dall-e-3",
            title: "DALL-E 3",
            subtitle: "Prompt faithful",
            backendModel: "dall-e-3",
            defaultQuality: .standard,
            supportedQualities: [.standard, .hd]
        ),
        ImageModel(
            id: "sdxl",
            title: "SDXL",
            subtitle: "Open style range",
            backendModel: "stabilityai/stable-diffusion-xl-base-1.0",
            defaultQuality: nil,
            supportedQualities: []
        )
    ]

    static var fallback: ImageModel {
        presets[0]
    }

    static func preset(id: String) -> ImageModel {
        presets.first { $0.id == id } ?? fallback
    }
}

enum ImageQuality: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case low
    case medium
    case high
    case standard
    case hd

    var id: String { rawValue }

    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .standard: return "Standard"
        case .hd: return "HD"
        }
    }
}
