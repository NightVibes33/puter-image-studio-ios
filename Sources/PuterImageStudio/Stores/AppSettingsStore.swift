import Foundation
import Security
import SwiftUI

enum AppSettingsKeys {
    static let defaultModelID = "settings.defaultModelID"
    static let defaultQualityRaw = "settings.defaultQualityRaw"
    static let userPuterUsername = "settings.userPuterUsername"
    static let userPuterAuthTokenLegacy = "settings.userPuterAuthToken"
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
        didSet { KeychainStore.set(userPuterAuthToken, for: KeychainStore.puterAuthTokenAccount) }
    }

    @Published var userPuterUsername: String {
        didSet { userDefaults.set(userPuterUsername, forKey: AppSettingsKeys.userPuterUsername) }
    }

    let privacyPolicyURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/PRIVACY.md")!
    let termsURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/blob/main/TERMS.md")!
    let supportURL = URL(string: "https://github.com/NightVibes33/puter-image-studio-ios/issues")!

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        defaultModelID = userDefaults.string(forKey: AppSettingsKeys.defaultModelID) ?? ImageModel.fallback.id
        defaultQualityRaw = userDefaults.string(forKey: AppSettingsKeys.defaultQualityRaw) ?? ImageQuality.low.rawValue
        let legacyToken = userDefaults.string(forKey: AppSettingsKeys.userPuterAuthTokenLegacy) ?? ""
        userPuterAuthToken = KeychainStore.string(for: KeychainStore.puterAuthTokenAccount) ?? legacyToken
        if !legacyToken.isEmpty {
            KeychainStore.set(legacyToken, for: KeychainStore.puterAuthTokenAccount)
            userDefaults.removeObject(forKey: AppSettingsKeys.userPuterAuthTokenLegacy)
        }
        userPuterUsername = userDefaults.string(forKey: AppSettingsKeys.userPuterUsername) ?? ""
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

    var hasUserPuterToken: Bool {
        !userPuterAuthToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var puterAuthURL: URL {
        var components = URLComponents(url: imageAPIBaseURL().appendingPathComponent("puter-auth"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "redirect", value: "imagestudio://puter-auth")]
        return components.url!
    }

    func setDefaultQuality(_ quality: ImageQuality?) {
        defaultQualityRaw = quality?.rawValue ?? ""
    }

    func connectPuter(token: String, username: String?) {
        userPuterAuthToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        userPuterUsername = username?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    func clearPuterConnection() {
        userPuterAuthToken = ""
        userPuterUsername = ""
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


private enum KeychainStore {
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
