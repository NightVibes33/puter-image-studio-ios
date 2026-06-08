import Foundation

final class HybridImageGenerationClient: ImageGenerationClient {
    private let localClient: ImageGenerationClient
    private let remoteClient: ImageGenerationClient

    init(localClient: ImageGenerationClient, remoteClient: ImageGenerationClient) {
        self.localClient = localClient
        self.remoteClient = remoteClient
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        if request.usesLocalModel {
            return try await localClient.generate(request)
        }
        return try await remoteClient.generate(request)
    }
}

extension HybridImageGenerationClient: @unchecked Sendable {}
