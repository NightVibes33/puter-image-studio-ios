import Foundation

struct ImageGenerationResponse: Decodable, Equatable {
    var created: Int
    var data: [ImageGenerationData]
}

struct ImageGenerationData: Decodable, Equatable {
    var revisedPrompt: String?
    var url: URL?
    var b64JSON: String?

    enum CodingKeys: String, CodingKey {
        case revisedPrompt = "revised_prompt"
        case url
        case b64JSON = "b64_json"
    }
}

struct ImageGenerationErrorResponse: Decodable, Equatable {
    var error: APIError

    struct APIError: Decodable, Equatable {
        var message: String
        var detail: String?
    }
}
