import Foundation

// Duplicated from Sources/OpencodeUsage/Models/UsageModels.swift (plus the
// relay payload) so the widget stays a plain SwiftPM executable target.
// SwiftPM cannot share individual files between two executable targets
// without introducing a library target — kept out of scope for this PR.
// Keep these shapes in sync: the snapshot file written by the app's
// WidgetDataRelay must decode here.

struct UsageItem: Equatable, Codable {
    let status: String
    let percent: Int
    let resetsAt: Date
}

struct UsageStats: Equatable, Codable {
    let rolling: UsageItem
    let weekly: UsageItem
    let monthly: UsageItem
}

/// Non-secret payload published by the app: percentages and reset times only.
/// The API key never leaves the Keychain.
struct WidgetSnapshot: Equatable, Codable {
    let stats: UsageStats
    let fetchedAt: Date
}

extension UsageStats {
    static let sample = UsageStats(
        rolling: UsageItem(status: "ok", percent: 42, resetsAt: Date().addingTimeInterval(3600)),
        weekly: UsageItem(status: "ok", percent: 55, resetsAt: Date().addingTimeInterval(86400)),
        monthly: UsageItem(status: "ok", percent: 30, resetsAt: Date().addingTimeInterval(604_800))
    )
}
