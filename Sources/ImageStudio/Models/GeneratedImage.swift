import Foundation

struct GeneratedImage: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var prompt: String
    var revisedPrompt: String?
    var model: String
    var quality: String?
    var width: Int
    var height: Int
    var createdAt: Date
    var remoteURL: URL?
    var localFileName: String

    /// Typed model resolved from the stored model ID string.
    /// Falls back to `ImageModel.fallback` for records written before a model was removed.
    var resolvedModel: ImageModel {
        ImageModel.preset(id: model)
    }

    init(
        id: UUID = UUID(),
        prompt: String,
        revisedPrompt: String?,
        model: String,
        quality: String?,
        width: Int,
        height: Int,
        createdAt: Date = Date(),
        remoteURL: URL?,
        localFileName: String
    ) {
        self.id = id
        self.prompt = prompt
        self.revisedPrompt = revisedPrompt
        self.model = model
        self.quality = quality
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.remoteURL = remoteURL
        self.localFileName = localFileName
    }
}
