import SwiftUI
import UIKit

struct GeneratedImageDetailView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @Environment(\.dismiss) private var dismiss

    var image: GeneratedImage
    var onRegenerate: (GeneratedImage) -> Void

    @State private var shareURL: URL?
    @State private var error: GenerationError?
    @State private var savedMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let error {
                    ErrorBanner(error: error) { self.error = nil }
                }
                if let savedMessage {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Text(savedMessage)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(12)
                    .background(AppTheme.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                }

                GeneratedImageFileView(fileURL: historyStore.localURL(for: image))
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                    .background(AppTheme.panelBackground)

                actionGrid

                VStack(alignment: .leading, spacing: 10) {
                    Text("Prompt")
                        .font(.headline)
                    Text(image.revisedPrompt ?? image.prompt)
                        .font(.body)
                        .textSelection(.enabled)
                    Divider()
                    metadataRow("Model", image.model)
                    if let quality = image.quality {
                        metadataRow("Quality", quality)
                    }
                    metadataRow("Size", "\(image.width) x \(image.height)")
                    metadataRow("Created", image.createdAt.formatted(date: .abbreviated, time: .shortened))
                }
                .padding(14)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            }
            .padding(16)
        }
        .background(AppTheme.pageBackground)
        .navigationTitle("Image")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { shareURL != nil },
            set: { if !$0 { shareURL = nil } }
        )) {
            if let shareURL {
                ShareSheet(activityItems: [shareURL])
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
            detailButton("Save", systemImage: "square.and.arrow.down") { save() }
            detailButton("Share", systemImage: "square.and.arrow.up") {
                shareURL = historyStore.localURL(for: image)
            }
            detailButton("Copy Prompt", systemImage: "doc.on.doc") {
                UIPasteboard.general.string = image.revisedPrompt ?? image.prompt
                savedMessage = "Prompt copied"
            }
            detailButton("Regenerate", systemImage: "arrow.clockwise") {
                onRegenerate(image)
                dismiss()
            }
            detailButton("Delete", systemImage: "trash", role: .destructive) {
                historyStore.delete(image)
                dismiss()
            }
        }
    }

    private func detailButton(
        _ title: String,
        systemImage: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .foregroundStyle(AppTheme.secondaryInk)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
        }
        .font(.subheadline)
    }

    private func save() {
        let fileURL = historyStore.localURL(for: image)
        Task {
            do {
                try await environment.photoLibrarySaver.saveImage(at: fileURL)
                await MainActor.run { savedMessage = "Saved to Photos" }
            } catch {
                await MainActor.run {
                    self.error = error as? GenerationError ?? .unknown(error.localizedDescription)
                }
            }
        }
    }
}
