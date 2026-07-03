import Foundation

protocol LocalImageGenerator: Sendable {
    func generate(_ request: LocalGenerationRequest) async throws -> GeneratedImage
}
