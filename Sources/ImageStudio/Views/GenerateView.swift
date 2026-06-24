import SwiftUI
import UIKit

struct GenerateView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var localModelInstaller: LocalModelInstallerStore

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

    private let quickActions = QuickActionPreset.defaults

    var body: some View {
        NavigationStack {
            ZStack {
                studioBackground
                GeometryReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 18) {
                            topBar
                                .padding(.top, 10)

                            heroStage
                                .frame(minHeight: currentImage == nil && !isGenerating ? max(210, proxy.size.height * 0.30) : 320)

                            if let error {
                                ErrorBanner(error: error) {
                                    self.error = nil
                                }
                            }

                            if let savedMessage {
                                savedBanner(savedMessage)
                            }

                            if selectedModel.isLocal && localModelInstaller.state != .installed {
                                localModelStatusCard
                            }

                            promptSurface

                            QuickActionGrid(actions: quickActions) { action in
                                apply(action)
                            }

                            if let currentImage, !isGenerating {
                                resultActions(for: currentImage)
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.bottom, 26)
                        .frame(minHeight: proxy.size.height, alignment: .top)
                    }
                }
            }
            .navigationBarHidden(true)
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
                    .environmentObject(localModelInstaller)
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

    private var studioBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.03, green: 0.04, blue: 0.07),
                    Color(red: 0.07, green: 0.10, blue: 0.16),
                    Color(red: 0.02, green: 0.02, blue: 0.03),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            GeometryReader { proxy in
                Circle()
                    .fill(AppTheme.accent.opacity(0.28))
                    .frame(width: proxy.size.width * 0.90)
                    .blur(radius: 72)
                    .offset(x: proxy.size.width * 0.35, y: proxy.size.height * 0.06)
                Circle()
                    .fill(AppTheme.warmAccent.opacity(0.17))
                    .frame(width: proxy.size.width * 0.70)
                    .blur(radius: 86)
                    .offset(x: -proxy.size.width * 0.24, y: proxy.size.height * 0.42)
            }
            Color.black.opacity(0.24)
        }
        .ignoresSafeArea()
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Image Studio")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(selectedModel.isLocal ? "On-device generation" : "Cloud fallback")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.66))
                    .lineLimit(1)
            }
            Spacer()
            IconButton(systemName: "square.grid.2x2", title: "Gallery") {
                showGallery = true
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            IconButton(systemName: "gearshape", title: "Settings") {
                showSettings = true
            }
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
    }

    @ViewBuilder
    private var heroStage: some View {
        if isGenerating {
            LoadingStateView(prompt: visiblePrompt, onCancel: cancelGeneration)
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding(18)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(glassBorder(cornerRadius: 22))
        } else if let currentImage {
            GeneratedImageFileView(fileURL: historyStore.localURL(for: currentImage))
                .frame(maxWidth: .infinity, minHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(currentImage.width) x \(currentImage.height)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.58), in: Capsule())
                        .padding(12)
                }
                .overlay(glassBorder(cornerRadius: 24))
        } else {
            VStack(spacing: 8) {
                Text("Image Studio")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                Text("Build something visual. Start typing below.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 10)
        }
    }


    private var localModelStatusCard: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: localModelStatusIcon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(localModelStatusTint)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.08), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(localModelStatusTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(localModelStatusMessage)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
                    .lineLimit(3)
            }

            Spacer(minLength: 8)

            localModelStatusAction
        }
        .padding(12)
        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(glassBorder(cornerRadius: AppTheme.cornerRadius))
    }

    private var localModelStatusIcon: String {
        switch localModelInstaller.state {
        case .downloading: return "arrow.down.circle"
        case .unpacking: return "archivebox"
        case .failed: return "exclamationmark.triangle.fill"
        case .missing: return "externaldrive.badge.exclamationmark"
        case .installed: return "checkmark.circle.fill"
        }
    }

    private var localModelStatusTint: Color {
        switch localModelInstaller.state {
        case .failed, .missing:
            return AppTheme.warmAccent
        case .installed:
            return AppTheme.success
        case .downloading, .unpacking:
            return AppTheme.accent
        }
    }

    private var localModelStatusTitle: String {
        switch localModelInstaller.state {
        case .downloading: return "Downloading Local SDXL"
        case .unpacking: return "Installing Local SDXL"
        case .failed: return "Local SDXL install failed"
        case .missing: return "Install Local SDXL"
        case .installed: return "Local SDXL ready"
        }
    }

    private var localModelStatusMessage: String {
        switch localModelInstaller.state {
        case .downloading:
            return "Keep the app open while the 3GB Core ML model downloads."
        case .unpacking:
            return "Unzipping the model. First generation will compile Core ML assets."
        case .failed(let message):
            return message.isEmpty ? "Retry after checking connection and free storage." : message
        case .missing:
            return "Local generation needs about 10GB free for download, extraction, and first compile."
        case .installed:
            return "Ready for on-device generation."
        }
    }

    @ViewBuilder
    private var localModelStatusAction: some View {
        switch localModelInstaller.state {
        case .downloading, .unpacking:
            Button("Cancel", role: .destructive) {
                localModelInstaller.cancel()
            }
            .buttonStyle(.bordered)
        case .missing:
            Button("Install") {
                localModelInstaller.install()
            }
            .buttonStyle(.borderedProminent)
        case .failed:
            Button("Retry") {
                localModelInstaller.install()
            }
            .buttonStyle(.borderedProminent)
        case .installed:
            EmptyView()
        }
    }

    private var promptSurface: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .focused($isPromptFocused)
                    .frame(minHeight: 92, maxHeight: 150)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .scrollContentBackground(.hidden)
                    .background(.clear)

                if prompt.isEmpty {
                    Text("Type your image request...")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                        .padding(.horizontal, 17)
                        .padding(.vertical, 19)
                        .allowsHitTesting(false)
                }
            }

            HStack(spacing: 8) {
                Button {
                    isPromptFocused = true
                } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.80))
                .background(.white.opacity(0.08), in: Circle())
                .accessibilityLabel("Attach reference")

                pickerMenu(title: selectedStyle.title, systemImage: selectedStyle.systemImage) {
                    ForEach(StylePreset.presets) { preset in
                        Button {
                            selectedStyle = preset
                        } label: {
                            Label(preset.title, systemImage: preset.systemImage)
                        }
                    }
                }

                pickerMenu(title: selectedAspect.title, systemImage: selectedAspect.systemImage) {
                    ForEach(AspectPreset.presets) { preset in
                        Button {
                            selectedAspect = preset
                        } label: {
                            Label(preset.title, systemImage: preset.systemImage)
                        }
                    }
                }

                Menu {
                    ForEach(ImageModel.presets) { model in
                        Button {
                            selectedModel = model
                            selectedQuality = settingsStore.defaultQuality(for: model)
                        } label: {
                            Label(model.title, systemImage: "cpu")
                        }
                    }
                    if selectedModel.supportsQuality {
                        Divider()
                        ForEach(selectedModel.supportedQualities) { quality in
                            Button {
                                selectedQuality = quality
                            } label: {
                                Label(quality.title, systemImage: selectedQuality == quality ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                } label: {
                    compactControlLabel(title: selectedModel.title, systemImage: "cpu")
                }

                Spacer(minLength: 4)

                Button(action: generate) {
                    Group {
                        if isGenerating {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 18, weight: .heavy))
                        }
                    }
                    .frame(width: 42, height: 42)
                    .foregroundStyle(.white)
                    .background(canGenerate ? AppTheme.accent : Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(!canGenerate || isGenerating)
                .accessibilityLabel(isGenerating ? "Generating" : "Generate image")
            }
            .padding(12)
        }
        .background(.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(glassBorder(cornerRadius: 18))
    }

    private func pickerMenu<Content: View>(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        Menu(content: content) {
            compactControlLabel(title: title, systemImage: systemImage)
        }
    }

    private func compactControlLabel(title: String, systemImage: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(.white.opacity(0.88))
        .padding(.horizontal, 9)
        .frame(height: 34)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private func glassBorder(cornerRadius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(.white.opacity(0.14), lineWidth: 1)
    }

    private var canGenerate: Bool {
        !prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
            .foregroundStyle(.white)
            .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            .overlay(glassBorder(cornerRadius: AppTheme.cornerRadius))
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
        .foregroundStyle(.white)
        .padding(12)
        .background(.black.opacity(0.34), in: RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .overlay(glassBorder(cornerRadius: AppTheme.cornerRadius))
    }

    private func apply(_ action: QuickActionPreset) {
        prompt = action.prompt
        selectedStyle = action.style
        selectedAspect = action.aspect
        isPromptFocused = true
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
        guard selectedModel.isLocal || settingsStore.hasUserPuterToken else {
            error = .missingPuterConnection
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
        let outputWidth = selectedModel.isLocal ? 768 : selectedAspect.width
        let outputHeight = selectedModel.isLocal ? 768 : selectedAspect.height
        let request = ImageGenerationRequest(
            prompt: composedPrompt,
            model: selectedModel.backendModel,
            quality: quality,
            width: outputWidth,
            height: outputHeight,
            responseFormat: .b64JSON
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

private struct QuickActionPreset: Identifiable {
    var id: String
    var title: String
    var systemImage: String
    var prompt: String
    var style: StylePreset
    var aspect: AspectPreset

    static let defaults: [QuickActionPreset] = [
        QuickActionPreset(id: "app-icon", title: "App Icon", systemImage: "app.badge", prompt: "Minimal iOS app icon for an AI image studio, glossy dark glass, blue accent, no text", style: style("logo"), aspect: aspect("square")),
        QuickActionPreset(id: "wallpaper", title: "Wallpaper", systemImage: "iphone", prompt: "Premium iPhone wallpaper, luminous abstract moonlit landscape, deep contrast, no text", style: style("wallpaper"), aspect: aspect("wallpaper")),
        QuickActionPreset(id: "logo", title: "Logo", systemImage: "seal", prompt: "Clean logo mark for a fast creative AI studio, simple geometry, no text", style: style("logo"), aspect: aspect("square")),
        QuickActionPreset(id: "product", title: "Product Shot", systemImage: "shippingbox", prompt: "Luxury product photo on dark reflective glass, studio lighting, premium composition", style: style("realistic"), aspect: aspect("social-4x5")),
        QuickActionPreset(id: "character", title: "Character", systemImage: "person.crop.circle", prompt: "Original heroic character portrait, dramatic lighting, detailed face, cinematic mood", style: style("cinematic"), aspect: aspect("social-4x5")),
        QuickActionPreset(id: "social", title: "Social Post", systemImage: "rectangle.portrait", prompt: "Eye-catching social media artwork, bold central subject, clean negative space, no text", style: style("cinematic"), aspect: aspect("social-4x5")),
        QuickActionPreset(id: "render", title: "3D Render", systemImage: "cube.transparent", prompt: "Futuristic 3D object render, polished material, soft studio shadows, high detail", style: style("3d"), aspect: aspect("square")),
        QuickActionPreset(id: "cinematic", title: "Cinematic", systemImage: "movieclapper", prompt: "Cinematic neon city at night, rain, reflections, dramatic film still lighting", style: style("cinematic"), aspect: aspect("landscape")),
    ]

    private static func style(_ id: String) -> StylePreset {
        StylePreset.presets.first { $0.id == id } ?? StylePreset.defaultPreset
    }

    private static func aspect(_ id: String) -> AspectPreset {
        AspectPreset.presets.first { $0.id == id } ?? AspectPreset.fallback
    }
}

private struct QuickActionGrid: View {
    var actions: [QuickActionPreset]
    var onSelect: (QuickActionPreset) -> Void

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 9)], spacing: 9) {
            ForEach(actions) { action in
                Button {
                    onSelect(action)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: action.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                        Text(action.title)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .foregroundStyle(.white.opacity(0.86))
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 10)
                    .background(.black.opacity(0.30), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.13), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(action.title)
            }
        }
    }
}
