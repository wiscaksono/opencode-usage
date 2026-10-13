import Foundation

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

struct UsageResponse: Codable {
    let usage: UsageStats
}

enum UsageLevel: Equatable {
    case safe
    case elevated
    case critical

    init(percent: Int) {
        switch percent {
        case ..<51: self = .safe
        case ..<81: self = .elevated
        default: self = .critical
        }
    }
}

/// Visual style for the macOS menu-bar status item.
enum MenuBarStyle: String, Equatable {
    /// Show the bundled OpenCode logo (template image, tinted by the menu bar).
    case logo
    /// Show colored percentage pills for rolling/weekly/monthly usage.
    case badges
}
