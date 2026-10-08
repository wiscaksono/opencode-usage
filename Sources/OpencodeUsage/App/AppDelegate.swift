import AppKit

/// Handles `opencodeusage://` URLs — used by the widget's settings button to
/// open a standalone settings window. Conformance to the @MainActor
/// NSApplicationDelegate protocol infers MainActor isolation on this class.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "opencodeusage" {
            SettingsWindowController.shared.present(viewModel: UsageViewModel.shared)
        }
    }
}
