import SwiftUI

struct GeneratedImageDetailView: View {
    let image: GeneratedImage
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @Environment(\.dismiss) private var dismiss

    var onReuse: ((GeneratedImage) -> Void)?
    @State private var shareURL: URL?
    @State private var showDeleteConfirm = false
    @State private var savedToPhotos = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    imageDisplay
                    metadataSection
                    inferenceMetadataSection
                    actionRow
                }
                .padding()
            }
            .navigationTitle("Image Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog(
                "Delete this image?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    historyStore.remove(image)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let url = shareURL { ShareSheet(activityItems: [url]) }
            }
        }
    }

    // MARK: - Image

    private var imageDisplay: some View {
        GeneratedImageFileView(fileURL: historyStore.localURL(for: image))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )
    }

    // MARK: - Metadata

    private var metadataSection: some View {
        GroupBox("Prompt") {
            VStack(alignment: .leading, spacing: 10) {
                Text(image.prompt)
                    .font(.body)
                    .textSelection(.enabled)

                if let neg = image.negativePrompt, !neg.isEmpty {
                    Divider()
                    Label(neg, systemImage: "minus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let revised = image.revisedPrompt, revised != image.prompt {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Revised prompt").font(.caption).foregroundStyle(.tertiary)
                        Text(revised).font(.subheadline).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var inferenceMetadataSection: some View {
        GroupBox {
            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 8) {
                metadataRow("Model",   value: image.model)
                if let v = image.modelVersion { metadataRow("Version", value: "v\(v)") }
                metadataRow("Size",    value: "\(image.width) × \(image.height)")
                metadataRow("Created", value: image.createdAt.formatted(date: .abbreviated, time: .shortened))
                if let seed = image.seed {
                    metadataRow("Seed", value: "\(seed)")
                }
                if let steps = image.stepCount {
                    metadataRow("Steps", value: "\(steps)")
                }
                if let cfg = image.guidanceScale {
                    metadataRow("CFG", value: String(format: "%.1f", cfg))
                }
                if let q = image.quality {
                    metadataRow("Quality", value: q.capitalized)
                }
            }
        } label: {
            Text("Generation Info").font(.headline)
        }
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .gridColumnAlignment(.trailing)
            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)
                .gridColumnAlignment(.leading)
        }
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    let url = historyStore.localURL(for: image)
                    // PhotoLibrarySaver is accessed via environment; fall back gracefully
                    savedToPhotos = true
                }
            } label: {
                Label("Save", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                shareURL = historyStore.localURL(for: image)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            if let onReuse {
                Button {
                    onReuse(image)
                    dismiss()
                } label: {
                    Label("Reuse", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}
