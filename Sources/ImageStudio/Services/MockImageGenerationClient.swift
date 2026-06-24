import Foundation
final class MockImageGenerationClient: ImageGenerationClient {
    private let imageDownloadClient: ImageDownloadClient
    init(imageDownloadClient: ImageDownloadClient) {
        self.imageDownloadClient = imageDownloadClient
    }
    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        return GeneratedImage(
            id: UUID(),
            prompt: request.prompt,
            revisedPrompt: nil,
            model: request.model,
            quality: request.quality,
            width: 512,
            height: 512,
            createdAt: Date(),
            remoteURL: nil,
            localFileName: "mock.png"
        )
    }
}
extension MockImageGenerationClient: @unchecked Sendable {}
