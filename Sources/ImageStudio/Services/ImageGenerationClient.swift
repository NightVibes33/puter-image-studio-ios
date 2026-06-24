import Foundation

protocol ImageGenerationClient: Sendable {
    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage
}
