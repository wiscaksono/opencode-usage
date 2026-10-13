import Foundation
@testable import OpencodeUsage
import Testing

struct UsageDecodingTests {
    private static func json(resetsAt: String) -> Data {
        """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10,  "resetsAt": "\(resetsAt)" },
            "weekly":  { "status": "allowed", "percent": 34,  "resetsAt": "\(resetsAt)" },
            "monthly": { "status": "allowed", "percent": 56,  "resetsAt": "\(resetsAt)" }
          }
        }
        """.data(using: .utf8)!
    }

    @Test func decodesFractionalSecondsTimestamps() throws {
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: Self.json(resetsAt: "2026-08-22T12:00:00.123Z"))
        #expect(response.usage.rolling.percent == 10)
        #expect(response.usage.rolling.resetsAt.timeIntervalSince1970 == 1_787_400_000.123)
    }

    @Test func decodesWholeSecondTimestamps() throws {
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: Self.json(resetsAt: "2026-08-22T12:00:00Z"))
        #expect(response.usage.monthly.resetsAt == Date(timeIntervalSince1970: 1_787_400_000))
    }

    @Test func invalidDateThrowsDecodingError() {
        #expect(throws: DecodingError.self) {
            try NetworkManager.decoder.decode(UsageResponse.self, from: Self.json(resetsAt: "not-a-date"))
        }
    }

    @Test func usageLevelRoundTripFromDecodedPercent() throws {
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: Self.json(resetsAt: "2026-08-22T12:00:00Z"))
        #expect(UsageLevel(percent: response.usage.weekly.percent) == .safe)
    }

    @Test func missingBalanceDecodesAsNil() throws {
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: Self.json(resetsAt: "2026-08-22T12:00:00Z"))
        #expect(response.availableCredits == nil)
    }

    @Test func decodesTopLevelBalanceObject() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" }
          },
          "balance": { "usd": 4.10, "currency": "USD" }
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.amount == 4.10)
    }

    @Test func decodesTopLevelPlainNumberBalance() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" }
          },
          "credits": 12.5
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.amount == 12.5)
    }

    @Test func decodesNestedUsageBalanceFallback() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" },
            "balance": { "amount": 7.25 }
          }
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.amount == 7.25)
    }

    @Test func topLevelBalanceWinsOverNested() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" },
            "balance": { "usd": 1.0 }
          },
          "balance": { "usd": 2.0 }
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.amount == 2.0)
    }

    @Test func decodesBalanceAsOfTimestamp() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" }
          },
          "balance": { "usd": 4.10, "currency": "USD", "asOf": "2026-08-22T12:00:00Z" }
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.asOf == Date(timeIntervalSince1970: 1_787_400_000))
    }

    @Test func decodesStringBalance() throws {
        let data = """
        {
          "usage": {
            "rolling": { "status": "allowed", "percent": 10, "resetsAt": "2026-08-22T12:00:00Z" },
            "weekly": { "status": "allowed", "percent": 34, "resetsAt": "2026-08-22T12:00:00Z" },
            "monthly": { "status": "allowed", "percent": 56, "resetsAt": "2026-08-22T12:00:00Z" }
          },
          "balance": "9.99"
        }
        """.data(using: .utf8)!
        let response = try NetworkManager.decoder.decode(UsageResponse.self, from: data)
        #expect(response.availableCredits?.amount == 9.99)
    }
}
