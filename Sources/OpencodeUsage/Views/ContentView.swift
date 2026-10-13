import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var viewModel: UsageViewModel
    @State private var showSettings = false
    @FocusState private var focusedField: FocusableField?

    private static let consoleURL = URL(string: "https://opencode.ai/console")!

    private var isSettingsVisible: Bool {
        viewModel.needsSetup || showSettings
    }

    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            if isSettingsVisible {
                SettingsView(
                    viewModel: viewModel,
                    isPresented: $showSettings,
                    isFirstSetup: viewModel.needsSetup
                )
            } else {
                contentView
            }
            Divider()
            footerView
        }
        .frame(width: 260)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 6) {
            Text("OpenCode Usage")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            if !isSettingsVisible {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
                    .opacity(viewModel.isLoading ? 1 : 0)

                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .settings)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentView: some View {
        if let stats = viewModel.stats {
            VStack(alignment: .leading, spacing: 0) {
                usageCard(title: "Rolling", item: stats.rolling)
                Divider()
                usageCard(title: "Weekly", item: stats.weekly)
                Divider()
                usageCard(title: "Monthly", item: stats.monthly)
                if AppSettings.showCredits {
                    Divider()
                    creditsCard(balance: viewModel.balance)
                }
            }
        } else if let error = viewModel.errorMessage {
            errorBanner(error)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        } else {
            loadingView
        }
    }

    // MARK: - Usage Card

    private func usageCard(title: String, item: UsageItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(" (Resets in \(formatDuration(seconds: secondsUntil(item.resetsAt))))")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()

                Spacer()

                Text("\(item.percent)%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.primary)
                    .monospacedDigit()
            }

            ProgressView(value: Double(item.percent), total: 100)
                .progressViewStyle(.linear)
                .tint(colorForPercent(item.percent))
                .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    // MARK: - Credits Card

    private func creditsCard(balance: BalanceInfo?) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "creditcard")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text("Available credits")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Spacer()

            Text(balance?.formatted ?? "—")
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(.primary)
                .monospacedDigit()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .help(balance != nil ? "Top-up balance apart from the subscription" : "Top-up balance — shown when the API returns it")
    }

    // MARK: - Loading

    private var loadingView: some View {
        VStack(spacing: 8) {
            ProgressView()
                .controlSize(.small)
            Text("Loading usage...")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Error Banner

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
            Text(message)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: 8) {
            if !isSettingsVisible {
                Button {
                    viewModel.refresh()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .refresh)
            }

            Spacer()

            if !isSettingsVisible {
                Button {
                    NSWorkspace.shared.open(Self.consoleURL)
                } label: {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focused($focusedField, equals: .dashboard)
                .help("Open OpenCode console")
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .focused($focusedField, equals: .quit)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func colorForPercent(_ percent: Int) -> Color {
        if AppSettings.progressAccent {
            return Color(NSColor.controlAccentColor)
        }
        switch UsageLevel(percent: percent) {
        case .safe: return .green
        case .elevated: return .yellow
        case .critical: return .red
        }
    }
}

enum FocusableField: Hashable {
    case refresh, dashboard, settings, quit
}
