import SwiftUI

struct LoadingStateView: View {
    var prompt: String
    var onCancel: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            ProgressView()
                .controlSize(.large)
                .tint(AppTheme.accent)
            Text("Generating")
                .font(.headline)
            Text(prompt)
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryInk)
                .multilineTextAlignment(.center)
                .lineLimit(4)
                .padding(.horizontal)
            Button(role: .cancel, action: onCancel) {
                Label("Cancel", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }
}
