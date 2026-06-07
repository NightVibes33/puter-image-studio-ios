import SwiftUI

struct StylePresetGrid: View {
    @Binding var selectedStyle: StylePreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Style")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(StylePreset.presets) { preset in
                        Button {
                            selectedStyle = preset
                        } label: {
                            Label(preset.title, systemImage: preset.systemImage)
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(1)
                                .padding(.horizontal, 12)
                                .frame(height: 38)
                                .foregroundStyle(selectedStyle.id == preset.id ? .white : AppTheme.ink)
                                .background(selectedStyle.id == preset.id ? AppTheme.accent : AppTheme.panelBackground)
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}
