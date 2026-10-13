import Combine
import Foundation
import os

@MainActor
class UsageViewModel: ObservableObject {
    @Published var stats: UsageStats?
    @Published var balance: BalanceInfo?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var needsSetup: Bool = false

    private var timer: Timer?
    private let fetch: @Sendable () async throws -> UsageResponse
    private let scheduleTimer: (@Sendable @escaping () -> Void) -> Timer
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "Usage")

    init(
        fetch: (@Sendable () async throws -> UsageResponse)? = nil,
        scheduleTimer: ((@Sendable @escaping () -> Void) -> Timer)? = nil
    ) {
        let networkManager = NetworkManager()
        self.fetch = fetch ?? { try await networkManager.fetchUsage(apiKey: AppSettings.apiKey) }
        self.scheduleTimer = scheduleTimer ?? { handler in
            Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in handler() }
        }
        if AppSettings.hasAPIKey {
            startMonitoring()
        } else {
            needsSetup = true
            logger.info("No credentials found — showing setup screen")
        }
    }

    func startMonitoring() {
        stopMonitoring()
        refresh()
        timer = scheduleTimer { [weak self] in
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
        balance = nil
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
                let response = try await self.fetch()
                self.stats = response.usage
                self.balance = response.availableCredits
                logger.info("Usage updated: rolling=\(response.usage.rolling.percent)%, weekly=\(response.usage.weekly.percent)%, monthly=\(response.usage.monthly.percent)%")
            } catch {
                self.errorMessage = error.localizedDescription
                logger.error("Failed to refresh usage: \(error.localizedDescription)")
            }
            self.isLoading = false
        }
    }
}
