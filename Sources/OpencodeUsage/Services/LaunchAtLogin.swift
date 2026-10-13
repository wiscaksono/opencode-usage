import Foundation
import ServiceManagement

/// Wraps `SMAppService.mainApp` for managing the app's launch-at-login
/// registration. Reads/writes the system status directly — there's no
/// `UserDefaults` cache to drift out of sync.
///
/// The first `register()` on an ad-hoc signed bundle prompts the user
/// once; subsequent calls succeed silently. Bundles living outside a
/// stable location (`/Applications`, `~/Applications`) can register but
/// the system may refuse to actually launch them at login.
@MainActor
enum LaunchAtLogin {
    /// Whether the system currently has this app registered to launch at
    /// login. `.requiresApproval` counts as registered: the item exists in
    /// Login Items, macOS is only waiting for the user to allow it.
    static var isEnabled: Bool {
        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval: true
        default: false
        }
    }

    /// True while macOS holds the registration back until the user allows
    /// the app in System Settings > General > Login Items.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Idempotent toggle. No-op if already in the desired state. Throws
    /// if the system rejects the change (e.g. the bundle sits somewhere
    /// `SMAppService` cannot register). Unregistering covers
    /// `.requiresApproval` too, so switching off drops a pending item.
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled, !isEnabled {
            try service.register()
        } else if !enabled, service.status != .notRegistered, service.status != .notFound {
            try service.unregister()
        }
    }
}
