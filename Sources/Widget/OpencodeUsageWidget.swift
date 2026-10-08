import AppIntents
import SwiftUI
import WidgetKit

struct UsageEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let error: String?
}

struct RefreshUsageIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Usage"
    static let description: IntentDescription = .init("Ask the menu bar app to refetch usage.")

    func perform() async throws -> some IntentResult {
        // No networking in the extension: drop a flag file the app polls,
        // then reload so the widget at least re-reads the latest snapshot.
        WidgetDataStore.requestRefresh()
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetDataStore.widgetKind)
        return .result()
    }
}

struct Provider: TimelineProvider {
    func placeholder(in _: Context) -> UsageEntry {
        UsageEntry(date: .now, snapshot: WidgetSnapshot(stats: .sample, fetchedAt: .now), error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping @Sendable (UsageEntry) -> Void) {
        if context.isPreview {
            completion(UsageEntry(date: .now, snapshot: WidgetSnapshot(stats: .sample, fetchedAt: .now), error: nil))
            return
        }
        Task { await completion(fetchEntry()) }
    }

    func getTimeline(in _: Context, completion: @escaping @Sendable (Timeline<UsageEntry>) -> Void) {
        Task {
            let entry = await fetchEntry()
            completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(300))))
        }
    }

    private func fetchEntry() async -> UsageEntry {
        guard let snapshot = WidgetDataStore.readSnapshot() else {
            return UsageEntry(
                date: .now,
                snapshot: nil,
                error: "Open the OpenCode Usage app to set your API key"
            )
        }
        return UsageEntry(date: .now, snapshot: snapshot, error: nil)
    }
}

struct ResetCountdownText: View {
    let date: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { _ in
            Text("(Reset in \(Self.countdown(to: date)))")
                .monospacedDigit()
        }
    }

    static func countdown(to date: Date) -> String {
        let total = max(0, Int(date.timeIntervalSinceNow))
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let minutes = (total % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h"
        }
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct ColoredProgressBar: View {
    let percent: Int
    let color: Color
    var height: CGFloat = 5

    var body: some View {
        GeometryReader { geo in
            let fraction = min(1.0, max(0.0, Double(percent) / 100.0))
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: height)
    }
}

struct OpencodeUsageWidgetEntryView: View {
    var entry: UsageEntry
    @Environment(\.widgetFamily) var family

    private static let settingsURL = URL(string: "opencodeusage://settings")!

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: mediumView(snapshot)
            default: smallView(snapshot)
            }
        } else {
            Label(entry.error ?? "Loading…", systemImage: "exclamationmark.triangle")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func smallView(_ snapshot: WidgetSnapshot) -> some View {
        let s = snapshot.stats
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(s.rolling.percent)%")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(color(for: s.rolling.percent))
                        .minimumScaleFactor(0.7)
                    Text("Rolling").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    refreshButton
                    settingsButton
                }
            }
            ResetCountdownText(date: s.rolling.resetsAt)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            miniRow("W", s.weekly)
            miniRow("M", s.monthly)
        }
    }

    private func mediumView(_ snapshot: WidgetSnapshot) -> some View {
        let s = snapshot.stats
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Text("OpenCode Usage").font(.caption2).foregroundStyle(.secondary)
                Text(updatedAgo(snapshot.fetchedAt))
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
                Spacer()
                refreshButton
                settingsButton
            }
            row("Rolling", s.rolling)
            row("Weekly", s.weekly)
            row("Monthly", s.monthly)
        }
    }

    private var refreshButton: some View {
        Button(intent: RefreshUsageIntent()) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
    }

    private var settingsButton: some View {
        Link(destination: Self.settingsURL) {
            Image(systemName: "gearshape")
                .font(.system(size: 11, weight: .medium))
                .frame(width: 18, height: 18)
        }
        .foregroundStyle(.secondary)
    }

    private func miniRow(_ label: String, _ item: UsageItem) -> some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundStyle(.secondary).frame(width: 12, alignment: .leading)
            ColoredProgressBar(percent: item.percent, color: color(for: item.percent), height: 4)
            Text("\(item.percent)%").font(.caption2).monospacedDigit().frame(width: 32, alignment: .trailing)
        }
    }

    private func row(_ title: String, _ item: UsageItem) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                ResetCountdownText(date: item.resetsAt)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(item.percent)%").font(.caption).fontWeight(.semibold).monospacedDigit()
            }
            ColoredProgressBar(percent: item.percent, color: color(for: item.percent), height: 6)
        }
    }

    private func updatedAgo(_ date: Date) -> String {
        let seconds = max(0, Int(-date.timeIntervalSinceNow))
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        if hours > 0 {
            return "Updated \(hours)h \(minutes)m ago"
        }
        return "Updated \(minutes)m ago"
    }

    private func color(for percent: Int) -> Color {
        switch percent {
        case 0 ... 50: .green
        case 51 ... 80: .yellow
        default: .red
        }
    }
}

@main
struct OpencodeUsageWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetDataStore.widgetKind, provider: Provider()) { entry in
            OpencodeUsageWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("OpenCode Usage")
        .description("Rolling, weekly and monthly usage at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
