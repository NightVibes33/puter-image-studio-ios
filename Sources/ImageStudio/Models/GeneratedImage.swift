import Foundation

struct GeneratedImage: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var prompt: String
    var negativePrompt: String?
    var revisedPrompt: String?
    var modelDisplayName: String
    var width: Int
    var height: Int
    var createdAt: Date
    var localFileName: String

    var seed: UInt32?
    var stepCount: Int?
    var guidanceScale: Float?
    var modelVersion: String?

    init(
        id: UUID = UUID(),
        prompt: String,
        negativePrompt: String? = nil,
        revisedPrompt: String?,
        modelDisplayName: String,
        width: Int,
        height: Int,
        createdAt: Date = Date(),
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
        self.modelDisplayName = modelDisplayName
        self.width = width
        self.height = height
        self.createdAt = createdAt
        self.localFileName = localFileName
        self.seed = seed
        self.stepCount = stepCount
        self.guidanceScale = guidanceScale
        self.modelVersion = modelVersion
    }
}
