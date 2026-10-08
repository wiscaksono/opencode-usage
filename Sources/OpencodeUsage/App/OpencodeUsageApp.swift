import AppKit
import os
import SwiftUI

@main
struct OpencodeUsageApp: App {
    @StateObject private var viewModel = UsageViewModel.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "App")

    /// Menu bar icon loaded from bundle Resources as a template image.
    private static let menuBarIcon: NSImage = {
        let img: NSImage = if let url = Bundle.module.url(forResource: "opencode-logo", withExtension: "png"),
                              let loaded = NSImage(contentsOf: url)
        {
            loaded
        } else {
            // Fallback to SF Symbol if resource not found
            NSImage(systemSymbolName: "cpu", accessibilityDescription: "OpencodeUsage") ?? NSImage()
        }
        img.isTemplate = true
        img.size = NSSize(width: 16, height: 16)
        return img
    }()

    init() {
        logger.info("OpencodeUsage app started")
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }
}
