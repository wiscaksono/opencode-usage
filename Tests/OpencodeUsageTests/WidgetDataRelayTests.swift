import Foundation
@testable import OpencodeUsage
import Testing

struct WidgetDataRelayTests {
    private let sampleStats = UsageStats(
        rolling: UsageItem(status: "allowed", percent: 42, resetsAt: Date(timeIntervalSince1970: 1_787_400_000)),
        weekly: UsageItem(status: "allowed", percent: 55, resetsAt: Date(timeIntervalSince1970: 1_787_400_000)),
        monthly: UsageItem(status: "allowed", percent: 30, resetsAt: Date(timeIntervalSince1970: 1_787_400_000))
    )

    private func makeRelay() -> (relay: WidgetDataRelay, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("opencode-usage-relay-tests-\(UUID().uuidString)", isDirectory: true)
        return (WidgetDataRelay(directory: directory), directory)
    }

    @Test func writeSnapshotPersistsDecodableJSON() throws {
        let (relay, directory) = makeRelay()
        let fetchedAt = Date(timeIntervalSince1970: 1_787_400_000)
        try relay.writeSnapshot(sampleStats, fetchedAt: fetchedAt)

        let url = directory.appendingPathComponent(WidgetDataRelay.snapshotFileName)
        let data = try Data(contentsOf: url)
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: data)
        #expect(snapshot.stats == sampleStats)
        #expect(snapshot.fetchedAt == fetchedAt)
    }

    @Test func writeSnapshotOverwritesPreviousFile() throws {
        let (relay, directory) = makeRelay()
        try relay.writeSnapshot(sampleStats)
        try relay.writeSnapshot(sampleStats, fetchedAt: Date(timeIntervalSince1970: 1_787_400_000))

        let url = directory.appendingPathComponent(WidgetDataRelay.snapshotFileName)
        let snapshot = try JSONDecoder().decode(WidgetSnapshot.self, from: Data(contentsOf: url))
        #expect(snapshot.fetchedAt == Date(timeIntervalSince1970: 1_787_400_000))
    }

    @Test func clearSnapshotRemovesPublishedFile() throws {
        let (relay, directory) = makeRelay()
        try relay.writeSnapshot(sampleStats)
        relay.clearSnapshot()

        let url = directory.appendingPathComponent(WidgetDataRelay.snapshotFileName)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func clearSnapshotToleratesMissingFile() {
        let (relay, _) = makeRelay()
        relay.clearSnapshot()
    }

    @Test func consumeRefreshRequestReturnsTrueOnlyOnce() throws {
        let (relay, directory) = makeRelay()
        let flagURL = directory.appendingPathComponent(WidgetDataRelay.refreshFlagFileName)

        #expect(!relay.consumeRefreshRequest())

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try "refresh".write(to: flagURL, atomically: true, encoding: .utf8)

        #expect(relay.consumeRefreshRequest())
        #expect(!FileManager.default.fileExists(atPath: flagURL.path))
        #expect(!relay.consumeRefreshRequest())
    }
}
