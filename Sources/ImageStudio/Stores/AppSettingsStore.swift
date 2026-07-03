import Foundation

@MainActor
final class AppSettingsStore: ObservableObject {
    let privacyPolicyURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/PRIVACY.md")!
    let termsURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/TERMS.md")!
    let supportURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/issues")!
}
