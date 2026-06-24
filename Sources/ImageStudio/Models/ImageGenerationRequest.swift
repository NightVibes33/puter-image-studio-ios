import Foundation

struct ImageGenerationRequest: Codable, Equatable, Sendable {
    var prompt: String
    var negativePrompt: String?
    var model: String
    var quality: String?
    var width: Int
    var height: Int
    var seed: UInt32?
    var stepCount: Int?
    var guidanceScale: Float?
    var responseFormat: ResponseFormat

    enum ResponseFormat: String, Codable, Sendable {
        case url
        case b64JSON = "b64_json"
    }

    enum CodingKeys: String, CodingKey {
        case prompt
        case negativePrompt  = "negative_prompt"
        case model
        case quality
        case width
        case height
        case seed
        case stepCount       = "step_count"
        case guidanceScale   = "guidance_scale"
        case responseFormat  = "response_format"
    }

    init(
        prompt: String,
        negativePrompt: String? = nil,
        model: String,
        quality: String?,
        width: Int,
        height: Int,
        seed: UInt32? = nil,
        stepCount: Int? = nil,
        guidanceScale: Float? = nil,
        responseFormat: ResponseFormat = .url
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.model = model
        self.quality = quality
        self.width = width
        self.height = height
        self.seed = seed
        self.stepCount = stepCount
        self.guidanceScale = guidanceScale
        self.responseFormat = responseFormat
    }
}
