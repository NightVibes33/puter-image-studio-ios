import Foundation

// localClient must be Sendable-bound because LocalImageStudioClient itself is Sendable
// and Swift 6 requires all stored properties of a Sendable type to be Sendable.
final class LocalImageStudioClient: ImageGenerationClient {
    private let localClient: any ImageGenerationClient & Sendable

    init(localClient: any ImageGenerationClient & Sendable) {
        self.localClient = localClient
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        return try await localClient.generate(request)
    }
}

extension LocalImageStudioClient: @unchecked Sendable {}
