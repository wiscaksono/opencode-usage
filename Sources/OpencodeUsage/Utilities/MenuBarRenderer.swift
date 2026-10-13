import AppKit

/// Renders the macOS menu-bar status item to an `NSImage` so that
/// per-pill foreground colors survive the SwiftUI `MenuBarExtra` label
/// pipeline (which otherwise drops `foregroundStyle` on `Text` and
/// tends to clip multi-view containers to the first child).
@MainActor
enum MenuBarRenderer {
    /// Returns the image for the chosen style. Logo ignores `stats`;
    /// badges shows `—` until stats arrive.
    static func image(for stats: UsageStats?, style: MenuBarStyle) -> NSImage {
        switch style {
        case .logo: logoImage
        case .badges: badgesImage(for: stats)
        }
    }

    // MARK: - Logo

    /// Template image loaded once from the bundled `opencode-logo.png`,
    /// falling back to an SF Symbol if the asset is missing.
    private static let logoImage: NSImage = {
        let url = Bundle.module.url(forResource: "opencode-logo", withExtension: "png")
        let img = url.flatMap { NSImage(contentsOf: $0) }
            ?? NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "OpenCode")
            ?? NSImage()
        img.isTemplate = true
        img.size = NSSize(width: 16, height: 16)
        return img
    }()

    // MARK: - Badges

    private static func badgesImage(for stats: UsageStats?) -> NSImage {
        let font = NSFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
        let textColor = currentTextColor()
        guard let stats else {
            return drawPills(font: font, entries: [
                ("—", NSColor.darkGray, textColor),
            ])
        }
        let entries: [(text: String, fill: NSColor, textColor: NSColor)] =
            [stats.rolling.percent, stats.weekly.percent, stats.monthly.percent]
                .map { percent in
                    ("\(percent)%", tintColor(for: percent), textColor)
                }
        return drawPills(font: font, entries: entries)
    }

    private static func drawPills(
        font: NSFont,
        entries: [(text: String, fill: NSColor, textColor: NSColor)]
    ) -> NSImage {
        guard !entries.isEmpty else { return NSImage(size: .zero) }

        // Measure each pill to size the canvas.
        var pillWidths: [CGFloat] = []
        var maxTextHeight: CGFloat = 0
        for entry in entries {
            let attrs: [NSAttributedString.Key: Any] = [.font: font]
            let size = (entry.text as NSString).size(withAttributes: attrs)
            pillWidths.append(ceil(size.width) + pillPaddingX * 2)
            maxTextHeight = max(maxTextHeight, size.height)
        }
        let pillH = ceil(maxTextHeight) + pillVerticalPadding * 2
        let totalWidth = pillWidths.reduce(0, +)
            + pillSpacing * CGFloat(entries.count - 1)
        let pointSize = NSSize(width: totalWidth, height: pillH)

        // Render at 2x for retina sharpness.
        let scale: CGFloat = 2
        let pixelW = max(1, Int(pointSize.width * scale))
        let pixelH = max(1, Int(pointSize.height * scale))

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: pixelW,
            pixelsHigh: pixelH,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 32
        ) else {
            return NSImage(size: pointSize)
        }

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let context = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current = context
        if let cg = context?.cgContext {
            cg.scaleBy(x: scale, y: scale)
        }

        var x: CGFloat = 0
        for (i, entry) in entries.enumerated() {
            let pillW = pillWidths[i]
            let pillRect = NSRect(x: x, y: 0, width: pillW, height: pillH)
            let path = NSBezierPath(
                roundedRect: pillRect,
                xRadius: cornerRadius,
                yRadius: cornerRadius
            )
            entry.fill.setFill()
            path.fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: entry.textColor,
            ]
            let textSize = (entry.text as NSString).size(withAttributes: attrs)
            let textRect = NSRect(
                x: x + (pillW - textSize.width) / 2,
                y: (pillH - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            (entry.text as NSString).draw(in: textRect, withAttributes: attrs)

            x += pillW + pillSpacing
        }

        let image = NSImage(size: pointSize)
        image.addRepresentation(rep)
        image.isTemplate = false
        return image
    }

    // MARK: - Style

    private static let cornerRadius: CGFloat = 3
    private static let pillPaddingX: CGFloat = 5
    private static let pillSpacing: CGFloat = 4
    private static let pillVerticalPadding: CGFloat = 2

    /// Always white so the percentage reads against any pill background.
    private static func currentTextColor() -> NSColor {
        .white
    }

    /// Pill fills keyed off `UsageLevel` so the menu bar and the popup
    /// always agree on what counts as elevated.
    ///
    /// White 13pt text needs roughly 3.5:1 against the fill, and the
    /// system colors land well below that (systemGreen 2.2:1,
    /// systemYellow 1.5:1), so all three shades are picked by hand.
    private static func tintColor(for percent: Int) -> NSColor {
        switch UsageLevel(percent: percent) {
        case .safe: NSColor(srgbRed: 0.16, green: 0.58, blue: 0.28, alpha: 1.0)
        case .elevated: NSColor(srgbRed: 0.68, green: 0.47, blue: 0.0, alpha: 1.0)
        case .critical: NSColor(srgbRed: 0.78, green: 0.16, blue: 0.12, alpha: 1.0)
        }
    }
}
