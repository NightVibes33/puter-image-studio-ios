import Foundation

protocol ImageGenerationClient {
    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage
}
