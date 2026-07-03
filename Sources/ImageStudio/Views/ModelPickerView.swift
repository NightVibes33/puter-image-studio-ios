import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: ImageModel
    @EnvironmentObject private var installerStore: LocalModelInstallerStore
    @State private var showInstaller = false

    var body: some View {
        List {
            Section("On-Device") {
                ForEach(ImageModel.localModels) { model in
                    modelRow(model)
                }
            }
        }
        .navigationTitle("Local Model")
        .sheet(isPresented: $showInstaller) {
            LocalModelInstallView()
                .environmentObject(installerStore)
        }
    }

    @ViewBuilder
    private func modelRow(_ model: ImageModel) -> some View {
        Button {
            selectedModel = model
            switch installerStore.state {
            case .missing:
                showInstaller = true
            case .unsupportedDevice:
                break
            default:
                break
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "cpu")
                    .frame(width: 28)
                    .foregroundStyle(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title).font(.body.weight(.semibold))
                    Text(model.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                localStateBadge

                if selectedModel.id == model.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(AppTheme.accent)
                        .font(.body.weight(.bold))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
        case .unsupportedDevice:
            Text("Unsupported")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 7).padding(.vertical, 3)
                .background(.orange.opacity(0.15), in: Capsule())
                .foregroundStyle(.orange)
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
