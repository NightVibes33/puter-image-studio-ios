import SwiftUI
import UIKit

struct GenerateView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @EnvironmentObject private var settingsStore: AppSettingsStore

    @State private var prompt = ""
    @State private var selectedStyle = StylePreset.defaultPreset
    @State private var selectedAspect = AspectPreset.fallback
    @State private var selectedModel = ImageModel.fallback
    @State private var selectedQuality: ImageQuality? = .low
    @State private var currentImage: GeneratedImage?
    @State private var isGenerating = false
    @State private var visiblePrompt = ""
    @State private var generationTask: Task<Void, Never>?
    @State private var error: GenerationError?
    @State private var showGallery = false
    @State private var showSettings = false
    @State private var shareURL: URL?
    @State private var savedMessage: String?
    @State private var didLoadSettings = false
    @FocusState private var isPromptFocused: Bool

    private let recentPrompts = [
        "Cinematic neon city at night",
        "Minimal app icon for a weather app",
        "Cozy cabin wallpaper at sunrise",
        "Retro robot mascot, clean background"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.pageBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        topBar
                        if let error {
                            ErrorBanner(error: error) {
                                self.error = nil
                            }
                        }
                        if let savedMessage {
                            savedBanner(savedMessage)
                        }
                        previewArea
                        PromptComposerView(
                            prompt: $prompt,
                            maxCharacters: settingsStore.promptMaxCharacters,
                            isFocused: $isPromptFocused
                        )
                        StylePresetGrid(selectedStyle: $selectedStyle)
                        AspectPickerView(selectedAspect: $selectedAspect)
                        ModelPickerView(selectedModel: $selectedModel, selectedQuality: $selectedQuality)
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 104)
                }
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                PrimaryButton(
                    title: isGenerating ? "Generating" : "Generate",
                    systemImage: "sparkles",
                    isLoading: isGenerating,
                    isDisabled: prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    generate()
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 10)
                .background(.regularMaterial)
            }
            .sheet(isPresented: $showGallery) {
                GalleryView { image in
                    prompt = image.revisedPrompt ?? image.prompt
                    currentImage = image
                    showGallery = false
                    generate()
                }
                .environmentObject(environment)
                .environmentObject(historyStore)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .environmentObject(settingsStore)
                    .environmentObject(historyStore)
            }
            .sheet(isPresented: Binding(
                get: { shareURL != nil },
                set: { if !$0 { shareURL = nil } }
            )) {
                if let shareURL {
                    ShareSheet(activityItems: [shareURL])
                }
            }
            .onAppear(perform: loadSettingsOnce)
            .onDisappear {
                generationTask?.cancel()
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Image Studio")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .minimumScaleFactor(0.60)
                    .lineLimit(1)
                    .allowsTightening(true)
                Text("AI image studio")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(AppTheme.secondaryInk)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            IconButton(systemName: "square.grid.2x2", title: "Gallery") {
                showGallery = true
            }
            IconButton(systemName: "gearshape", title: "Settings") {
                showSettings = true
            }
        }
    }

    @ViewBuilder
    private var previewArea: some View {
        VStack(spacing: 12) {
            Group {
                if isGenerating {
                    LoadingStateView(prompt: visiblePrompt, onCancel: cancelGeneration)
                } else if let currentImage {
                    GeneratedImageFileView(fileURL: historyStore.localURL(for: currentImage))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Text("\(currentImage.width) x \(currentImage.height)")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.black.opacity(0.55))
                                .clipShape(Capsule())
                                .padding(10)
                        }
                } else {
                    emptyPreview
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 260)
            .background(AppTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))

            if let currentImage, !isGenerating {
                resultActions(for: currentImage)
            }
        }
    }

    private var emptyPreview: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.16))
                    .frame(width: 132, height: 132)
                Circle()
                    .fill(AppTheme.warmAccent.opacity(0.18))
                    .frame(width: 92, height: 92)
                    .offset(x: 38, y: 24)
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            VStack(spacing: 6) {
                Text("Create an image")
                    .font(.title3.bold())
                Text("Prompt, style, generate.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryInk)
                    .multilineTextAlignment(.center)
            }
            FlowChips(items: recentPrompts) { chip in
                prompt = chip
                isPromptFocused = true
            }
        }
        .padding(18)
    }

    private func resultActions(for image: GeneratedImage) -> some View {
        HStack(spacing: 8) {
            actionButton(title: "Save", systemImage: "square.and.arrow.down") {
                save(image)
            }
            actionButton(title: "Share", systemImage: "square.and.arrow.up") {
                shareURL = historyStore.localURL(for: image)
            }
            actionButton(title: "Regenerate", systemImage: "arrow.clockwise") {
                prompt = image.revisedPrompt ?? image.prompt
                generate()
            }
            actionButton(title: "Edit", systemImage: "slider.horizontal.3") {}
                .disabled(true)
                .opacity(0.55)
        }
    }

    private func actionButton(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.headline)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background(AppTheme.panelBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func savedBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
            Text(message)
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(12)
        .background(AppTheme.panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
    }

    private func loadSettingsOnce() {
        guard !didLoadSettings else { return }
        didLoadSettings = true
        selectedModel = settingsStore.defaultModel
        selectedQuality = settingsStore.defaultQuality(for: selectedModel)
    }

    private func generate() {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            error = .emptyPrompt
            return
        }
        guard trimmedPrompt.count <= settingsStore.promptMaxCharacters else {
            error = .promptTooLong(maxCharacters: settingsStore.promptMaxCharacters)
            return
        }

        generationTask?.cancel()
        isPromptFocused = false
        error = nil
        savedMessage = nil
        isGenerating = true

        let composedPrompt = selectedStyle.apply(to: trimmedPrompt)
        visiblePrompt = trimmedPrompt
        let quality = selectedModel.supportsQuality ? selectedQuality?.rawValue : nil
        let request = ImageGenerationRequest(
            prompt: composedPrompt,
            model: selectedModel.backendModel,
            quality: quality,
            width: selectedAspect.width,
            height: selectedAspect.height
        )
        let client = environment.imageClient
        let store = historyStore

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        generationTask = Task {
            do {
                let image = try await client.generate(request)
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    currentImage = image
                    store.add(image)
                    isGenerating = false
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    guard !Task.isCancelled else { return }
                    isGenerating = false
                    self.error = error as? GenerationError ?? .unknown(error.localizedDescription)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }

    private func cancelGeneration() {
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        error = .cancelled
    }

    private func save(_ image: GeneratedImage) {
        let fileURL = historyStore.localURL(for: image)
        Task {
            do {
                try await environment.photoLibrarySaver.saveImage(at: fileURL)
                await MainActor.run {
                    savedMessage = "Saved to Photos"
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    self.error = error as? GenerationError ?? .unknown(error.localizedDescription)
                    UINotificationFeedbackGenerator().notificationOccurred(.error)
                }
            }
        }
    }
}

private struct FlowChips: View {
    var items: [String]
    var onSelect: (String) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], spacing: 8) {
            ForEach(items, id: \.self) { item in
                Button {
                    onSelect(item)
                } label: {
                    Text(item)
                        .font(.caption.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 42)
                        .padding(.horizontal, 8)
                        .background(AppTheme.elevatedBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }
}
