import Foundation

struct StylePreset: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    /// Suffix appended to the user prompt when this style is active.
    let promptSuffix: String

    /// Return the prompt with the style suffix appended (trimmed, comma-separated).
    func apply(to prompt: String) -> String {
        let base = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptSuffix.isEmpty else { return base }
        guard !base.isEmpty else { return promptSuffix }
        return base + promptSuffix
    }

    // MARK: - Presets

    static let defaultPreset = StylePreset(
        id: "none",
        title: "None",
        systemImage: "photo",
        promptSuffix: ""
    )

    static let presets: [StylePreset] = [
        defaultPreset,
        StylePreset(id: "cinematic",    title: "Cinematic",   systemImage: "film",                promptSuffix: ", cinematic lighting, film grain, anamorphic lens"),
        StylePreset(id: "anime",        title: "Anime",       systemImage: "sparkles",            promptSuffix: ", anime style, vibrant colors, detailed line art"),
        StylePreset(id: "photorealism", title: "Photo",       systemImage: "camera",              promptSuffix: ", photorealistic, DSLR, 8k, sharp focus"),
        StylePreset(id: "realistic",    title: "Realistic",   systemImage: "camera.fill",         promptSuffix: ", hyperrealistic photography, natural lighting, sharp"),
        StylePreset(id: "painting",     title: "Painting",    systemImage: "paintpalette",        promptSuffix: ", oil painting, thick brush strokes, impressionist"),
        StylePreset(id: "sketch",       title: "Sketch",      systemImage: "pencil.and.scribble", promptSuffix: ", pencil sketch, black and white, fine detail"),
        StylePreset(id: "neon",         title: "Neon",        systemImage: "lightbulb",           promptSuffix: ", neon lights, cyberpunk, dark background, glowing"),
        StylePreset(id: "watercolor",   title: "Watercolor",  systemImage: "drop",                promptSuffix: ", watercolor illustration, soft edges, pastel tones"),
        StylePreset(id: "3d",           title: "3D Render",   systemImage: "cube.transparent",   promptSuffix: ", 3D render, octane render, subsurface scattering, studio lighting"),
        StylePreset(id: "logo",         title: "Logo",        systemImage: "seal",                promptSuffix: ", minimal logo design, vector style, clean lines, no text"),
        StylePreset(id: "wallpaper",    title: "Wallpaper",   systemImage: "iphone",              promptSuffix: ", premium wallpaper, 4K, ultra-detailed, deep contrast"),
    ]
}
