import SwiftUI

struct PromptComposerView: View {
    @Binding var prompt: String
    var maxCharacters: Int
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Prompt")
                    .font(.headline)
                Spacer()
                if !prompt.isEmpty {
                    Button {
                        prompt = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppTheme.secondaryInk)
                    }
                    .accessibilityLabel("Clear prompt")
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $prompt)
                    .focused(isFocused)
                    .frame(minHeight: 116)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(AppTheme.panelBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadius, style: .continuous))
                    .onChange(of: prompt) { _, newValue in
                        if newValue.count > maxCharacters {
                            prompt = String(newValue.prefix(maxCharacters))
                        }
                    }

                if prompt.isEmpty {
                    Text("A cinematic neon city at night")
                        .foregroundStyle(AppTheme.secondaryInk)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }

            HStack {
                Text("\(prompt.count)/\(maxCharacters)")
                    .font(.caption)
                    .foregroundStyle(prompt.count >= maxCharacters ? AppTheme.warmAccent : AppTheme.secondaryInk)
                Spacer()
                Button {
                    isFocused.wrappedValue = false
                } label: {
                    Label("Done", systemImage: "keyboard.chevron.compact.down")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss keyboard")
            }
        }
    }
}
