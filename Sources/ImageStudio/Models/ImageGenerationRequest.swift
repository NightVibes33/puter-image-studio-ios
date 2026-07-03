import Foundation

struct LocalGenerationRequest: Codable, Equatable, Sendable {
    var prompt: String
    var negativePrompt: String?
    var width: Int
    var height: Int
    var seed: UInt32?
    var stepCount: Int?
    var guidanceScale: Float?

    init(
        prompt: String,
        negativePrompt: String? = nil,
        width: Int,
        height: Int,
        seed: UInt32? = nil,
        stepCount: Int? = nil,
        guidanceScale: Float? = nil
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.width = width
        self.height = height
        self.seed = seed
        self.stepCount = stepCount
        self.guidanceScale = guidanceScale
    }
}
