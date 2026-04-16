import SwiftUI

struct MenuBarItemLabel: View {
    let icon: String
    let text: String
    var textColor: Color = .primary
    var iconPaletteColors: [Color]? = nil

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
            if settings.showCPU {
                MenuBarItemLabel(icon: "cpu", text: monitor.cpuPercent)
            }
            if settings.showGPU {
                MenuBarItemLabel(icon: "display", text: monitor.gpuPercent)
            }
            if settings.showMemory {
                MenuBarItemLabel(icon: "memorychip", text: monitor.memoryPercent)
            }
            if settings.showDisk {
                MenuBarItemLabel(icon: "internaldrive", text: monitor.diskMenuText)
            }
            if settings.showNetwork {
                MenuBarItemLabel(icon: "network", text: monitor.networkInText)
            }
            if settings.showPowerPanel, monitor.hasPowerPanel {
                MenuBarItemLabel(icon: monitor.powerMenuSymbol, text: monitor.powerMenuText)
            }
            if settings.showThermal, monitor.hasThermal {
                MenuBarItemLabel(
                    icon: "thermometer.medium",
                    text: monitor.thermalMenuText,
                    textColor: Color(nsColor: monitor.thermalMenuColor),
                    iconPaletteColors: monitor.thermalMenuSymbolPaletteColors?.map(Color.init(nsColor:))
                )
            }
            if settings.showFans, monitor.hasFans {
                MenuBarItemLabel(icon: "wind", text: monitor.fansSummaryText)
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
