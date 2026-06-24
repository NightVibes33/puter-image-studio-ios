import Foundation
import Security
import SwiftUI

enum AppSettingsKeys {
    static let defaultModelID = "settings.defaultModelID"
    static let defaultQualityRaw = "settings.defaultQualityRaw"
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultModelID: String {
        didSet { userDefaults.set(defaultModelID, forKey: AppSettingsKeys.defaultModelID) }
    }

    @Published var defaultQualityRaw: String {
        didSet { userDefaults.set(defaultQualityRaw, forKey: AppSettingsKeys.defaultQualityRaw) }
    }

    let privacyPolicyURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/PRIVACY.md")!
    let termsURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/TERMS.md")!
    let supportURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/issues")!

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        defaultModelID = userDefaults.string(forKey: AppSettingsKeys.defaultModelID) ?? "fallback"
        defaultQualityRaw = userDefaults.string(forKey: AppSettingsKeys.defaultQualityRaw) ?? "low"
    }

    func setDefaultQuality(_ quality: String?) {
        defaultQualityRaw = quality ?? ""
    }
}
