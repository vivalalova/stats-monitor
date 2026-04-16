import AppKit

struct MenuBarItem: Equatable, Identifiable {
    let panel: PanelID
    let symbol: String
    let text: String
    let color: NSColor
    let symbolPaletteColors: [NSColor]?

    var id: PanelID { panel }

    init(
        panel: PanelID,
        symbol: String,
        text: String,
        color: NSColor,
        symbolPaletteColors: [NSColor]? = nil
    ) {
        self.panel = panel
        self.symbol = symbol
        self.text = text
        self.color = color
        self.symbolPaletteColors = symbolPaletteColors
    }

    static func == (lhs: MenuBarItem, rhs: MenuBarItem) -> Bool {
        lhs.panel == rhs.panel &&
        lhs.symbol == rhs.symbol &&
        lhs.text == rhs.text &&
        lhs.color.isEqual(rhs.color) &&
        paletteColorsEqual(lhs.symbolPaletteColors, rhs.symbolPaletteColors)
    }

    private static func paletteColorsEqual(_ lhs: [NSColor]?, _ rhs: [NSColor]?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (left?, right?):
            guard left.count == right.count else { return false }
            return zip(left, right).allSatisfy { $0.isEqual($1) }
        default:
            return false
        }
    }

    var paddedText: String {
        MenuBarTextLayout.paddedText(text, for: panel)
    }

    var textSlotWidth: CGFloat {
        MenuBarTextLayout.slotWidth(for: panel)
    }
}

@MainActor
extension SystemMonitor {
    func menuBarItems(settings: AppSettings) -> [MenuBarItem] {
        var items: [MenuBarItem] = []
        appendMenuBarItem(to: &items, isVisible: settings.showCPU, panel: .cpu, symbol: "cpu", text: cpuMenuText)
        appendMenuBarItem(to: &items, isVisible: settings.showGPU, panel: .gpu, symbol: "display", text: gpuMenuText)
        appendMenuBarItem(to: &items, isVisible: settings.showMemory, panel: .memory, symbol: "memorychip", text: memoryMenuText)
        appendMenuBarItem(to: &items, isVisible: settings.showDisk, panel: .disk, symbol: "internaldrive", text: diskMenuText)
        appendMenuBarItem(to: &items, isVisible: settings.showNetwork, panel: .network, symbol: "network", text: networkMenuText)
        appendMenuBarItem(
            to: &items,
            isVisible: settings.showPowerPanel && hasPower,
            panel: .power,
            symbol: powerMenuSymbol,
            text: powerMenuText
        )
        appendMenuBarItem(
            to: &items,
            isVisible: settings.showThermal && hasThermal,
            panel: .thermal,
            symbol: "thermometer.medium",
            text: thermalMenuText,
            color: thermalMenuColor,
            symbolPaletteColors: thermalMenuSymbolPaletteColors
        )
        appendMenuBarItem(to: &items, isVisible: settings.showFans && hasFans, panel: .fans, symbol: "wind", text: fansMenuText)
        return items
    }

    var thermalMenuColor: NSColor {
        thermalPressureState == .critical ? .systemRed : .labelColor
    }

    var thermalMenuSymbolPaletteColors: [NSColor]? {
        guard thermalPressureState == .critical else { return nil }
        return [.systemRed, .systemOrange]
    }

    private func appendMenuBarItem(
        to items: inout [MenuBarItem],
        isVisible: Bool,
        panel: PanelID,
        symbol: String,
        text: String,
        color: NSColor = .labelColor,
        symbolPaletteColors: [NSColor]? = nil
    ) {
        guard isVisible else { return }
        items.append(MenuBarItem(
            panel: panel,
            symbol: symbol,
            text: text,
            color: color,
            symbolPaletteColors: symbolPaletteColors
        ))
    }
}
