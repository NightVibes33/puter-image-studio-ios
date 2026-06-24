import Foundation

struct GeneratedImage: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var prompt: String
    var negativePrompt: String?
    var revisedPrompt: String?
    var model: String
    var quality: String?
    var width: Int
    var height: Int
    var createdAt: Date
    var remoteURL: URL?
    var localFileName: String

    // Reproducibility metadata — stored so the user can re-run exact settings
    var seed: UInt32?
    var stepCount: Int?
    var guidanceScale: Float?
    var modelVersion: String?   // e.g. "1.0.0" from the manifest

    init(
        id: UUID = UUID(),
        prompt: String,
        negativePrompt: String? = nil,
        revisedPrompt: String?,
        model: String,
        quality: String?,
        width: Int,
        height: Int,
        createdAt: Date = Date(),
        remoteURL: URL?,
        localFileName: String,
        seed: UInt32? = nil,
        stepCount: Int? = nil,
        guidanceScale: Float? = nil,
        modelVersion: String? = nil
    ) {
        self.id = id
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.revisedPrompt = revisedPrompt
        self.model = model
        self.quality = quality
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.remoteURL = remoteURL
        self.localFileName = localFileName
        self.seed = seed
        self.stepCount = stepCount
        self.guidanceScale = guidanceScale
        self.modelVersion = modelVersion
    }

    /// Returns an `ImageModel` by looking up `model` in the presets list.
    var resolvedModel: ImageModel {
        ImageModel.preset(id: model)
    }
}
