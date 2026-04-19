import AppKit

enum MenuBarTextLayout {
    struct Style {
        let rowCount: Int
        let contentInset: CGFloat
        let segmentSpacing: CGFloat
        let rowSpacing: CGFloat
        let iconSpacing: CGFloat
        let iconSlotSize: CGFloat
        let symbolPointSize: CGFloat
        let textFontSize: CGFloat
    }

    static let statusItemHeight: CGFloat = 22
    static let compactRowThreshold = 5

    static func style(forRowCount rowCount: Int) -> Style {
        if rowCount > 1 {
            return Style(
                rowCount: rowCount,
                contentInset: 3,
                segmentSpacing: 2,
                rowSpacing: 0,
                iconSpacing: 1,
                iconSlotSize: 12,
                symbolPointSize: 10,
                textFontSize: 10
            )
        }

        return Style(
            rowCount: rowCount,
            contentInset: 6,
            segmentSpacing: 4,
            rowSpacing: 0,
            iconSpacing: 2,
            iconSlotSize: 13,
            symbolPointSize: 11,
            textFontSize: 12
        )
    }

    static func textFont(for style: Style) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: style.textFontSize, weight: .medium)
    }

    static func slotLength(for panel: PanelID) -> Int {
        switch panel {
        case .cpu, .gpu, .memory, .disk, .network, .power, .thermal, .fans:
            return 4
        }
    }

    static func paddedText(_ text: String, for panel: PanelID) -> String {
        let slotLength = slotLength(for: panel)
        guard text.count < slotLength else { return text }
        return String(repeating: " ", count: slotLength - text.count) + text
    }

    static func slotWidth(for panel: PanelID, style: Style = style(forRowCount: 1)) -> CGFloat {
        let template = String(repeating: "0", count: slotLength(for: panel))
        return NSAttributedString(
            string: template,
            attributes: [.font: textFont(for: style)]
        ).size().width
    }
}
