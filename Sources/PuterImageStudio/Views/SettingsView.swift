import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @Environment(\.dismiss) private var dismiss
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

                Section("Puter Account") {
                    SecureField("Auth token", text: $settingsStore.userPuterAuthToken)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .privacySensitive()

                    if !settingsStore.userPuterAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Clear Puter Token", role: .destructive) {
                            settingsStore.userPuterAuthToken = ""
                        }
                    }

                    Link("Copy token from Puter dashboard", destination: URL(string: "https://puter.com/dashboard#account")!)
                    Text("Using your own Puter token avoids the shared server token and lets Puter bill usage to your Puter account/session.")
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

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
