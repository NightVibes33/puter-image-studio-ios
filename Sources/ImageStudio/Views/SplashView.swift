import SwiftUI

struct SplashView: View {
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didStart = false
    @State private var didFinish = false
    @State private var backgroundDrift = false
    @State private var showIdentity = false
    @State private var showPromptCard = false
    @State private var showActions = false
    @State private var typedPrompt = ""
    @State private var sendReady = false

    private let promptText = "Create a cinematic moonlit AI studio scene"
    private let actions = SplashAction.defaults

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                splashBackground

                VStack(spacing: 0) {
                    Spacer(minLength: max(62, proxy.size.height * 0.14))

                    identityStack
                        .opacity(showIdentity ? 1 : 0)
                        .blur(radius: showIdentity ? 0 : 12)
                        .scaleEffect(showIdentity ? 1 : 0.94)
                        .offset(y: showIdentity ? 0 : 18)
                        .animation(identityAnimation, value: showIdentity)

                    Spacer(minLength: 30)

                    VStack(spacing: 16) {
                        promptCard
                            .opacity(showPromptCard ? 1 : 0)
                            .blur(radius: showPromptCard ? 0 : 10)
                            .scaleEffect(showPromptCard ? 1 : 0.96)
                            .offset(y: showPromptCard ? 0 : 24)
                            .animation(cardAnimation, value: showPromptCard)

                        quickActions
                    }
                    .frame(maxWidth: 640)
                    .padding(.horizontal, 20)
                    .padding(.bottom, max(46, proxy.safeAreaInsets.bottom + proxy.size.height * 0.10))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                finish()
            }
        }
        .ignoresSafeArea()
        .task {
            await startIfNeeded()
        }
    }

    private var splashBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.025, blue: 0.045),
                    Color(red: 0.08, green: 0.10, blue: 0.18),
                    Color(red: 0.015, green: 0.015, blue: 0.025)
                ],
                startPoint: backgroundDrift ? .topTrailing : .topLeading,
                endPoint: backgroundDrift ? .bottomLeading : .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color(red: 0.22, green: 0.48, blue: 0.95).opacity(0.46),
                    .clear
                ],
                center: backgroundDrift ? .topTrailing : .top,
                startRadius: 40,
                endRadius: 390
            )
            .scaleEffect(backgroundDrift ? 1.14 : 0.92)
            .offset(x: backgroundDrift ? 72 : -42, y: backgroundDrift ? -38 : 8)

            RadialGradient(
                colors: [
                    Color(red: 0.92, green: 0.33, blue: 0.68).opacity(0.28),
                    .clear
                ],
                center: backgroundDrift ? .bottomLeading : .bottomTrailing,
                startRadius: 20,
                endRadius: 360
            )
            .scaleEffect(backgroundDrift ? 0.95 : 1.12)
            .offset(x: backgroundDrift ? -32 : 54, y: backgroundDrift ? 78 : 36)

            LinearGradient(
                colors: [
                    .black.opacity(0.16),
                    .black.opacity(0.40)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            diagonalTexture
                .opacity(0.11)
        }
        .animation(reduceMotion ? .linear(duration: 0.01) : .easeInOut(duration: 1.35), value: backgroundDrift)
    }

    private var diagonalTexture: some View {
        Canvas { context, size in
            let spacing: CGFloat = 28
            var path = Path()

            for x in stride(from: -size.height, through: size.width + size.height, by: spacing) {
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x + size.height, y: size.height))
            }

            context.stroke(
                path,
                with: .color(.white.opacity(0.42)),
                lineWidth: 0.55
            )
        }
    }

    private var identityStack: some View {
        VStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.10))
                    .frame(width: 76, height: 76)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(.white.opacity(0.20), lineWidth: 1)
                    )

                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: AppTheme.accent.opacity(0.65), radius: 18, y: 6)
                    .scaleEffect(sendReady && !reduceMotion ? 1.05 : 1)
                    .animation(.spring(duration: 0.45, bounce: 0.28), value: sendReady)
            }

            VStack(spacing: 6) {
                Text("Puter Image Studio")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.64)

                Text("AI images from one native prompt.")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.74))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding(.horizontal, 24)
        }
    }

    private var promptCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Text(typedPrompt.isEmpty ? "Type your image request..." : typedPrompt)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(typedPrompt.isEmpty ? .white.opacity(0.48) : .white)
                    .lineSpacing(3)
                    .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
                    .contentTransition(.opacity)

                if !typedPrompt.isEmpty {
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(AppTheme.accent)
                        .frame(width: 3, height: 19)
                        .opacity(sendReady || reduceMotion ? 0 : 1)
                        .padding(.top, 1)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 8)

            HStack(spacing: 9) {
                iconCircle("paperclip", label: "Attach reference")

                pillLabel("Cinematic", systemName: "movieclapper")
                pillLabel("4:5", systemName: "rectangle.portrait")

                Spacer(minLength: 4)

                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(sendReady ? AppTheme.accent : Color.white.opacity(0.12))
                        .frame(width: 44, height: 44)
                        .shadow(color: sendReady ? AppTheme.accent.opacity(0.46) : .clear, radius: 18, y: 8)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .heavy))
                        .foregroundStyle(sendReady ? .white : .white.opacity(0.50))
                }
                .scaleEffect(sendReady && !reduceMotion ? 1.06 : 1)
                .animation(.spring(duration: 0.42, bounce: 0.24), value: sendReady)
                .accessibilityLabel("Generate")
            }
            .padding(12)
        }
        .background(Color.black.opacity(0.46), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.28), radius: 28, y: 18)
    }

    private var quickActions: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 9)], spacing: 9) {
            ForEach(Array(actions.enumerated()), id: \.element.id) { index, action in
                HStack(spacing: 7) {
                    Image(systemName: action.systemName)
                        .font(.system(size: 14, weight: .semibold))

                    Text(action.title)
                        .font(.caption.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity, minHeight: 38)
                .padding(.horizontal, 10)
                .background(.black.opacity(0.32), in: Capsule())
                .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
                .opacity(showActions ? 1 : 0)
                .scaleEffect(showActions ? 1 : 0.92)
                .offset(y: showActions ? 0 : 10)
                .animation(actionAnimation.delay(reduceMotion ? 0 : Double(index) * 0.045), value: showActions)
                .accessibilityLabel(action.title)
            }
        }
    }

    private func iconCircle(_ systemName: String, label: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: 36, height: 36)
            .background(.white.opacity(0.09), in: Circle())
            .accessibilityLabel(label)
    }

    private func pillLabel(_ title: String, systemName: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemName)
                .font(.system(size: 11, weight: .bold))
            Text(title)
                .font(.caption.weight(.bold))
                .lineLimit(1)
        }
        .foregroundStyle(.white.opacity(0.84))
        .frame(height: 34)
        .padding(.horizontal, 10)
        .background(.white.opacity(0.08), in: Capsule())
    }

    private var identityAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.70, bounce: 0.16)
    }

    private var cardAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.70, bounce: 0.20)
    }

    private var actionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .spring(duration: 0.48, bounce: 0.22)
    }

    @MainActor
    private func startIfNeeded() async {
        guard !didStart else { return }
        didStart = true

        if reduceMotion {
            showIdentity = true
            showPromptCard = true
            showActions = true
            typedPrompt = promptText
            sendReady = true
            try? await Task.sleep(nanoseconds: 850_000_000)
            finish()
            return
        }

        withAnimation(.easeInOut(duration: 1.35)) {
            backgroundDrift = true
        }

        withAnimation(identityAnimation) {
            showIdentity = true
        }

        try? await Task.sleep(nanoseconds: 260_000_000)
        withAnimation(cardAnimation) {
            showPromptCard = true
        }

        try? await Task.sleep(nanoseconds: 220_000_000)
        for character in promptText {
            guard !didFinish else { return }
            typedPrompt.append(character)
            try? await Task.sleep(nanoseconds: 18_000_000)
        }

        withAnimation(.spring(duration: 0.44, bounce: 0.22)) {
            sendReady = true
        }

        try? await Task.sleep(nanoseconds: 120_000_000)
        withAnimation(actionAnimation) {
            showActions = true
        }

        try? await Task.sleep(nanoseconds: 1_050_000_000)
        finish()
    }

    @MainActor
    private func finish() {
        guard !didFinish else { return }
        didFinish = true
        onFinished()
    }
}

private struct SplashAction: Identifiable {
    var id: String
    var title: String
    var systemName: String

    static let defaults: [SplashAction] = [
        SplashAction(id: "image-assets", title: "Image Assets", systemName: "photo.on.rectangle.angled"),
        SplashAction(id: "theme-ideas", title: "Theme Ideas", systemName: "paintpalette"),
        SplashAction(id: "style-board", title: "Style Board", systemName: "square.grid.2x2"),
        SplashAction(id: "wallpaper", title: "Wallpaper", systemName: "rectangle.portrait"),
        SplashAction(id: "product-shot", title: "Product Shot", systemName: "shippingbox"),
        SplashAction(id: "cinematic", title: "Cinematic", systemName: "movieclapper")
    ]
}

#Preview {
    SplashView {}
}
