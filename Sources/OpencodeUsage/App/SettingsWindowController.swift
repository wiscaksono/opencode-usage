import AppKit
import SwiftUI

/// Presents the settings UI in a standalone window, raised by the
/// `opencodeusage://settings` deep link from the widget.
@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func present(viewModel: UsageViewModel) {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let isPresented = Binding<Bool>(
            get: { self.window?.isVisible ?? false },
            set: {
                if !$0 {
                    self.window?.close()
                }
            }
        )

        let content = SettingsView(
            viewModel: viewModel,
            isPresented: isPresented,
            isFirstSetup: false
        )
        .frame(width: 300)

        let host = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: host)
        window.title = "OpenCode Usage Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
