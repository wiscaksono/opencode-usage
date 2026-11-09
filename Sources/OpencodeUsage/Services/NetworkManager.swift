import Foundation
import os

enum NetworkError: Error, LocalizedError {
    case parseError
    case requestFailed
    case notConfigured
    case authExpired

    var errorDescription: String? {
        switch self {
        case .parseError: "Failed to parse server response"
        case .requestFailed: "Request failed"
        case .notConfigured: "Not configured. Sign in to OpenCode or paste an API key in Settings."
        case .authExpired: "Authentication expired. Open OpenCode or update your API key in Settings."
        }
    }
}

final class NetworkManager: @unchecked Sendable {
    private let logger = Logger(subsystem: "com.wiscaksono.opencode-usage", category: "Network")
    private let endpoint = URL(string: "https://opencode.ai/zen/go/v1/usage")!

    func fetchUsage() async throws -> UsageStats {
        guard let apiKey = AppSettings.effectiveToken else {
            logger.error("No OpenCode credential available")
            throw NetworkError.notConfigured
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "GET"
        request.timeoutInterval = 15
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        logger.info("Fetching usage from API...")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200 ... 299).contains(httpResponse.statusCode)
        else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            logger.error("API request failed with status: \(statusCode)")
            if statusCode == 401 || statusCode == 403 {
                throw NetworkError.authExpired
            }
            throw NetworkError.requestFailed
        }

        logger.info("Parsing response...")
        do {
            let decoded = try Self.decoder.decode(UsageResponse.self, from: data)
            logger.info("Parsed usage stats successfully")
            return decoded.usage
        } catch {
            logger.error("Failed to decode response: \(error.localizedDescription)")
            throw NetworkError.parseError
        }
    }

    /// Internal (not private) so tests can exercise the decoding pipeline directly.
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let formatters = SharedFormatters.shared
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            if let date = formatters.withFractionalSeconds.date(from: dateString) {
                return date
            }
            if let date = formatters.standard.date(from: dateString) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date: \(dateString)")
        }
        return decoder
    }()
}

/// ISO8601DateFormatter is not Sendable but safe to share for parsing; boxed so the
/// @Sendable decode closure can capture it without tripping strict concurrency.
private final class SharedFormatters: @unchecked Sendable {
    static let shared = SharedFormatters()

    let withFractionalSeconds = ISO8601DateFormatter()
    let standard = ISO8601DateFormatter()

    private init() {
        withFractionalSeconds.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    }
}
