import SwiftUI

struct SparklineView: View {
    let samples: [UsageSample]
    let currentPercent: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("Monthly history")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("24h")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            if samples.count < 2 {
                Text("Collecting history…")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 34, alignment: .center)
            } else {
                GeometryReader { geometry in
                    let points = points(in: geometry.size)

                    ZStack {
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: geometry.size.height - 0.5))
                            path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - 0.5))
                        }
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 1)

                        Path { path in
                            guard let first = points.first else { return }
                            path.move(to: first)
                            for point in points.dropFirst() {
                                path.addLine(to: point)
                            }
                        }
                        .stroke(
                            lineColor,
                            style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .frame(height: 34)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var lineColor: Color {
        switch UsageLevel(percent: currentPercent) {
        case .safe: .green
        case .elevated: .yellow
        case .critical: .red
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        let ordered = samples.sorted { $0.timestamp < $1.timestamp }
        guard let first = ordered.first?.timestamp,
              let last = ordered.last?.timestamp,
              last > first
        else {
            return []
        }

        let span = last.timeIntervalSince(first)
        return ordered.map { sample in
            let progress = sample.timestamp.timeIntervalSince(first) / span
            let clamped = min(max(sample.monthly, 0), 100)
            let x = size.width * progress
            let y = size.height - (CGFloat(clamped) / 100 * size.height)
            return CGPoint(x: x, y: y)
        }
    }
}
