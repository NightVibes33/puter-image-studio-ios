import Foundation
import Security
import SwiftUI

enum AppSettingsKeys {
    static let defaultModelID = "settings.defaultModelID"
    static let defaultQualityRaw = "settings.defaultQualityRaw"
    static let userLocalUsername = "settings.userLocalUsername"
    static let userLocalAuthTokenLegacy = "settings.userLocalAuthToken"
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var defaultModelID: String {
        didSet { userDefaults.set(defaultModelID, forKey: AppSettingsKeys.defaultModelID) }
    }

    @Published var defaultQualityRaw: String {
        didSet { userDefaults.set(defaultQualityRaw, forKey: AppSettingsKeys.defaultQualityRaw) }
    }

    @Published var userLocalAuthToken: String {
        didSet { KeychainStore.set(userLocalAuthToken, for: KeychainStore.puterAuthTokenAccount) }
    }

    @Published var userLocalUsername: String {
        didSet { userDefaults.set(userLocalUsername, forKey: AppSettingsKeys.userLocalUsername) }
    }

    let privacyPolicyURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/PRIVACY.md")!
    let termsURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/TERMS.md")!
    let supportURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/issues")!

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        defaultModelID = userDefaults.string(forKey: AppSettingsKeys.defaultModelID) ?? ImageModel.fallback.id
        defaultQualityRaw = userDefaults.string(forKey: AppSettingsKeys.defaultQualityRaw) ?? ImageQuality.low.rawValue
        let legacyToken = userDefaults.string(forKey: AppSettingsKeys.userLocalAuthTokenLegacy) ?? ""
        userLocalAuthToken = KeychainStore.string(for: KeychainStore.puterAuthTokenAccount) ?? legacyToken
        if !legacyToken.isEmpty {
            KeychainStore.set(legacyToken, for: KeychainStore.puterAuthTokenAccount)
            userDefaults.removeObject(forKey: AppSettingsKeys.userLocalAuthTokenLegacy)
        }
        userLocalUsername = userDefaults.string(forKey: AppSettingsKeys.userLocalUsername) ?? ""
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

    var hasUserLocalToken: Bool {
        !userLocalAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var puterAuthURL: URL {
        var components = URLComponents(url: imageAPIBaseURL().appendingPathComponent("puter-auth"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "redirect", value: "imagestudio://puter-auth")]
        return components.url!
    }

    func setDefaultQuality(_ quality: ImageQuality?) {
        defaultQualityRaw = quality?.rawValue ?? ""
    }

    

    func clearLocalConnection() {
        userLocalAuthToken = ""
        userLocalUsername = ""
    }

    private func imageAPIBaseURL() -> URL {
        if let rawValue = Bundle.main.object(forInfoDictionaryKey: "IMAGE_API_BASE_URL") as? String,
           let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
           url.scheme == "http" || url.scheme == "https",
           url.host?.isEmpty == false {
            return url
        }
        return URL(string: "https://puter-image-studio-ios.vercel.app")!
    }
}


enum KeychainStore {
    static let puterAuthTokenAccount = "puterAuthToken"
    private static let service = "com.nightvibes.imagestudio.puter"

    static func string(for account: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func set(_ value: String, for account: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
        SecItemDelete(query as CFDictionary)

        guard !value.isEmpty, let data = value.data(using: .utf8) else { return }
        let attributes: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecValueData: data
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }
}
