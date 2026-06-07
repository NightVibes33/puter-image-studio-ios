import SwiftUI

struct IconButton: View {
    var systemName: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(AppTheme.ink)
                .background(AppTheme.panelBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
