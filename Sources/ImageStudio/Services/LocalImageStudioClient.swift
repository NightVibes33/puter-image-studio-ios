import Foundation

final class LocalImageStudioClient: ImageGenerationClient {
    private let localClient: ImageGenerationClient

    init(localClient: ImageGenerationClient) {
        self.localClient = localClient
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        return try await localClient.generate(request)
    }
}

extension LocalImageStudioClient: @unchecked Sendable {}
