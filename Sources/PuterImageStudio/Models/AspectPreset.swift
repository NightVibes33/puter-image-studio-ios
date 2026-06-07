import Foundation

struct AspectPreset: Identifiable, Codable, Equatable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var width: Int
    var height: Int
    var systemImage: String

    static let presets: [AspectPreset] = [
        AspectPreset(id: "square", title: "Square", subtitle: "512 x 512", width: 512, height: 512, systemImage: "square"),
        AspectPreset(id: "wallpaper", title: "Portrait Wallpaper", subtitle: "1024 x 1792", width: 1024, height: 1792, systemImage: "rectangle.portrait"),
        AspectPreset(id: "social-4x5", title: "Social 4:5", subtitle: "1024 x 1280", width: 1024, height: 1280, systemImage: "rectangle.portrait.fill"),
        AspectPreset(id: "landscape", title: "Landscape", subtitle: "1344 x 768", width: 1344, height: 768, systemImage: "rectangle"),
    ]

    static var fallback: AspectPreset {
        presets[0]
    }
}
