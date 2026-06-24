import Foundation

struct ImageGenerationResponse: Decodable, Equatable, Sendable {
    var created: Int
    var data: [ImageGenerationData]
}

struct ImageGenerationData: Decodable, Equatable, Sendable {
    var revisedPrompt: String?
    var url: URL?
    var b64JSON: String?

    enum CodingKeys: String, CodingKey {
        case revisedPrompt = "revised_prompt"
        case url
        case b64JSON = "b64_json"
    }
}

struct ImageGenerationErrorResponse: Decodable, Equatable, Sendable {
    var error: APIError

    struct APIError: Decodable, Equatable, Sendable {
        var message: String
        var detail: String?
    }
}
