import Foundation
import SwiftUI

@MainActor
final class GenerationHistoryStore: ObservableObject {
    @Published private(set) var images: [GeneratedImage] = []

    private let imageDownloadClient: ImageDownloadClient
    private let fileManager: FileManager
    private let historyURL: URL

    init(imageDownloadClient: ImageDownloadClient, fileManager: FileManager = .default) {
        self.imageDownloadClient = imageDownloadClient
        self.fileManager = fileManager
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        historyURL = supportURL.appendingPathComponent("generation-history.json")
        try? fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true, attributes: nil)
        load()
    }

    func add(_ image: GeneratedImage) {
        images.removeAll { $0.id == image.id }
        images.insert(image, at: 0)
        save()
    }

    func delete(_ image: GeneratedImage) {
        images.removeAll { $0.id == image.id }
        imageDownloadClient.delete(fileName: image.localFileName)
        save()
    }

    func remove(_ image: GeneratedImage) {
        delete(image)
    }

    func clear() {
        images.forEach { imageDownloadClient.delete(fileName: $0.localFileName) }
        images = []
        save()
    }

    func localURL(for image: GeneratedImage) -> URL {
        imageDownloadClient.localURL(for: image.localFileName)
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else {
            images = []
            return
        }

        do {
            images = try JSONDecoder().decode([GeneratedImage].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
        } catch {
            images = []
        }
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(images)
            try data.write(to: historyURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save generation history: \(error)")
        }
    }
}
