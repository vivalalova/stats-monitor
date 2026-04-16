import SwiftUI

struct MenuBarItemLabel: View {
    let icon: String
    let text: String
    var textColor: Color = .primary
    var iconPaletteColors: [Color]? = nil

    init(
        icon: String,
        text: String,
        textColor: Color = .primary,
        iconPaletteColors: [Color]? = nil
    ) {
        self.icon = icon
        self.text = text
        self.textColor = textColor
        self.iconPaletteColors = iconPaletteColors
    }

    init(item: MenuBarItem) {
        self.init(
            icon: item.symbol,
            text: item.text,
            textColor: Color(nsColor: item.color),
            iconPaletteColors: item.symbolPaletteColors?.map(Color.init(nsColor:))
        )
    }

    var body: some View {
        HStack(spacing: 4) {
            iconView
            Text(text)
                .monospacedDigit()
                .lineLimit(1)
                .foregroundStyle(textColor)
        }
        .padding(.horizontal, 4)
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
        MenuBarItemLabel(icon: "cpu",          text: "42%")
        MenuBarItemLabel(icon: "display",      text: "18%")
        MenuBarItemLabel(icon: "memorychip",   text: "71%")
        MenuBarItemLabel(icon: "internaldrive",text: "10.0 MB/s")
        MenuBarItemLabel(icon: "network",      text: "↓1.2 MB/s")
        MenuBarItemLabel(icon: "bolt.fill",    text: "21.3W")
        MenuBarItemLabel(icon: "thermometer.medium", text: "68.4°C")
        MenuBarItemLabel(icon: "wind",         text: "2470 RPM")
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
