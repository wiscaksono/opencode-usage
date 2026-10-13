import Foundation

enum AppSettings {
    enum Keys {
        static let progressAccent = "opencode_progress_accent"
        static let menuBarStyle = "opencode_menu_bar_style"
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

    /// Menu-bar visual style. Defaults to `.logo`.
    static var menuBarStyle: MenuBarStyle {
        guard let raw = UserDefaults.standard.string(forKey: Keys.menuBarStyle),
              let style = MenuBarStyle(rawValue: raw)
        else { return .logo }
        return style
    }

    static func setMenuBarStyle(_ value: MenuBarStyle) {
        UserDefaults.standard.set(value.rawValue, forKey: Keys.menuBarStyle)
    }
}
