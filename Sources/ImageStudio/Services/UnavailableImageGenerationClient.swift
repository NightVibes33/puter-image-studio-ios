import Foundation

struct UnavailableImageGenerationClient: ImageGenerationClient {
    var error: GenerationError

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        throw error
    }
}
