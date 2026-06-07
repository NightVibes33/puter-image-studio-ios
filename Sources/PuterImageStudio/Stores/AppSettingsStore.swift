import Foundation
import SwiftUI

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultModelID: String {
        didSet { userDefaults.set(defaultModelID, forKey: Keys.defaultModelID) }
    }

    @Published var defaultQualityRaw: String {
        didSet { userDefaults.set(defaultQualityRaw, forKey: Keys.defaultQualityRaw) }
    }

    let promptMaxCharacters = 1_600
    let privacyPolicyURL = URL(string: "https://your-domain.example/privacy")!
    let termsURL = URL(string: "https://your-domain.example/terms")!
    let supportEmail = "support@your-domain.example"

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        defaultModelID = userDefaults.string(forKey: Keys.defaultModelID) ?? ImageModel.fallback.id
        defaultQualityRaw = userDefaults.string(forKey: Keys.defaultQualityRaw) ?? ImageQuality.low.rawValue
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

    private enum Keys {
        static let defaultModelID = "settings.defaultModelID"
        static let defaultQualityRaw = "settings.defaultQualityRaw"
    }
}
