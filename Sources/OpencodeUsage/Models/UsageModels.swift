import Foundation

struct UsageItem: Equatable, Codable {
    let status: String
    let percent: Int
    let resetsAt: Date
}

struct BalanceInfo: Equatable, Codable {
    let amount: Double
    let currency: String?
    let asOf: Date?

    init(amount: Double, currency: String? = nil, asOf: Date? = nil) {
        self.amount = amount
        self.currency = currency
        self.asOf = asOf
    }

    /// Formatted for display, e.g. "$4.10".
    var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency ?? "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? String(format: "$%.2f", amount)
    }
}

struct UsageStats: Equatable, Codable {
    let rolling: UsageItem
    let weekly: UsageItem
    let monthly: UsageItem
    let balance: BalanceInfo?

    init(rolling: UsageItem, weekly: UsageItem, monthly: UsageItem, balance: BalanceInfo? = nil) {
        self.rolling = rolling
        self.weekly = weekly
        self.monthly = monthly
        self.balance = balance
    }
}

struct UsageResponse: Codable {
    let usage: UsageStats
    let balance: BalanceInfo?

    init(usage: UsageStats, balance: BalanceInfo? = nil) {
        self.usage = usage
        self.balance = balance
    }

    /// Top-level balance wins; falls back to a balance nested inside `usage`.
    var availableCredits: BalanceInfo? {
        balance ?? usage.balance
    }
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

// MARK: - Flexible balance decoding

/// Balance aliases accepted at any level. The upstream API proposal uses
/// top-level `balance: { usd, currency, asOf }`; other shapes (plain number,
/// `credits`, `availableCredits`) decode too so the app picks up whichever
/// form the server eventually ships.
private let balanceAliases = ["balance", "credits", "creditBalance", "availableCredits", "available_credits"]

private let balanceAmountKeys = ["usd", "balance", "credits", "amount", "value", "available", "remaining", "total"]

extension BalanceInfo {
    init(from decoder: Decoder) throws {
        var currency: String? = nil
        var amount: Double?
        var asOf: Date? = nil

        // Plain number: `"balance": 4.10` (or `"4.10"`)
        if let single = try? decoder.singleValueContainer(),
           let direct = try? single.decode(Double.self)
        {
            amount = direct
        } else if let single = try? decoder.singleValueContainer(),
                  let intDirect = try? single.decode(Int.self)
        {
            amount = Double(intDirect)
        } else if let single = try? decoder.singleValueContainer(),
                  let stringDirect = try? single.decode(String.self),
                  let parsed = Double(stringDirect)
        {
            amount = parsed
        } else {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            for key in balanceAmountKeys {
                let dynamic = DynamicKey(key)
                if let value = try? container.decode(Double.self, forKey: dynamic) {
                    amount = value
                    break
                }
                if let intValue = try? container.decode(Int.self, forKey: dynamic) {
                    amount = Double(intValue)
                    break
                }
                if let stringValue = try? container.decode(String.self, forKey: dynamic),
                   let parsed = Double(stringValue)
                {
                    amount = parsed
                    break
                }
            }
            currency = try? container.decode(String.self, forKey: DynamicKey("currency"))
            for key in ["asOf", "as_at"] {
                if let date = try? container.decode(Date.self, forKey: DynamicKey(key)) {
                    asOf = date
                    break
                }
            }
        }

        guard let resolved = amount else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "No balance amount found")
            )
        }
        self.init(amount: resolved, currency: currency, asOf: asOf)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(amount, forKey: DynamicKey("usd"))
        if let currency {
            try container.encode(currency, forKey: DynamicKey("currency"))
        }
        if let asOf {
            try container.encode(asOf, forKey: DynamicKey("asOf"))
        }
    }
}

extension UsageStats {
    enum CodingKeys: String, CodingKey {
        case rolling
        case weekly
        case monthly
        case balance
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rolling = try container.decode(UsageItem.self, forKey: .rolling)
        weekly = try container.decode(UsageItem.self, forKey: .weekly)
        monthly = try container.decode(UsageItem.self, forKey: .monthly)
        // Optional balance nested inside `usage` (tolerated; canonical spot is top level).
        balance = Self.decodeBalance(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rolling, forKey: .rolling)
        try container.encode(weekly, forKey: .weekly)
        try container.encode(monthly, forKey: .monthly)
        if let balance {
            try container.encode(balance, forKey: .balance)
        }
    }

    fileprivate static func decodeBalance(from decoder: Decoder) -> BalanceInfo? {
        guard let container = try? decoder.container(keyedBy: DynamicKey.self) else { return nil }
        for key in balanceAliases {
            if let info = try? container.decode(BalanceInfo.self, forKey: DynamicKey(key)) {
                return info
            }
        }
        return nil
    }
}

extension UsageResponse {
    enum CodingKeys: String, CodingKey {
        case usage
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        usage = try container.decode(UsageStats.self, forKey: .usage)
        balance = UsageStats.decodeBalance(from: decoder)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: DynamicKey.self)
        try container.encode(usage, forKey: DynamicKey("usage"))
        if let balance {
            try container.encode(balance, forKey: DynamicKey("balance"))
        }
    }
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init(_ stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(stringValue: String) {
        self.init(stringValue)
    }

    init?(intValue: Int) {
        stringValue = "\(intValue)"
        self.intValue = intValue
    }
}
