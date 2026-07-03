import Foundation

struct UnavailableImageGenerationClient: LocalImageGenerator {
    var error: GenerationError

    func generate(_ request: LocalGenerationRequest) async throws -> GeneratedImage {
        throw error
    }
}
