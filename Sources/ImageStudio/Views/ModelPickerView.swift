import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: ImageModel
    @Binding var selectedQuality: ImageQuality?
    @EnvironmentObject private var installerStore: LocalModelInstallerStore
    @State private var showInstaller = false

    var body: some View {
        List {
            Section("On-Device") {
                ForEach(ImageModel.localModels) { model in
                    modelRow(model)
                }
            }
            Section("Cloud") {
                ForEach(ImageModel.presets.filter { !$0.isLocal }) { model in
                    modelRow(model)
                }
            }
        }
        .navigationTitle("Choose Model")
        .sheet(isPresented: $showInstaller) {
            LocalModelInstallView()
                .environmentObject(installerStore)
        }
    }

    @ViewBuilder
    private func modelRow(_ model: ImageModel) -> some View {
        Button {
            selectedModel = model
            selectedQuality = model.defaultQuality
            // Trigger installer sheet if local model not yet installed
            if model.isLocal {
                if case .missing = installerStore.state { showInstaller = true }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: model.isLocal ? "cpu" : "cloud")
                    .frame(width: 28)
                    .foregroundStyle(model.isLocal ? .green : .blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title).font(.body.weight(.semibold))
                    Text(model.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Local install state chip
                if model.isLocal {
                    localStateBadge
                }

                if selectedModel.id == model.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.accent)
                        .font(.body.weight(.bold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)

        // Quality picker inline for selected cloud model with quality support
        if selectedModel.id == model.id && model.supportsQuality {
            ForEach(model.supportedQualities) { quality in
                Button {
                    selectedQuality = quality
                } label: {
                    HStack {
                        Text(quality.title)
                            .font(.subheadline)
                            .padding(.leading, 40)
                        Spacer()
                        if selectedQuality == quality {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppTheme.accent)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var localStateBadge: some View {
        switch installerStore.state {
        case .installed(let version):
            Text("v\(version)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.green.opacity(0.15), in: Capsule())
                .foregroundStyle(.green)
        case .active(let phase, _, let overall, _, _):
            HStack(spacing: 4) {
                ProgressView(value: overall)
                    .progressViewStyle(.circular)
                    .scaleEffect(0.65)
                Text(phase.shortLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        case .failed:
            Text("Failed")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
        case .missing:
            Text("Not installed")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

private extension LocalModelInstallPhase {
    var shortLabel: String {
        switch self {
        case .queued:           return "Queued"
        case .downloading:      return "DL"
        case .verifyingArchive: return "Verify"
        case .extracting:       return "Unzip"
        case .validatingFiles:  return "Check"
        case .activating:       return "Activate"
        case .rollingBack:      return "Rollback"
        }
    }
}
