import Foundation

struct StylePreset: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var title: String
    var systemImage: String
    var promptSuffix: String

    func apply(to prompt: String) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptSuffix.isEmpty else { return trimmedPrompt }
        return "\(trimmedPrompt), \(promptSuffix)"
    }

    static let presets: [StylePreset] = [
        StylePreset(id: "realistic", title: "Realistic", systemImage: "camera.aperture", promptSuffix: "photorealistic, natural lighting, high detail"),
        StylePreset(id: "anime", title: "Anime", systemImage: "sparkles", promptSuffix: "anime illustration, clean linework, expressive lighting"),
        StylePreset(id: "cinematic", title: "Cinematic", systemImage: "movieclapper", promptSuffix: "cinematic composition, dramatic lighting, film still"),
        StylePreset(id: "cyberpunk", title: "Cyberpunk", systemImage: "bolt.horizontal.circle", promptSuffix: "neon cyberpunk, rain, reflective streets, high contrast"),
        StylePreset(id: "fantasy", title: "Fantasy", systemImage: "wand.and.stars", promptSuffix: "epic fantasy art, magical atmosphere, detailed environment"),
        StylePreset(id: "logo", title: "Logo", systemImage: "seal", promptSuffix: "simple logo mark, clean vector-like design, no text"),
        StylePreset(id: "tattoo", title: "Tattoo", systemImage: "scribble.variable", promptSuffix: "tattoo flash design, bold lines, high contrast, no text"),
        StylePreset(id: "wallpaper", title: "Wallpaper", systemImage: "iphone", promptSuffix: "phone wallpaper composition, centered subject, clean negative space, no text"),
        StylePreset(id: "3d", title: "3D", systemImage: "cube.transparent", promptSuffix: "3D render, studio lighting, polished materials"),
        StylePreset(id: "sketch", title: "Sketch", systemImage: "pencil.and.scribble", promptSuffix: "pencil sketch, monochrome, detailed shading")
    ]

    static var defaultPreset: StylePreset {
        presets[2]
    }
}
