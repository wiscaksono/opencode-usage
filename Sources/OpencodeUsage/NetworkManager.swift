import Foundation
import os

enum NetworkError: Error, LocalizedError {
    case invalidData
    case parseError
    case requestFailed
    case notConfigured
    case authExpired

    var errorDescription: String? {
        switch self {
        case .invalidData: return "Invalid data received"
        case .parseError: return "Failed to parse server response"
        case .requestFailed: return "Request failed"
        case .notConfigured: return "Not configured. Please open Settings and paste your curl command."
        case .authExpired: return "Authentication expired. Please update your credentials in Settings."
        }
    }
}

final class NetworkManager: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "Network")

    func fetchUsage() async throws -> UsageStats {
        guard let apiURL = Config.apiURL else {
            logger.error("API URL not configured")
            throw NetworkError.notConfigured
        }

        var request = URLRequest(url: apiURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 15

        for (key, value) in Config.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        if let cookie = Config.authCookie {
            request.setValue(cookie, forHTTPHeaderField: "Cookie")
        } else {
            logger.error("Auth cookie not configured")
            throw NetworkError.notConfigured
        }

        logger.info("Fetching usage from API...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("API request failed with status: \(statusCode)")
            if statusCode == 401 || statusCode == 403 {
                throw NetworkError.authExpired
            }
            throw NetworkError.requestFailed
        }

        guard let rawString = String(data: data, encoding: .utf8) else {
            logger.error("Failed to decode response data to string")
            throw NetworkError.invalidData
        }

        logger.info("Parsing response...")
        return try parseResponse(rawString)
    }

    private func parseResponse(_ raw: String) throws -> UsageStats {
        // Try the SolidJS SSR hydration format first ($R[...] = { ... }).
        if let ssr = parseSSRUsage(from: raw) {
            logger.info("Parsed usage stats successfully (SSR format)")
            return ssr
        }

        // Fall back to the newer data-slot HTML format used by the web console.
        if let dataSlot = parseDataSlotUsage(from: raw) {
            logger.info("Parsed usage stats successfully (data-slot format)")
            return dataSlot
        }

        logger.error("Could not parse usage data in either known format")
        throw NetworkError.parseError
    }

    private func parseSSRUsage(from raw: String) -> UsageStats? {
        guard let rolling = try? extractItem(from: raw, label: "rollingUsage"),
              let weekly = try? extractItem(from: raw, label: "weeklyUsage"),
              let monthly = try? extractItem(from: raw, label: "monthlyUsage") else {
            return nil
        }
        return UsageStats(rolling: rolling, weekly: weekly, monthly: monthly)
    }

    private static let regexCache: [String: NSRegularExpression] = {
        let labels = ["rollingUsage", "weeklyUsage", "monthlyUsage"]
        var cache: [String: NSRegularExpression] = [:]
        for label in labels {
            let pattern = "\(label):\\s*\\$R\\[\\d+\\]\\s*=\\s*\\{\\s*status:\\s*\"([^\"]+)\",\\s*resetInSec:\\s*(\\d+),\\s*usagePercent:\\s*(\\d+)\\s*\\}"
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) {
                cache[label] = regex
            }
        }
        return cache
    }()

    private func extractItem(from raw: String, label: String) throws -> UsageItem {
        guard let regex = Self.regexCache[label] else {
            throw NetworkError.parseError
        }

        let nsRange = NSRange(location: 0, length: raw.utf16.count)
        guard let match = regex.firstMatch(in: raw, options: [], range: nsRange) else {
            logger.error("Regex failed to match label: \(label)")
            throw NetworkError.parseError
        }

        guard let statusRange = Range(match.range(at: 1), in: raw),
              let resetRange = Range(match.range(at: 2), in: raw),
              let percentRange = Range(match.range(at: 3), in: raw),
              let resetInSec = Int(raw[resetRange]),
              let usagePercent = Int(raw[percentRange]) else {
            logger.error("Failed to extract values for label: \(label)")
            throw NetworkError.parseError
        }

        let status = String(raw[statusRange])
        return UsageItem(status: status, resetInSec: resetInSec, usagePercent: usagePercent)
    }

    // MARK: - data-slot HTML fallback

    /// Parse the newer `data-slot` HTML format the OpenCode Go web console uses
    /// (usage-label / usage-value / reset-time-or-now), which carries the same
    /// Rolling / Weekly / Monthly usage windows as the SSR payload.
    private func parseDataSlotUsage(from raw: String) -> UsageStats? {
        let parts = raw.components(separatedBy: "data-slot=\"usage-item\"")
        guard parts.count > 1 else { return nil }

        var rolling: UsageItem?
        var weekly: UsageItem?
        var monthly: UsageItem?

        for part in parts.dropFirst() {
            guard let label = Self.capture(in: part, pattern: #"data-slot="usage-label">([^<]+)"#) else { continue }
            let lower = label.lowercased()
            guard let key = lower.contains("rolling") ? "rolling"
                    : lower.contains("weekly") ? "weekly"
                    : lower.contains("monthly") ? "monthly" : nil else { continue }

            guard let usageRaw = Self.capture(in: part, pattern: #"data-slot="usage-value">[^0-9]*(\d+(?:\.\d+)?)"#) else { continue }
            let usagePercent = Int(Double(usageRaw) ?? -1)
            guard usagePercent >= 0 else { continue }

            guard let resetSlot = Self.capture(in: part, pattern: #"data-slot="(reset-time|reset-now)""#),
                  let resetContent = Self.capture(in: part, pattern: #"data-slot="(?:reset-time|reset-now)">([\s\S]*?)</span>"#) else { continue }

            let cleaned = resetContent
                .replacingOccurrences(of: "<!--$-->", with: "")
                .replacingOccurrences(of: "<!--/-->", with: "")
                .replacingOccurrences(of: "^Resets?\\s*in\\s*", with: "", options: [.regularExpression, .caseInsensitive])
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let resetInSec: Int
            if resetSlot == "reset-now" {
                resetInSec = 0
            } else if let parsed = parseHumanReadableTime(cleaned) {
                resetInSec = parsed
            } else {
                continue
            }

            let item = UsageItem(status: "active", resetInSec: resetInSec, usagePercent: usagePercent)
            switch key {
            case "rolling": rolling = item
            case "weekly": weekly = item
            default: monthly = item
            }
        }

        guard let rolling, let weekly, let monthly else { return nil }
        return UsageStats(rolling: rolling, weekly: weekly, monthly: monthly)
    }

    /// First regex capture group in `text`, or nil when there is no match.
    private static func capture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]) else { return nil }
        let nsRange = NSRange(location: 0, length: text.utf16.count)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let capRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[capRange])
    }

    /// Parse human-readable durations like "1 hour 56 minutes", "6 days 2 hours",
    /// "26 days 17 hours" into seconds.
    private func parseHumanReadableTime(_ input: String) -> Int? {
        let normalized = input.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if ["reset-now", "reset now", "now", "resets now"].contains(normalized) {
            return 0
        }

        let pattern = #"(\d+(?:\.\d+)?)\s*(seconds?|minutes?|hours?|days?)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsRange = NSRange(location: 0, length: normalized.utf16.count)
        var total = 0.0
        var matched = false
        regex.enumerateMatches(in: normalized, options: [], range: nsRange) { match, _, _ in
            guard let match,
                  let valueRange = Range(match.range(at: 1), in: normalized),
                  let unitRange = Range(match.range(at: 2), in: normalized),
                  let value = Double(normalized[valueRange]) else { return }
            matched = true
            switch normalized[unitRange] {
            case let unit where unit.hasPrefix("day"): total += value * 86400
            case let unit where unit.hasPrefix("hour"): total += value * 3600
            case let unit where unit.hasPrefix("minute"): total += value * 60
            case let unit where unit.hasPrefix("second"): total += value
            default: break
            }
        }

        return matched ? Int(total) : nil
    }
}
