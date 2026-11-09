import Combine
import Foundation
import os

@MainActor
class UsageViewModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var history: [UsageSample] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var needsSetup: Bool = false

    private var timer: Timer?
    private let networkManager = NetworkManager()
    private let historyStore = UsageHistoryStore()
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "Usage")

    init() {
        history = historyStore.load()
        if AppSettings.hasCredentials {
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
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func credentialsUpdated() {
        needsSetup = false
        stats = nil
        errorMessage = nil
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
                self.recordHistory(newStats)
                logger.info("Usage updated: rolling=\(newStats.rolling.percent)%, weekly=\(newStats.weekly.percent)%, monthly=\(newStats.monthly.percent)%")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("Failed to refresh usage: \(error.localizedDescription)")
            }
            self.isLoading = false
        }
    }

    private func recordHistory(_ stats: UsageStats) {
        let sample = UsageSample(timestamp: Date(), stats: stats)
        history = historyStore.appending(sample, to: history)
        historyStore.save(history)
    }
}
