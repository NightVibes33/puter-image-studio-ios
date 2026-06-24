import Foundation

struct ImageGenerationRequest: Codable, Equatable, Sendable {
    var prompt: String
    var negativePrompt: String?
    var model: String
    var quality: String?
    var width: Int
    var height: Int
    var responseFormat: ResponseFormat

    // Local-only inference controls
    // These are ignored by cloud clients and used directly by the local SD pipeline.
    var seed: UInt32?
    var stepCount: Int?
    var guidanceScale: Float?

    enum ResponseFormat: String, Codable, Sendable {
        case url
        case b64JSON = "b64_json"
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt = "negative_prompt"
        case model
        case quality
        case width
        case height
        case responseFormat = "response_format"
        case seed
        case stepCount  = "step_count"
        case guidanceScale = "guidance_scale"
    }

    init(
        prompt: String,
        negativePrompt: String? = nil,
        model: String,
        quality: String? = nil,
        width: Int,
        height: Int,
        responseFormat: ResponseFormat = .url,
        seed: UInt32? = nil,
        stepCount: Int? = nil,
        guidanceScale: Float? = nil
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.model = model
        self.quality = quality
        self.width = width
        self.height = height
        self.responseFormat = responseFormat
        self.seed = seed
        self.stepCount = stepCount
        self.guidanceScale = guidanceScale
    }
}
