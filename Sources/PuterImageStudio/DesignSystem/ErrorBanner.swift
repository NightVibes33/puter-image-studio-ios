import SwiftUI

struct ErrorBanner: View {
    var error: GenerationError
    var onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppTheme.warmAccent)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 3) {
                Text(error.localizedDescription)
                    .font(.callout.weight(.semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.secondaryInk)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)
                }
            }
            Spacer(minLength: 6)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(10)
        .background(AppTheme.panelBackground)
        .overlay(
            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                .stroke(AppTheme.warmAccent.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
        .dynamicTypeSize(.small ... .large)
    }
}
