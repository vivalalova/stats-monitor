import AppKit
import SwiftUI

struct MenuBarItemLabel: View {
    let icon: String
    let text: String
    let fixedTextWidth: CGFloat?
    var textColor: Color = .primary
    var iconPaletteColors: [Color]? = nil

    init(
        icon: String,
        text: String,
        fixedTextWidth: CGFloat? = nil,
        textColor: Color = .primary,
        iconPaletteColors: [Color]? = nil
    ) {
        self.icon = icon
        self.text = text
        self.fixedTextWidth = fixedTextWidth
        self.textColor = textColor
        self.iconPaletteColors = iconPaletteColors
    }

    init(item: MenuBarItem) {
        self.init(
            icon: item.symbol,
            text: item.text,
            fixedTextWidth: item.textSlotWidth,
            textColor: Color(nsColor: item.color),
            iconPaletteColors: item.symbolPaletteColors?.map(Color.init(nsColor:))
        )
    }

    var body: some View {
        HStack(spacing: MenuBarTextLayout.iconTextSpacing) {
            iconView
            Text(text)
                .font(.system(size: MenuBarTextLayout.textFontSize, weight: .regular, design: .monospaced))
                .lineLimit(1)
                .foregroundStyle(textColor)
                .frame(width: fixedTextWidth, alignment: .trailing)
        }
        .padding(.horizontal, MenuBarTextLayout.itemHorizontalPadding)
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconPaletteColors, iconPaletteColors.count >= 2 {
            Image(systemName: icon)
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(iconPaletteColors[0], iconPaletteColors[1])
        } else {
            Image(systemName: icon)
        }
    }
}

struct CombinedMenuBarLabel: View {
    var monitor: SystemMonitor
    var settings: AppSettings

    var body: some View {
        HStack(spacing: 0) {
            ForEach(monitor.menuBarItems(settings: settings)) { item in
                MenuBarItemLabel(item: item)
            }
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("StatsMonitor")
        .fixedSize()
    }
}

#Preview("All Metrics", traits: .sizeThatFitsLayout) {
    HStack(spacing: 0) {
        MenuBarItemLabel(icon: "cpu", text: "42%", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .cpu))
        MenuBarItemLabel(icon: "display", text: "18%", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .gpu))
        MenuBarItemLabel(icon: "memorychip", text: "71%", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .memory))
        MenuBarItemLabel(icon: "internaldrive", text: "10M", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .disk))
        MenuBarItemLabel(icon: "network", text: "1.2M", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .network))
        MenuBarItemLabel(icon: "bolt.fill", text: "21W", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .power))
        MenuBarItemLabel(icon: "thermometer.medium", text: "68C", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .thermal))
        MenuBarItemLabel(icon: "wind", text: "2.5K", fixedTextWidth: MenuBarTextLayout.slotWidth(for: .fans))
    }
    .padding()
}

#Preview("Thermal Critical", traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    settings.showCPU = false
    settings.showGPU = false
    settings.showMemory = false
    settings.showDisk = false
    settings.showNetwork = false
    settings.showBattery = false
    settings.showThermal = true
    settings.showPower = false
    settings.showFans = false

    let monitor = SystemMonitor(settings: settings)
    monitor.record(thermalPressureState: .critical)

    return CombinedMenuBarLabel(monitor: monitor, settings: settings)
        .padding()
}
