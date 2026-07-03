import Foundation

struct ImageModel: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var title: String
    var subtitle: String
    var engineIdentifier: String
    var modelSizeBytes: Int64?

    var isLocal: Bool { true }

    static let presets: [ImageModel] = [
        ImageModel(
            id: "local-sdxl",
            title: "On-Device SDXL",
            subtitle: "Private · offline after install",
            engineIdentifier: LocalStableDiffusionModelStore.localModelIdentifier,
            modelSizeBytes: 6_400_000_000
        )
    ]

    static var fallback: ImageModel { presets[0] }

    static func preset(id: String) -> ImageModel {
        presets.first { $0.id == id } ?? fallback
    }

    static var localModels: [ImageModel] { presets }
}
