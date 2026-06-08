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

                    Text("The app downloads Apple's iOS SDXL Core ML archive, unzips it into Application Support, then Core ML compiles it on first use. Keep about 10 GB free.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryInk)
                }

                Section("Puter Account") {
                    if settingsStore.hasUserPuterToken {
                        Label(settingsStore.userPuterUsername.isEmpty ? "Connected" : "Connected as \(settingsStore.userPuterUsername)", systemImage: "checkmark.circle.fill")
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

                    Text("Connect Puter so generation runs on the signed-in user's Puter session instead of the shared server token.")
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
                Button("Clear History", role: .destructive) {
                    historyStore.clear()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }


    @ViewBuilder
    private var localGenerationStatus: some View {
        switch localModelInstaller.state {
        case .installed:
            Label("Local SDXL installed", systemImage: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.success)
        case .downloading:
            Label("Downloading local SDXL model", systemImage: "arrow.down.circle")
                .foregroundStyle(AppTheme.accent)
        case .unpacking:
            Label("Unpacking local SDXL model", systemImage: "archivebox")
                .foregroundStyle(AppTheme.accent)
        case .failed(let message):
            Label(message.isEmpty ? "Local model install failed" : message, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.warmAccent)
        case .missing:
            Label("Local SDXL model missing", systemImage: "externaldrive.badge.exclamationmark")
                .foregroundStyle(AppTheme.warmAccent)
        }
    }

    @ViewBuilder
    private var localGenerationControls: some View {
        switch localModelInstaller.state {
        case .installed:
            Button("Check Model") {
                localModelInstaller.refresh()
            }
        case .downloading, .unpacking:
            HStack {
                ProgressView()
                Button("Cancel", role: .destructive) {
                    localModelInstaller.cancel()
                }
            }
        case .missing:
            Button {
                localModelInstaller.install()
            } label: {
                Label("Install Local SDXL", systemImage: "arrow.down.circle")
            }
        case .failed:
            Button {
                localModelInstaller.install()
            } label: {
                Label("Retry Install", systemImage: "arrow.clockwise")
            }
        }
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
