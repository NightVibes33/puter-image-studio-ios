import Foundation

struct ImageGenerationRequest: Codable, Equatable, Sendable {
    var prompt: String
    var negativePrompt: String?
    var model: String
    var quality: String?
    var width: Int
    var height: Int
    var responseFormat: ResponseFormat

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
    }

    init(
        prompt: String,
        negativePrompt: String? = nil,
        model: String,
        quality: String?,
        width: Int,
        height: Int,
        responseFormat: ResponseFormat = .url
    ) {
        self.prompt = prompt
        self.negativePrompt = negativePrompt
        self.model = model
        self.quality = quality
        self.width = width
        self.height = height
        self.responseFormat = responseFormat
    }
}
