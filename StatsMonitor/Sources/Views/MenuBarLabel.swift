import SwiftUI

struct MenuBarItemLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
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
                MenuBarItemLabel(icon: "internaldrive", text: monitor.diskPercent)
            }
            if settings.showNetwork {
                MenuBarItemLabel(icon: "network", text: monitor.networkInText)
            }
            if settings.showBattery, monitor.hasBattery {
                MenuBarItemLabel(icon: "battery.100", text: monitor.batteryPercent)
            }
            if settings.showThermal, monitor.hasThermal {
                MenuBarItemLabel(icon: "thermometer.medium", text: monitor.cpuTempText)
            }
            if settings.showPower, monitor.hasPower {
                MenuBarItemLabel(icon: "bolt.fill", text: monitor.powerText)
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

#Preview(traits: .sizeThatFitsLayout) {
    HStack(spacing: 0) {
        MenuBarItemLabel(icon: "cpu",          text: "42%")
        MenuBarItemLabel(icon: "display",      text: "18%")
        MenuBarItemLabel(icon: "memorychip",   text: "71%")
        MenuBarItemLabel(icon: "internaldrive",text: "55%")
        MenuBarItemLabel(icon: "network",      text: "↓1.2 MB/s")
        MenuBarItemLabel(icon: "battery.100",  text: "78%")
        MenuBarItemLabel(icon: "thermometer.medium", text: "68.4°C")
        MenuBarItemLabel(icon: "bolt.fill",    text: "21.3 W")
        MenuBarItemLabel(icon: "wind",         text: "2470 RPM")
    }
    .padding()
}
