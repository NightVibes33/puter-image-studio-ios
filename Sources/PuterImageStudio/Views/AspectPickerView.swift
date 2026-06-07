import SwiftUI

struct AspectPickerView: View {
    @Binding var selectedAspect: AspectPreset

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Size")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AspectPreset.presets) { preset in
                        Button {
                            selectedAspect = preset
                        } label: {
                            VStack(alignment: .leading, spacing: 5) {
                                Image(systemName: preset.systemImage)
                                    .font(.headline)
                                Text(preset.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(preset.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(selectedAspect.id == preset.id ? .white.opacity(0.78) : AppTheme.secondaryInk)
                            }
                            .frame(width: 142, alignment: .leading)
                            .padding(12)
                            .foregroundStyle(selectedAspect.id == preset.id ? .white : AppTheme.ink)
                            .background(selectedAspect.id == preset.id ? AppTheme.accent : AppTheme.panelBackground)
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
