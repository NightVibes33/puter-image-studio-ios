import Foundation

/// Replaces `LocalStableDiffusionModelStore`.
/// Derives all paths from a `LocalModelEntry` — no hardcoded folder names or URLs.
struct LocalManifestModelStore {
    let entry: LocalModelEntry
    private let fileManager: FileManager

    init(entry: LocalModelEntry, fileManager: FileManager = .default) {
        self.entry = entry
        self.fileManager = fileManager
    }

    // MARK: - Path resolution

    /// Root directory for all versions of this model.
    func modelRootURL() -> URL? {
        guard let support = fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return support
            .appendingPathComponent("LocalModels", isDirectory: true)
            .appendingPathComponent(entry.id, isDirectory: true)
    }

    /// URL of the `current` symlink, which points to the active versioned folder.
    func currentLinkURL() -> URL? {
        modelRootURL()?.appendingPathComponent("current")
    }

    /// Resolves the `current` symlink to an actual directory URL.
    func activeVersionURL() -> URL? {
        guard let link = currentLinkURL() else { return nil }
        let resolved = (try? URL(
            resolvingAliasFileAt: link,
            options: .withoutMounting
        )) ?? link
        return fileManager.fileExists(atPath: resolved.path) ? resolved : nil
    }

    /// The version string of the currently installed model, or nil if not installed.
    func installedVersion() -> String? {
        guard let url = activeVersionURL() else { return nil }
        guard isValid(at: url) else { return nil }
        // Derive version from the directory name (parent of current)
        return url.lastPathComponent
    }

    func isInstalled() -> Bool {
        installedVersion() != nil
    }

    /// Also checks bundled resources as a fallback.
    func installedResourceURL() -> URL? {
        if let active = activeVersionURL(), isValid(at: active) { return active }
        if let bundled = Bundle.main.url(forResource: entry.installFolderName, withExtension: nil),
           isValid(at: bundled) { return bundled }
        return nil
    }

    // MARK: - Validation

    /// Validates that all required files from the manifest exist.
    func isValid(at url: URL) -> Bool {
        entry.requiredFiles.allSatisfy { name in
            fileManager.fileExists(atPath: url.appendingPathComponent(name).path)
        }
    }

    // MARK: - Cleanup

    func deleteInstall() {
        guard let root = modelRootURL() else { return }
        try? fileManager.removeItem(at: root)
    }
}
