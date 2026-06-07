import SwiftUI

struct ModelPickerView: View {
    @Binding var selectedModel: ImageModel
    @Binding var selectedQuality: ImageQuality?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Model")
                .font(.headline)
            Menu {
                ForEach(ImageModel.presets) { model in
                    Button {
                        selectedModel = model
                        selectedQuality = model.defaultQuality
                    } label: {
                        Label(model.title, systemImage: selectedModel.id == model.id ? "checkmark" : "circle")
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "cpu")
                        .font(.headline)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedModel.title)
                            .font(.subheadline.weight(.semibold))
                        Text(selectedModel.subtitle)
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.secondaryInk)
                }
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if selectedModel.supportsQuality {
                Picker("Quality", selection: Binding(
                    get: { selectedQuality ?? selectedModel.defaultQuality ?? selectedModel.supportedQualities[0] },
                    set: { selectedQuality = $0 }
                )) {
                    ForEach(selectedModel.supportedQualities) { quality in
                        Text(quality.title).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .onChange(of: selectedModel) { _, newModel in
            if !newModel.supportsQuality {
                selectedQuality = nil
            } else if let selectedQuality, newModel.supportedQualities.contains(selectedQuality) {
                return
            } else {
                selectedQuality = newModel.defaultQuality
            }
        }
    }
}
