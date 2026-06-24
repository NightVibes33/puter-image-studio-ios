import Foundation

struct ImageModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var backendModel: String
    var defaultQuality: ImageQuality?
    var supportedQualities: [ImageQuality]
    var modelSizeBytes: Int64?

    var supportsQuality: Bool { !supportedQualities.isEmpty }

    var isLocal: Bool {
        backendModel == LocalStableDiffusionModelStore.backendModelID
    }

    // MARK: - Single on-device model only
    static let presets: [ImageModel] = [
        ImageModel(
            id: "local-sdxl",
            title: "On-Device SDXL",
            subtitle: "Private · no internet · no credits",
            backendModel: LocalStableDiffusionModelStore.backendModelID,
            defaultQuality: nil,
            supportedQualities: [],
            modelSizeBytes: 6_400_000_000
        )
    ]

    static var fallback: ImageModel { presets[0] }

    static func preset(id: String) -> ImageModel {
        presets.first { $0.id == id } ?? fallback
    }

    static var localModels: [ImageModel] { presets.filter(\.isLocal) }
}

enum ImageQuality: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case low, medium, high, standard, hd
    var id: String { rawValue }
    var title: String {
        switch self {
        case .low:      return "Low"
        case .medium:   return "Medium"
        case .high:     return "High"
        case .standard: return "Standard"
        case .hd:       return "HD"
        }
    }
}
