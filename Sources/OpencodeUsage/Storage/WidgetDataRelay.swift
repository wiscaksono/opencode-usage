import Foundation

/// Non-secret payload published to the desktop widget: percentages and reset
/// times only. The API key never leaves the Keychain. Mirrors the widget
/// target's copy in Sources/Widget/WidgetModels.swift — keep in sync.
struct WidgetSnapshot: Equatable, Codable {
    let stats: UsageStats
    let fetchedAt: Date
}

/// File-based relay between the menu bar app and the widget extension.
///
/// The API key lives in the Keychain, which an ad-hoc signed widget cannot
/// read (no stable designated requirement, no App Group without a team ID).
/// Instead the app publishes non-secret usage snapshots to a file the
/// sandboxed widget reads via a read-only temporary entitlement exception,
/// and the widget signals refresh requests back through a flag file the app
/// polls. The widget does no networking of its own.
struct WidgetDataRelay: Sendable {
    /// Timeline kind — kept in sync with the widget target's
    /// OpencodeUsageWidget.kind.
    static let widgetKind = "com.wiscaksono.opencode-usage.widget"

    static let snapshotFileName = "widget-snapshot.json"
    static let refreshFlagFileName = "widget-refresh-requested"

    let directory: URL

    /// - Parameter directory: relay directory. Injectable so tests can point
    ///   at a scratch directory instead of the user's Application Support.
    init(directory: URL? = nil) {
        if let directory {
            self.directory = directory
        } else {
            let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directory = base.appendingPathComponent("com.wiscaksono.opencode-usage", isDirectory: true)
        }
    }

    private var snapshotURL: URL {
        directory.appendingPathComponent(Self.snapshotFileName)
    }

    private var refreshFlagURL: URL {
        directory.appendingPathComponent(Self.refreshFlagFileName)
    }

    /// Publishes the latest usage for the widget. Written atomically so the
    /// widget never observes a half-written file.
    func writeSnapshot(_ stats: UsageStats, fetchedAt: Date = Date()) throws {
        let data = try JSONEncoder().encode(WidgetSnapshot(stats: stats, fetchedAt: fetchedAt))
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: snapshotURL, options: .atomic)
    }

    /// Removes the published snapshot (e.g. credentials changed) so the
    /// widget falls back to its setup prompt instead of stale data.
    func clearSnapshot() {
        try? FileManager.default.removeItem(at: snapshotURL)
    }

    /// Returns and clears the widget's refresh request, if any. The widget
    /// writes the flag file when the user presses its refresh button.
    func consumeRefreshRequest() -> Bool {
        guard FileManager.default.fileExists(atPath: refreshFlagURL.path) else { return false }
        try? FileManager.default.removeItem(at: refreshFlagURL)
        return true
    }
}
