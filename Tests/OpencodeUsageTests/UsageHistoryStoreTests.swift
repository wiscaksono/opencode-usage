import Foundation
@testable import OpencodeUsage
import Testing

struct UsageHistoryStoreTests {
    private func makeStore(maxSamples: Int = 288) -> (UsageHistoryStore, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("history.json")
        return (UsageHistoryStore(fileURL: url, maxSamples: maxSamples), url)
    }

    private func sample(at date: Date, monthly: Int = 10) -> UsageSample {
        UsageSample(timestamp: date, rolling: 1, weekly: 2, monthly: monthly)
    }

    @Test func appendingKeepsNewestSamplesOnly() {
        let (store, _) = makeStore(maxSamples: 3)
        let now = Date()
        var history: [UsageSample] = []
        for index in 0 ..< 5 {
            let date = now.addingTimeInterval(TimeInterval(index * 300))
            history = store.appending(sample(at: date, monthly: index), to: history, now: now.addingTimeInterval(3600))
        }
        #expect(history.count == 3)
        #expect(history.map(\.monthly) == [2, 3, 4])
    }

    @Test func closeSamplesReplaceTheLastOne() {
        let (store, _) = makeStore()
        let now = Date()
        var history = store.appending(sample(at: now, monthly: 10), to: [], now: now)
        history = store.appending(sample(at: now.addingTimeInterval(20), monthly: 12), to: history, now: now)
        #expect(history.count == 1)
        #expect(history.first?.monthly == 12)
    }

    @Test func dropsSamplesOlderThanTwentyFourHours() {
        let (store, _) = makeStore()
        let now = Date()
        let old = sample(at: now.addingTimeInterval(-25 * 60 * 60), monthly: 90)
        let fresh = sample(at: now, monthly: 20)
        let history = store.appending(fresh, to: [old], now: now)
        #expect(history.count == 1)
        #expect(history.first?.monthly == 20)
    }

    @Test func roundTripsThroughDisk() {
        let (store, url) = makeStore()
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let samples = [
            sample(at: now.addingTimeInterval(-300), monthly: 11),
            sample(at: now, monthly: 12),
        ]
        store.save(samples)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(store.load(now: now) == samples)
    }
}
