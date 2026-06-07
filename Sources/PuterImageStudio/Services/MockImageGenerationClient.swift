import Foundation
import UIKit

final class MockImageGenerationClient: ImageGenerationClient {
    private let imageDownloadClient: ImageDownloadClient

    init(imageDownloadClient: ImageDownloadClient) {
        self.imageDownloadClient = imageDownloadClient
    }

    func generate(_ request: ImageGenerationRequest) async throws -> GeneratedImage {
        try await Task.sleep(nanoseconds: 700_000_000)
        let id = UUID()
        let data = try renderPlaceholderPNG(prompt: request.prompt, width: request.width, height: request.height)
        let localFileName = try imageDownloadClient.writeImageData(data, preferredFileName: "\(id.uuidString).png")
        return GeneratedImage(
            id: id,
            prompt: request.prompt,
            revisedPrompt: request.prompt,
            model: request.model,
            quality: request.quality,
            width: request.width,
            height: request.height,
            remoteURL: nil,
            localFileName: localFileName
        )
    }

    private func renderPlaceholderPNG(prompt: String, width: Int, height: Int) throws -> Data {
        let size = CGSize(width: max(256, width), height: max(256, height))
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            UIColor(red: 0.05, green: 0.07, blue: 0.11, alpha: 1).setFill()
            context.cgContext.fill(rect)

            let accent = UIColor(red: 0.18, green: 0.47, blue: 0.91, alpha: 1)
            accent.withAlphaComponent(0.35).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: size.width * 0.12, y: size.height * 0.10, width: size.width * 0.70, height: size.width * 0.70))
            UIColor(red: 0.96, green: 0.42, blue: 0.20, alpha: 1).withAlphaComponent(0.30).setFill()
            context.cgContext.fillEllipse(in: CGRect(x: size.width * 0.35, y: size.height * 0.42, width: size.width * 0.55, height: size.width * 0.55))

            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .center
            paragraphStyle.lineBreakMode = .byWordWrapping
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: max(24, size.width * 0.045), weight: .semibold),
                .foregroundColor: UIColor.white,
                .paragraphStyle: paragraphStyle
            ]
            let text = prompt.isEmpty ? "Image Studio" : prompt
            let textRect = CGRect(x: size.width * 0.10, y: size.height * 0.40, width: size.width * 0.80, height: size.height * 0.28)
            text.draw(in: textRect, withAttributes: attributes)
        }

        guard let pngData = image.pngData() else {
            throw GenerationError.downloadFailed
        }
        return pngData
    }
}
