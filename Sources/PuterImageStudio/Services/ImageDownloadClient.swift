import Foundation
import UIKit

final class ImageDownloadClient {
    private let session: URLSession
    private let fileManager: FileManager
    let imagesDirectoryURL: URL

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager

        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        imagesDirectoryURL = supportURL.appendingPathComponent("GeneratedImages", isDirectory: true)
        try? fileManager.createDirectory(at: imagesDirectoryURL, withIntermediateDirectories: true, attributes: nil)
    }

    func downloadImage(from url: URL, preferredFileName: String) async throws -> String {
        do {
            let (data, response) = try await session.data(from: url)
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw GenerationError.downloadFailed
            }
            return try writeImageData(data, preferredFileName: preferredFileName)
        } catch is CancellationError {
            throw GenerationError.cancelled
        } catch let error as GenerationError {
            throw error
        } catch let error as URLError {
            throw ImageDownloadClient.map(error)
        } catch {
            throw GenerationError.downloadFailed
        }
    }

    func writeImageData(_ data: Data, preferredFileName: String) throws -> String {
        guard UIImage(data: data) != nil else {
            throw GenerationError.downloadFailed
        }

        let safeFileName = ImageDownloadClient.safeFileName(preferredFileName)
        let destinationURL = imagesDirectoryURL.appendingPathComponent(safeFileName)
        try data.write(to: destinationURL, options: [.atomic])
        return safeFileName
    }

    func localURL(for fileName: String) -> URL {
        imagesDirectoryURL.appendingPathComponent(fileName)
    }

    func delete(fileName: String) {
        let url = localURL(for: fileName)
        try? fileManager.removeItem(at: url)
    }

    private static func safeFileName(_ fileName: String) -> String {
        let fallback = "\(UUID().uuidString).png"
        guard !fileName.isEmpty else { return fallback }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let filtered = fileName.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        return filtered.hasSuffix(".png") ? filtered : "\(filtered).png"
    }

    private static func map(_ error: URLError) -> GenerationError {
        switch error.code {
        case .cancelled:
            return .cancelled
        case .timedOut:
            return .requestTimedOut
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost:
            return .networkUnavailable
        default:
            return .downloadFailed
        }
    }
}
