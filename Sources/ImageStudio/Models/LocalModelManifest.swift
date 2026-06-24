import Foundation

// MARK: - Chip tier

enum LocalModelChipTier: String, Codable, Sendable {
    case a14  // iPhone 12+
    case a15  // iPhone 13+
    case a16  // iPhone 14 Pro+
    case a17  // iPhone 15 Pro+
    case m1   // iPad Pro M1+
}

// MARK: - Single model entry

struct LocalModelEntry: Codable, Identifiable, Equatable, Sendable {
    /// Matches `ImageModel.id` / `backendModel` used by the generation pipeline.
    var id: String
    /// Human-readable semantic version string, e.g. "1.0.0".
    var version: String
    var title: String
    var subtitle: String
    /// Direct download URL for the compiled ZIP archive.
    var archiveURL: URL
    /// Lowercase hex SHA-256 of the archive file. Used for pre-extraction integrity check.
    var sha256: String
    /// Top-level folder name inside the archive (and on disk).
    var installFolderName: String
    /// Bytes required free before download + extraction begins.
    var requiredFreeBytes: Int64
    /// Every file/directory that must exist for the install to be considered valid.
    var requiredFiles: [String]
    /// Minimum chip required. nil = no restriction.
    var minimumChip: LocalModelChipTier?
    /// Minimum RAM in bytes. nil = no restriction.
    var minimumRAMBytes: Int64?
    /// Mirror URLs tried in order when the primary archiveURL fails.
    var mirrorURLs: [URL]

    var requiredFreeSpaceDescription: String {
        ByteCountFormatter.string(fromByteCount: requiredFreeBytes, countStyle: .file)
    }
}

// MARK: - Catalog

struct LocalModelCatalog: Codable, Sendable {
    var schemaVersion: Int
    var models: [LocalModelEntry]

    /// Loads the bundled `local-models.json` from the main bundle.
    static func bundled() throws -> LocalModelCatalog {
        guard let url = Bundle.main.url(forResource: "local-models", withExtension: "json") else {
            throw LocalModelCatalogError.manifestNotFound
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(LocalModelCatalog.self, from: data)
    }

    func entry(id: String) -> LocalModelEntry? {
        models.first { $0.id == id }
    }
}

enum LocalModelCatalogError: LocalizedError, Sendable {
    case manifestNotFound
    case unknownModel(String)

    var errorDescription: String? {
        switch self {
        case .manifestNotFound:
            return "The local model catalog was not found in the app bundle."
        case .unknownModel(let id):
            return "No local model found with ID \"\(id)\"."
        }
    }
}
