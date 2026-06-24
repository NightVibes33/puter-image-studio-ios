import Foundation

enum ImageQuality: String, CaseIterable, Sendable {
    case low, hd
}

struct ImageModel: Identifiable, Sendable {
    let id: String
    let name: String
    let supportsQuality: Bool
    
    var supportedQualities: [ImageQuality] {
        supportsQuality ? [.low, .hd] : []
    }
    
    var defaultQuality: ImageQuality {
        .low
    }

    static let fallback = ImageModel(id: "stable-diffusion-v1-5", name: "Stable Diffusion v1.5", supportsQuality: false)
    
    static func preset(id: String) -> ImageModel {
        return fallback
    }
}
