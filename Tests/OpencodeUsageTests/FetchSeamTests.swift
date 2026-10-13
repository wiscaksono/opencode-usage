import Foundation
@testable import OpencodeUsage
import Testing

struct FetchSeamTests {
    private static func sampleResponse() -> UsageResponse {
        let item = UsageItem(status: "allowed", percent: 10, resetsAt: Date(timeIntervalSince1970: 1_787_400_000))
        let usage = UsageStats(rolling: item, weekly: item, monthly: item)
        return UsageResponse(usage: usage, balance: nil)
    }

    @Test func fetchUsageRequiresAPIKey() async {
        let manager = NetworkManager()
        await #expect(throws: NetworkError.notConfigured) {
            try await manager.fetchUsage(apiKey: nil)
        }
        await #expect(throws: NetworkError.notConfigured) {
            try await manager.fetchUsage(apiKey: "")
        }
    }

    @Test @MainActor func viewModelUsesInjectedFetch() async throws {
        let expected = Self.sampleResponse()
        let viewModel = UsageViewModel(
            fetch: { expected },
            scheduleTimer: { _ in Timer(timeInterval: 300, repeats: true, block: { _ in }) }
        )
        viewModel.stopMonitoring()
        viewModel.refresh()

        for _ in 0 ..< 50 {
            if viewModel.stats != nil {
                break
            }
            try await Task.sleep(nanoseconds: 20_000_000)
        }

        #expect(viewModel.stats == expected.usage)
        #expect(viewModel.balance == expected.availableCredits)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == nil)
        viewModel.stopMonitoring()
    }

    @Test @MainActor func startMonitoringIsIdempotent() {
        var timers: [Timer] = []
        let viewModel = UsageViewModel(
            fetch: { throw NetworkError.requestFailed },
            scheduleTimer: { _ in
                let timer = Timer(timeInterval: 300, repeats: true, block: { _ in })
                timers.append(timer)
                return timer
            }
        )
        viewModel.stopMonitoring()
        timers.removeAll()

        viewModel.startMonitoring()
        viewModel.startMonitoring()

        #expect(timers.count == 2)
        #expect(timers[0].isValid == false)
        #expect(timers[1].isValid == true)

        viewModel.stopMonitoring()
        #expect(timers[1].isValid == false)
    }
}
