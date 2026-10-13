import os
import SwiftUI

@main
struct OpencodeUsageApp: App {
    @StateObject private var viewModel = UsageViewModel()
    @AppStorage(AppSettings.Keys.menuBarStyle) private var menuBarStyle: MenuBarStyle = .logo
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "App")

    init() {
        logger.info("OpencodeUsage app started")
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            Image(nsImage: MenuBarRenderer.image(for: viewModel.stats, style: menuBarStyle))
        }
        .menuBarExtraStyle(.window)
    }
}
