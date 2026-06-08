import Foundation
import SwiftUI

enum AppSettingsKeys {
    static let defaultModelID = "settings.defaultModelID"
    static let defaultQualityRaw = "settings.defaultQualityRaw"
    static let userPuterAuthToken = "settings.userPuterAuthToken"
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultModelID: String {
        didSet { userDefaults.set(defaultModelID, forKey: AppSettingsKeys.defaultModelID) }
    }

    @Published var defaultQualityRaw: String {
        didSet { userDefaults.set(defaultQualityRaw, forKey: AppSettingsKeys.defaultQualityRaw) }
    }

    @Published var userPuterAuthToken: String {
        didSet { userDefaults.set(userPuterAuthToken, forKey: AppSettingsKeys.userPuterAuthToken) }
    }

    let privacyPolicyURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/PRIVACY.md")!
    let termsURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/TERMS.md")!
    let supportURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/issues")!

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        defaultModelID = userDefaults.string(forKey: AppSettingsKeys.defaultModelID) ?? ImageModel.fallback.id
        defaultQualityRaw = userDefaults.string(forKey: AppSettingsKeys.defaultQualityRaw) ?? ImageQuality.low.rawValue
        userPuterAuthToken = userDefaults.string(forKey: AppSettingsKeys.userPuterAuthToken) ?? ""
    }

    var defaultModel: ImageModel {
        ImageModel.preset(id: defaultModelID)
    }

    func defaultQuality(for model: ImageModel) -> ImageQuality? {
        guard model.supportsQuality else { return nil }
        let saved = ImageQuality(rawValue: defaultQualityRaw)
        if let saved, model.supportedQualities.contains(saved) {
            return saved
        }
        return model.defaultQuality
    }

    func setDefaultQuality(_ quality: ImageQuality?) {
        defaultQualityRaw = quality?.rawValue ?? ""
    }
}
