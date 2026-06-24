import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var historyStore: GenerationHistoryStore
    @EnvironmentObject private var localModelInstaller: LocalModelInstallerStore

    @State private var showClearHistoryConfirm = false
    @State private var showInstaller = false
    @State private var showDeleteModelConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                localModelSection
                defaultsSection
                historySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showInstaller) {
                LocalModelInstallView()
                    .environmentObject(localModelInstaller)
            }
            .confirmationDialog(
                "Remove the installed SDXL model?",
                isPresented: $showDeleteModelConfirm,
                titleVisibility: .visible
            ) {
                Button("Remove Model", role: .destructive) {
                    localModelInstaller.deleteInstall()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - Local model section

    private var localModelSection: some View {
        Section {
            // Phase row
            HStack(spacing: 12) {
                ZStack {
                    if localModelInstaller.state.isBusy {
                        Circle()
                            .stroke(Color.secondary.opacity(0.20), lineWidth: 2.5)
                            .frame(width: 32, height: 32)
                        Circle()
                            .trim(from: 0, to: activeOverallProgress)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 32, height: 32)
                            .animation(.linear(duration: 0.3), value: activeOverallProgress)
                    }
                    Image(systemName: statusIcon)
                        .font(.system(size: localModelInstaller.state.isBusy ? 12 : 16, weight: .semibold))
                        .foregroundStyle(statusTint)
                }
                .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle).font(.body.weight(.semibold))
                    Text(statusSubtitle).font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if localModelInstaller.state.isBusy {
                    ProgressView()
                }
            }

            // Action button row
            switch localModelInstaller.state {
            case .missing:
                Button {
                    showInstaller = true
                } label: {
                    Label(
                        localModelInstaller.hasResumeData ? "Resume Download" : "Download & Install",
                        systemImage: "arrow.down.circle"
                    )
                }

            case .active:
                Button(role: .destructive) {
                    localModelInstaller.cancel()
                } label: {
                    Label("Cancel Installation", systemImage: "xmark.circle")
                }

            case .installed:
                Button(role: .destructive) {
                    showDeleteModelConfirm = true
                } label: {
                    Label("Remove Model", systemImage: "trash")
                }
                .foregroundStyle(.red)

            case .failed(let e):
                Button {
                    if e.isRetryable {
                        localModelInstaller.install()
                    } else {
                        showInstaller = true
                    }
                } label: {
                    Label(e.isRetryable ? "Retry" : "Reinstall", systemImage: "arrow.clockwise")
                }
            }

        } header: {
            Text("On-Device Model")
        } footer: {
            if let entry = localModelInstaller.modelEntry {
                Text("SDXL Base v\(entry.version) · Requires \(entry.requiredFreeSpaceDescription) free during install · Runs fully offline after setup.")
            } else {
                Text("Runs fully offline after setup.")
            }
        }
    }

    /// Extract `overallProgress` from the `.active` enum case; 0 otherwise.
    private var activeOverallProgress: Double {
        if case .active(_, _, let overall, _, _) = localModelInstaller.state {
            return overall
        }
        return 0
    }

    private var statusIcon: String {
        switch localModelInstaller.state {
        case .missing:                        return "externaldrive.badge.plus"
        case .active(let p, _, _, _, _):
            switch p {
            case .downloading:                return "arrow.down.circle.fill"
            case .verifyingArchive:           return "checkmark.shield"
            case .extracting:                 return "archivebox"
            case .validatingFiles:            return "doc.badge.gearshape"
            case .activating:                 return "bolt.circle"
            case .rollingBack:                return "arrow.uturn.backward.circle"
            case .queued:                     return "clock"
            }
        case .installed:                      return "checkmark.circle.fill"
        case .failed:                         return "exclamationmark.triangle.fill"
        }
    }

    private var statusTint: Color {
        switch localModelInstaller.state {
        case .installed:          return .green
        case .failed, .missing:   return .orange
        case .active:             return .accentColor
        }
    }

    private var statusTitle: String {
        switch localModelInstaller.state {
        case .missing:                       return "SDXL Base — Not Installed"
        case .active(let p, _, let o, _, _): return "\(p.settingsLabel) · \(Int(o * 100))%"
        case .installed(let v):              return "SDXL Base v\(v) — Installed"
        case .failed(let e):                 return e.errorDescription ?? "Install Failed"
        }
    }

    private var statusSubtitle: String {
        switch localModelInstaller.state {
        case .missing:
            return "On-device generation · No credits needed"
        case .active(_, _, _, let speed, let eta):
            var parts: [String] = []
            if speed > 0 {
                parts.append(ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s")
            }
            if let eta {
                parts.append(eta < 60 ? "\(Int(eta))s left" : "\(Int(eta/60))m \(Int(eta)%60)s left")
            }
            return parts.joined(separator: " · ")
        case .installed:
            return "Ready · Fully offline"
        case .failed(let e):
            return e.recoverySuggestion ?? "Tap to retry"
        }
    }

    // MARK: - Defaults section

    private var defaultsSection: some View {
        Section("Generation Defaults") {
            Picker("Default Model", selection: Binding(
                get: { settingsStore.defaultModel },
                set: { settingsStore.defaultModelID = $0.id }
            )) {
                ForEach(ImageModel.presets) { model in
                    Text(model.title).tag(model)
                }
            }

            if settingsStore.defaultModel.supportsQuality {
                Picker("Default Quality", selection: Binding(
                    get: { settingsStore.defaultQuality(for: settingsStore.defaultModel) ?? .low },
                    set: { settingsStore.setDefaultQuality($0, for: settingsStore.defaultModel) }
                )) {
                    ForEach(settingsStore.defaultModel.supportedQualities) { q in
                        Text(q.title).tag(Optional(q))
                    }
                }
            }
        }
    }

    // MARK: - History section

    private var historySection: some View {
        Section("History") {
            HStack {
                Text("Saved images")
                Spacer()
                Text("\(historyStore.images.count)")
                    .foregroundStyle(.secondary)
            }
            Button("Clear All History", role: .destructive) {
                showClearHistoryConfirm = true
            }
            .confirmationDialog(
                "Delete all \(historyStore.images.count) generated images?",
                isPresented: $showClearHistoryConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear History", role: .destructive) { historyStore.clear() }
                Button("Cancel", role: .cancel) {}
            }
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Local Model Engine", value: "Apple Core ML · Split Einsum")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(v) (\(b))"
    }
}

private extension LocalModelInstallPhase {
    var settingsLabel: String {
        switch self {
        case .queued:           return "Queued"
        case .downloading:      return "Downloading"
        case .verifyingArchive: return "Verifying"
        case .extracting:       return "Extracting"
        case .validatingFiles:  return "Validating"
        case .activating:       return "Activating"
        case .rollingBack:      return "Rolling Back"
        }
    }
}
