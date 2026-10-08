import Foundation

/// App ↔ widget relay file access from inside the widget sandbox.
///
/// The sandboxed extension can only touch two paths, via temporary
/// entitlement exceptions (see Support/OpencodeUsageWidget.entitlements):
/// read-only on the snapshot file, read-write on the refresh-request flag.
/// `NSHomeDirectory()` resolves to the extension container under sandbox,
/// so the real user home is resolved via `getpwuid` instead.
enum WidgetDataStore {
    /// Timeline kind — kept in sync with the app's WidgetDataRelay.widgetKind.
    static let widgetKind = "com.wiscaksono.opencode-usage.widget"

    static let appSupportSubdirectory = "com.wiscaksono.opencode-usage"
    static let snapshotFileName = "widget-snapshot.json"
    static let refreshFlagFileName = "widget-refresh-requested"

    static func appSupportDirectory() -> URL {
        let home: String = if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            String(cString: dir)
        } else {
            FileManager.default.homeDirectoryForCurrentUser.path
        }
        return URL(fileURLWithPath: home)
            .appendingPathComponent("Library/Application Support/\(appSupportSubdirectory)", isDirectory: true)
    }

    /// Latest usage published by the menu bar app, or nil if the app has
    /// never published one (not configured / never launched).
    static func readSnapshot() -> WidgetSnapshot? {
        let url = appSupportDirectory().appendingPathComponent(snapshotFileName)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    /// Records that the user pressed the widget's refresh button. The menu
    /// bar app polls this flag, refetches from the API and republishes the
    /// snapshot. No networking happens in the extension.
    static func requestRefresh() {
        let dir = appSupportDirectory()
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            try Date().description.write(
                to: dir.appendingPathComponent(refreshFlagFileName),
                atomically: true,
                encoding: .utf8
            )
        } catch {
            // Best effort: the timeline reload below still refreshes the
            // widget from the last published snapshot.
        }
    }
}
