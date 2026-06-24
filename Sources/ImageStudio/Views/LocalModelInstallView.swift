import SwiftUI

/// Full-screen install sheet presented from GenerateView or ModelPickerView.
struct LocalModelInstallView: View {
    @EnvironmentObject private var installer: LocalModelInstallerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        ringSection
                        infoSection
                        actionSection
                    }
                    .padding()
                }
            }
            .navigationTitle("Local SDXL Model")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    // MARK: - Ring

    private var ringSection: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.20), lineWidth: 10)
                .frame(width: 140, height: 140)

            Circle()
                .trim(from: 0, to: installer.state.overallProgress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 140, height: 140)
                .animation(.linear(duration: 0.4), value: installer.state.overallProgress)

            VStack(spacing: 4) {
                Image(systemName: ringIcon)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ringColor)
                if installer.state.isBusy {
                    Text("\(Int(installer.state.overallProgress * 100))%")
                        .font(.headline.monospacedDigit())
                }
            }
        }
        .padding(.top, 8)
    }

    private var ringIcon: String {
        switch installer.state {
        case .missing:                          return "arrow.down.circle"
        case .active(let p, _, _, _, _):
            switch p {
            case .downloading:                  return "arrow.down.circle.fill"
            case .verifyingArchive:             return "checkmark.shield.fill"
            case .extracting:                   return "archivebox.fill"
            case .validatingFiles:              return "doc.badge.gearshape.fill"
            case .activating:                   return "bolt.circle.fill"
            case .rollingBack:                  return "arrow.uturn.backward.circle.fill"
            case .queued:                       return "clock.fill"
            }
        case .installed:                        return "checkmark.circle.fill"
        case .failed:                           return "exclamationmark.triangle.fill"
        }
    }

    private var ringColor: Color {
        switch installer.state {
        case .installed:  return .green
        case .failed:     return .orange
        case .missing:    return .secondary
        case .active:     return AppTheme.accent
        }
    }

    // MARK: - Info

    private var infoSection: some View {
        VStack(spacing: 8) {
            Text(phaseTitle)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            Text(phaseSubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            // Speed + ETA badges (during download)
            if installer.state.isBusy {
                HStack(spacing: 12) {
                    if installer.state.speedBytesPerSec > 0 {
                        Label(
                            ByteCountFormatter.string(fromByteCount: Int64(installer.state.speedBytesPerSec), countStyle: .file) + "/s",
                            systemImage: "arrow.down"
                        )
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(.thinMaterial, in: Capsule())
                    }
                    if let eta = installer.state.etaSeconds {
                        Label(etaLabel(eta), systemImage: "clock")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(.thinMaterial, in: Capsule())
                    }
                }
            }

            // Phase progress bar (shows current-phase granularity)
            if installer.state.isBusy {
                ProgressView(value: installer.state.phaseProgress)
                    .tint(AppTheme.accent)
                    .animation(.linear(duration: 0.3), value: installer.state.phaseProgress)
            }

            // Resume indicator
            if case .missing = installer.state, installer.hasResumeData {
                Label("Partial download found — will resume", systemImage: "arrow.counterclockwise")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal)
    }

    private var phaseTitle: String {
        switch installer.state {
        case .missing:
            if let entry = installer.modelEntry {
                return "\(entry.title) · \(entry.version)"
            }
            return "Local SDXL Model"
        case .active(let phase, _, _, _, _): return phase.displayTitle
        case .installed(let version):        return "Installed · v\(version)"
        case .failed(let e):                 return e.errorDescription ?? "Install failed"
        }
    }

    private var phaseSubtitle: String {
        switch installer.state {
        case .missing:
            if let entry = installer.modelEntry {
                return "Requires \(entry.requiredFreeSpaceDescription) free storage. Connect to Wi-Fi before starting."
            }
            return "Requires ~10 GB free storage."
        case .active(let phase, _, _, _, _):
            switch phase {
            case .downloading:      return "Keep the app open while downloading. The download resumes if interrupted."
            case .verifyingArchive: return "Checking archive integrity…"
            case .extracting:       return "Unzipping Core ML model files…"
            case .validatingFiles:  return "Confirming all model components are present…"
            case .activating:       return "Performing final activation…"
            case .rollingBack:      return "Something went wrong. Cleaning up…"
            case .queued:           return "Waiting to start…"
            }
        case .installed:
            return "Ready for on-device generation. No internet or credits needed."
        case .failed(let e):
            return e.recoverySuggestion ?? "Check your connection and storage, then retry."
        }
    }

    // MARK: - Actions

    private var actionSection: some View {
        VStack(spacing: 12) {
            switch installer.state {
            case .missing:
                Button(action: { installer.install() }) {
                    Label(installer.hasResumeData ? "Resume Download" : "Download & Install",
                          systemImage: installer.hasResumeData ? "arrow.counterclockwise" : "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

            case .active:
                Button(role: .destructive, action: { installer.cancel() }) {
                    Label("Cancel Installation", systemImage: "xmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .installed:
                Button(role: .destructive, action: {
                    installer.deleteInstall()
                }) {
                    Label("Remove Model", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

            case .failed(let e):
                if e.isRetryable {
                    Button(action: { installer.install() }) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button(action: {
                        installer.deleteInstall()
                        installer.install()
                    }) {
                        Label("Reinstall", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .padding(.horizontal)
    }

    private func etaLabel(_ s: Double) -> String {
        if s < 60 { return "\(Int(s))s" }
        return "\(Int(s / 60))m \(Int(s) % 60)s"
    }
}

private extension LocalModelInstallPhase {
    var displayTitle: String {
        switch self {
        case .queued:           return "Queued…"
        case .downloading:      return "Downloading"
        case .verifyingArchive: return "Verifying Archive"
        case .extracting:       return "Extracting Files"
        case .validatingFiles:  return "Validating Install"
        case .activating:       return "Activating Model"
        case .rollingBack:      return "Rolling Back"
        }
    }
}
