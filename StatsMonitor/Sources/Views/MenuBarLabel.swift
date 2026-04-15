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
    var viewModel: StatsViewModel
    var settings: AppSettings

    var body: some View {
        HStack(spacing: 0) {
            if settings.showCPU {
                MenuBarItemLabel(icon: "cpu", text: viewModel.cpuPercent)
            }
            if settings.showGPU {
                MenuBarItemLabel(icon: "display", text: viewModel.gpuPercent)
            }
            if settings.showMemory {
                MenuBarItemLabel(icon: "memorychip", text: viewModel.memoryPercent)
            }
            if settings.showDisk {
                MenuBarItemLabel(icon: "internaldrive", text: viewModel.diskPercent)
            }
            if settings.showNetwork {
                MenuBarItemLabel(icon: "network", text: viewModel.networkIn)
            }
        }
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
    }
    .padding()
}
