import SwiftUI

struct GalleryView: View {
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @Environment(\.dismiss) private var dismiss

    var onRegenerate: (GeneratedImage) -> Void
    @State private var selectedImage: GeneratedImage?

    private let columns = [
        GridItem(.adaptive(minimum: 150), spacing: 12)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if historyStore.images.isEmpty {
                    ContentUnavailableView(
                        "No Images Yet",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Generated images are saved here automatically.")
                    )
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(historyStore.images) { image in
                                Button {
                                    selectedImage = image
                                } label: {
                                    GalleryCell(image: image, fileURL: historyStore.localURL(for: image))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .background(AppTheme.pageBackground)
                }
            }
            .navigationTitle("Gallery")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(item: $selectedImage) { image in
                GeneratedImageDetailView(image: image) { image in
                    onRegenerate(image)
                }
            }
        }
    }
}

private struct GalleryCell: View {
    var image: GeneratedImage
    var fileURL: URL

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeneratedImageFileView(fileURL: fileURL, contentMode: .fill)
                .frame(height: 168)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            Text(image.revisedPrompt ?? image.prompt)
                .font(.caption.weight(.semibold))
                .lineLimit(2)
                .foregroundStyle(AppTheme.ink)
            Text(image.createdAt, style: .date)
                .font(.caption2)
                .foregroundStyle(AppTheme.secondaryInk)
        }
        .padding(8)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }
}
