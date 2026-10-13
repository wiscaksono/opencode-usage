import Foundation

enum AppSettings {
    private enum Keys {
        static let progressAccent = "opencode_progress_accent"
        static let showCredits = "opencode_show_credits"
    }

    static let keychain = KeychainStore()

    /// Whether the user has saved an API key.
    static var hasAPIKey: Bool {
        keychain.read() != nil
    }

    static var apiKey: String? {
        keychain.read()
    }

    static func setAPIKey(_ value: String) throws {
        try keychain.save(value)
    }

    static func clearAPIKey() {
        keychain.delete()
    }

    static var progressAccent: Bool {
        UserDefaults.standard.bool(forKey: Keys.progressAccent)
    }

    static func setProgressAccent(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Keys.progressAccent)
    }

    /// Off by default: the API does not yet expose the prepaid balance.
    static var showCredits: Bool {
        UserDefaults.standard.bool(forKey: Keys.showCredits)
    }

    static func setShowCredits(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: Keys.showCredits)
    }
}
