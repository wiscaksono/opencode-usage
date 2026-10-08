import Combine
import Foundation
import os
import WidgetKit

@MainActor
final class UsageViewModel: ObservableObject {
    /// Shared instance so the menu bar popup and the deep-link settings window
    /// observe the same data and run a single refresh loop.
    static let shared = UsageViewModel()

    @Published var stats: UsageStats?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var needsSetup: Bool = false

    private var timer: Timer?
    private var relayPollTimer: Timer?
    private let networkManager = NetworkManager()
    private let widgetRelay = WidgetDataRelay()
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "Usage")

    init() {
        if AppSettings.hasAPIKey {
            startMonitoring()
        } else {
            needsSetup = true
            logger.info("No credentials found — showing setup screen")
        }
    }

    func startMonitoring() {
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.refresh()
            }
        }
        relayPollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleWidgetRefreshRequest()
            }
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        relayPollTimer?.invalidate()
        relayPollTimer = nil
    }

    func credentialsUpdated() {
        needsSetup = false
        stats = nil
        errorMessage = nil
        widgetRelay.clearSnapshot()
        stopMonitoring()
        startMonitoring()
    }

    func refresh() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        logger.info("Refreshing usage data...")

        Task {
            do {
                let newStats = try await networkManager.fetchUsage()
                self.stats = newStats
                publishToWidget(newStats)
                logger.info("Usage updated: rolling=\(newStats.rolling.percent)%, weekly=\(newStats.weekly.percent)%, monthly=\(newStats.monthly.percent)%")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("Failed to refresh usage: \(error.localizedDescription)")
                if widgetRelay.consumeRefreshRequest() {
                    WidgetCenter.shared.reloadTimelines(ofKind: WidgetDataRelay.widgetKind)
                }
            }
            self.isLoading = false
        }
    }

    /// Publishes non-secret usage to the desktop widget and nudges WidgetKit.
    private func publishToWidget(_ stats: UsageStats) {
        do {
            try widgetRelay.writeSnapshot(stats)
            WidgetCenter.shared.reloadTimelines(ofKind: WidgetDataRelay.widgetKind)
        } catch {
            logger.error("Failed to publish widget snapshot: \(error.localizedDescription)")
        }
    }

    /// Fetches fresh data when the widget's refresh button asks for it.
    private func handleWidgetRefreshRequest() {
        guard widgetRelay.consumeRefreshRequest() else { return }
        logger.info("Widget requested a refresh")
        refresh()
    }
}
