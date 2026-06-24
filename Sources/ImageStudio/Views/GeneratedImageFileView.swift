import SwiftUI
import UIKit

struct GeneratedImageFileView: View {
    var fileURL: URL
    var contentMode: ContentMode = .fit

    var body: some View {
        if let image = UIImage(contentsOfFile: fileURL.path) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
                .accessibilityLabel("Generated image")
        } else {
            UnavailableImageView()
        }
    }
}

struct UnavailableImageView: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo")
                .font(.largeTitle)
            Text("Image unavailable")
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(AppTheme.secondaryInk)
        .frame(maxWidth: .infinity, minHeight: 220)
    }
}
