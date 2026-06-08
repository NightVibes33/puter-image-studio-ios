import SwiftUI

struct PrimaryButton: View {
    var title: String
    var systemImage: String?
    var isLoading: Bool = false
    var isDisabled: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
            }
            .frame(maxWidth: .infinity, minHeight: AppTheme.controlHeight)
            .foregroundStyle(.white)
            .background(isDisabled ? Color(uiColor: .systemGray3) : AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
        .disabled(isDisabled || isLoading)
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
