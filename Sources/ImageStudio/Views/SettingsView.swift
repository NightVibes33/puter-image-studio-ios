import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @EnvironmentObject private var localModelInstaller: LocalModelInstallerStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var showClearConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Defaults") {
                    Picker("Model", selection: $settingsStore.defaultModelID) {
                        ForEach(ImageModel.presets) { model in
                            Text(model.title).tag(model.id)
                        }
                    }

                    let model = ImageModel.preset(id: settingsStore.defaultModelID)
                    if model.supportsQuality {
                        Picker("Quality", selection: Binding(
                            get: { settingsStore.defaultQuality(for: model) ?? model.defaultQuality ?? model.supportedQualities[0] },
                            set: { settingsStore.setDefaultQuality($0) }
                        )) {
                            ForEach(model.supportedQualities) { quality in
                                Text(quality.title).tag(quality)
                            }
                        }
                    }
                }

                Section("Local Generation") {
                    localGenerationStatus
                    localGenerationControls
                    Link("Model source", destination: LocalStableDiffusionModelStore.downloadURL)
                    Text("Downloads Apple\u2019s iOS SDXL Core ML model (~4 GB zip, ~10 GB installed). Keep ~10 GB free. Core ML compiles on first use.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Section("Puter Account") {
                    if settingsStore.hasUserPuterToken {
                        Label(settingsStore.userPuterUsername.isEmpty
                              ? "Connected"
                              : "Connected as \(settingsStore.userPuterUsername)",
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.success)
                        Button("Disconnect Puter", role: .destructive) {
                            settingsStore.clearPuterConnection()
                        }
                    } else {
                        Button {
                            openURL(settingsStore.puterAuthURL)
                        } label: {
                            Label("Connect Puter", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                    DisclosureGroup("Advanced token") {
                        SecureField("Auth token", text: $settingsStore.userPuterAuthToken)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .privacySensitive()
                    }
                    Text("Connect Puter so generation runs on the signed-in user\u2019s Puter session instead of the shared server token.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Section("Library") {
                    Button("Clear History", role: .destructive) {
                        showClearConfirmation = true
                    }
                    .disabled(historyStore.images.isEmpty)
                }

                Section("Privacy") {
                    Text("Prompts and generated images are sent to the generation service and AI providers as needed.")
                    Link("Privacy Policy", destination: settingsStore.privacyPolicyURL)
                    Link("Terms", destination: settingsStore.termsURL)
                }

                Section("Support") {
                    Link("GitHub Issues", destination: settingsStore.supportURL)
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog("Clear all generated images?", isPresented: $showClearConfirmation, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { historyStore.clear() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Local Generation Status

    @ViewBuilder
    private var localGenerationStatus: some View {
        switch localModelInstaller.state {
        case .installed:
            Label("Local SDXL installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)

        case .active(let phase, let progress, let speed, let eta):
            VStack(alignment: .leading, spacing: 6) {
                Label(phaseLabel(phase), systemImage: phaseIcon(phase))
                    .foregroundStyle(AppTheme.accent)

                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.25), value: progress)

                HStack {
                    if phase == .download {
                        Text(formatProgress(localModelInstaller))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryInk)
                        Spacer()
                        if speed > 0 {
                            Text(formatSpeed(speed))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                        if let eta, eta > 1 {
                            Text("\u2022 " + formatETA(eta))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(AppTheme.secondaryInk)
                        }
                    } else {
                        Text(String(format: "%.0f%%", progress * 100))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                }
            }
            .padding(.vertical, 2)

        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warmAccent)

        case .missing:
            Label("Local SDXL not installed", systemImage: "externaldrive.badge.exclamationmark")
                .foregroundStyle(AppTheme.secondaryInk)
        }
    }

    // MARK: - Local Generation Controls

    @ViewBuilder
    private var localGenerationControls: some View {
        switch localModelInstaller.state {
        case .installed:
            Button("Verify Model") { localModelInstaller.refresh() }

        case .active:
            Button("Pause & Save Progress", role: .destructive) {
                localModelInstaller.cancel()
            }

        case .missing:
            Button {
                localModelInstaller.install()
            } label: {
                // Show "Resume" if there is saved resume data
                let hasResume = UserDefaults.standard.data(forKey: "localModelResumeData") != nil
                Label(hasResume ? "Resume Download" : "Install Local SDXL",
                      systemImage: hasResume ? "arrow.clockwise" : "arrow.down.circle")
            }

        case .failed:
            Button {
                localModelInstaller.install()
            } label: {
                Label("Retry Install", systemImage: "arrow.clockwise")
            }
        }
    }

    // MARK: - Helpers

    private func phaseLabel(_ phase: LocalModelInstallPhase) -> String {
        switch phase {
        case .download: return "Downloading model\u2026"
        case .unzip:    return "Unpacking\u2026"
        case .move:     return "Finalising\u2026"
        }
    }

    private func phaseIcon(_ phase: LocalModelInstallPhase) -> String {
        switch phase {
        case .download: return "arrow.down.circle"
        case .unzip:    return "archivebox"
        case .move:     return "arrow.right.circle"
        }
    }

    private func formatProgress(_ store: LocalModelInstallerStore) -> String {
        let written = store.bytesWrittenForUI
        let expected = store.bytesExpectedForUI
        if expected > 0 {
            return "\(formatBytes(written)) / \(formatBytes(expected))"
        }
        return formatBytes(written)
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.2f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.1f MB", mb)
    }

    private func formatSpeed(_ bps: Double) -> String {
        let mbs = bps / 1_048_576
        if mbs >= 1 { return String(format: "%.1f MB/s", mbs) }
        return String(format: "%.0f KB/s", bps / 1024)
    }

    private func formatETA(_ seconds: Double) -> String {
        let s = Int(seconds)
        if s < 60  { return "\(s)s left" }
        if s < 3600 { return "\(s / 60)m left" }
        return "\(s / 3600)h \((s % 3600) / 60)m left"
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
