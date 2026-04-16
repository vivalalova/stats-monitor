import AppKit

@MainActor
enum StatusBarLabelRenderer {
    private static let contentInset: CGFloat = 6
    private static let symbolPointSize: CGFloat = 11
    private static let textFontSize: CGFloat = 12

    static func makeAttributedTitle(monitor: SystemMonitor, settings: AppSettings) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let segments = makeSegments(monitor: monitor, settings: settings)

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                result.append(separatorString)
            }
            result.append(makeSegment(
                symbol: segment.symbol,
                text: segment.text,
                color: segment.color,
                symbolPaletteColors: segment.symbolPaletteColors
            ))
        }

        return result
    }

    static func makeSegments(monitor: SystemMonitor, settings: AppSettings) -> [MenuBarItem] {
        monitor.menuBarItems(settings: settings)
    }

    static func measuredTitleWidth(for segments: [MenuBarItem]) -> CGFloat {
        guard !segments.isEmpty else { return 0 }

        return segments.enumerated().reduce(0) { partialWidth, item in
            let spacing = item.offset > 0 ? separatorWidth : 0
            return partialWidth + spacing + segmentWidth(for: item.element)
        }
    }

    static func panel(at x: CGFloat, in segments: [MenuBarItem]) -> PanelID? {
        guard !segments.isEmpty else { return nil }

        let clampedX = max(0, x - contentInset)
        var currentMinX: CGFloat = 0

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                currentMinX += separatorWidth
            }

            let segmentMaxX = currentMinX + segmentWidth(for: segment)
            if clampedX < segmentMaxX {
                return segment.panel
            }
            currentMinX = segmentMaxX
        }

        return segments.last?.panel
    }

    private static func makeSegment(
        symbol: String,
        text: String,
        color: NSColor,
        symbolPaletteColors: [NSColor]?
    ) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let attachment = NSTextAttachment()

        attachment.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration(paletteColors: symbolPaletteColors))

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttributes([
            .baselineOffset: -1,
            .foregroundColor: color,
        ], range: NSRange(location: 0, length: attachmentString.length))
        result.append(attachmentString)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: textFontSize, weight: .regular),
            .foregroundColor: color,
        ]
        result.append(NSAttributedString(string: " \(text)", attributes: textAttributes))
        return result
    }

    private static func segmentWidth(for segment: MenuBarItem) -> CGFloat {
        makeSegment(
            symbol: segment.symbol,
            text: segment.text,
            color: segment.color,
            symbolPaletteColors: segment.symbolPaletteColors
        ).size().width
    }

    private static func symbolConfiguration(paletteColors: [NSColor]?) -> NSImage.SymbolConfiguration {
        let baseConfiguration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)

        guard let paletteColors else {
            return baseConfiguration
        }

        let paletteConfiguration = NSImage.SymbolConfiguration(paletteColors: paletteColors)
        let multicolorConfiguration = NSImage.SymbolConfiguration.preferringMulticolor()
        return baseConfiguration.applying(paletteConfiguration).applying(multicolorConfiguration)
    }

    private static var separatorString: NSAttributedString {
        NSAttributedString(
            string: "  ",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: textFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        )
    }

    private static var separatorWidth: CGFloat {
        separatorString.size().width
    }
}
