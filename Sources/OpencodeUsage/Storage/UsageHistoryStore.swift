import Foundation

struct UsageSample: Codable, Equatable, Sendable {
    let timestamp: Date
    let rolling: Int
    let weekly: Int
    let monthly: Int

    init(timestamp: Date, rolling: Int, weekly: Int, monthly: Int) {
        self.timestamp = timestamp
        self.rolling = rolling
        self.weekly = weekly
        self.monthly = monthly
    }

    init(timestamp: Date, stats: UsageStats) {
        self.init(
            timestamp: timestamp,
            rolling: stats.rolling.percent,
            weekly: stats.weekly.percent,
            monthly: stats.monthly.percent
        )
    }
}

/// Persists a 24-hour rolling history of usage percentages for the sparkline.
struct UsageHistoryStore: Sendable {
    static let maxSamples = 288 // 24 h at one sample per 5 minutes

    let fileURL: URL
    let maxSamples: Int

    init(fileURL: URL = UsageHistoryStore.defaultFileURL, maxSamples: Int = UsageHistoryStore.maxSamples) {
        self.fileURL = fileURL
        self.maxSamples = maxSamples
    }

    static var defaultFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/OpenCode Usage/history.json")
    }

    func load(now: Date = Date()) -> [UsageSample] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let samples = try? decoder.decode([UsageSample].self, from: data) else { return [] }
        return trimmed(samples, now: now)
    }

    /// Returns the history with the new sample appended. Samples closer than a
    /// minute replace the previous one so manual refreshes do not create spikes.
    func appending(_ sample: UsageSample, to history: [UsageSample], now: Date = Date()) -> [UsageSample] {
        var samples = history
        if let last = samples.last,
           abs(last.timestamp.timeIntervalSince(sample.timestamp)) < 60
        {
            samples[samples.count - 1] = sample
        } else {
            samples.append(sample)
        }
        return trimmed(samples, now: now)
    }

    func save(_ samples: [UsageSample]) {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.sortedKeys]
            let data = try encoder.encode(samples)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            // History is best-effort; a failed write must not break refreshes.
        }
    }

    private func trimmed(_ samples: [UsageSample], now: Date) -> [UsageSample] {
        let cutoff = now.addingTimeInterval(-24 * 60 * 60)
        return Array(samples.filter { $0.timestamp >= cutoff }.suffix(maxSamples))
    }
}
