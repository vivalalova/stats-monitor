import AppKit

enum MenuBarTextLayout {
    static let contentInset: CGFloat = 6
    static let symbolPointSize: CGFloat = 11
    static let textFontSize: CGFloat = 12
    static let iconTextSpacing: CGFloat = 3
    static let itemHorizontalPadding: CGFloat = 2

    static var textFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: textFontSize, weight: .regular)
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

    static func slotWidth(for panel: PanelID) -> CGFloat {
        let template = String(repeating: "0", count: slotLength(for: panel))
        return NSAttributedString(
            string: template,
            attributes: [.font: textFont]
        ).size().width
    }
}
