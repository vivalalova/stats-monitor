import AppKit
import SwiftUI

enum AppSceneID {
    static let settingsWindow = "settings-window"
}

enum SettingsWindowLayout {
    static let defaultWidth: CGFloat = 820
    static let defaultHeight: CGFloat = 520
    static let sidebarWidth: CGFloat = 130
}

// MARK: - View

struct MainWindowView: View {
    enum Tab: CaseIterable, Hashable {
        case cpuCores
        case gpuEngines
        case dashboard
        case general
        case about

        static let chartTabs: [Tab] = [.cpuCores, .gpuEngines]
        static let textTabs: [Tab] = [.dashboard, .general, .about]

        var localizedTitle: LocalizedStringKey {
            switch self {
            case .cpuCores:   "CPU"
            case .gpuEngines: "GPU"
            case .dashboard:  "Dashboard"
            case .general:    "General"
            case .about:      "About"
            }
        }

        var icon: String {
            switch self {
            case .cpuCores:   "cpu"
            case .gpuEngines: "memorychip"
            case .dashboard:  "square.grid.2x2"
            case .general:    "gearshape"
            case .about:      "info.circle"
            }
        }
    }

    let settings: AppSettings
    let monitor: SystemMonitor
    private let aboutData: AboutView.SnapshotData
    @State private var selection: Tab = .dashboard

    init(
        settings: AppSettings,
        monitor: SystemMonitor,
        selection: Tab = .dashboard,
        aboutData: AboutView.SnapshotData = .live
    ) {
        self.settings = settings
        self.monitor = monitor
        self.aboutData = aboutData
        _selection = State(initialValue: selection)
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                ForEach(Tab.chartTabs, id: \.self) { tab in
                    Button {
                        selection = tab
                    } label: {
                        sidebarRow(for: tab)
                    }
                    .buttonStyle(.plain)
                    .selectionDisabled()
                }
                Divider()
                    .listRowSeparator(.hidden)
                ForEach(Tab.textTabs, id: \.self) { tab in
                    sidebarRow(for: tab)
                        .tag(tab)
                }
            }
            .navigationSplitViewColumnWidth(
                min: SettingsWindowLayout.sidebarWidth,
                ideal: SettingsWindowLayout.sidebarWidth,
                max: SettingsWindowLayout.sidebarWidth
            )
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    SidebarToggleButton()
                }
            }
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch selection {
            case .cpuCores:   CPUCoreChartsView(monitor: monitor)
            case .gpuEngines: GPUEnginesView(monitor: monitor)
            case .dashboard:  DashboardView(settings: settings, monitor: monitor)
            case .general:    GeneralSettingsView(settings: settings)
            case .about:      AboutView(data: aboutData)
            }
        }
        .frame(
            minWidth: SettingsWindowLayout.defaultWidth,
            minHeight: SettingsWindowLayout.defaultHeight
        )
    }

    @ViewBuilder
    private func sidebarRow(for tab: Tab) -> some View {
        switch tab {
        case .cpuCores:
            sidebarChartRow(
                tab: .cpuCores,
                title: "CPU",
                value: monitor.cpuPercent,
                statusColor: progressColor(monitor.cpuFraction),
                lines: [(history: monitor.paddedCPUHistory, color: .blue)]
            )
        case .gpuEngines:
            sidebarChartRow(
                tab: .gpuEngines,
                title: "GPU",
                value: monitor.gpuPercent,
                statusColor: progressColor(monitor.gpuFraction),
                lines: [(history: monitor.paddedGPUHistory, color: .purple)]
            )
        default:
            Label(tab.localizedTitle, systemImage: tab.icon)
        }
    }

    private func sidebarChartRow(
        tab: Tab,
        title: String,
        value: String,
        statusColor: Color,
        lines: [(history: [Double], color: Color)]
    ) -> some View {
        let maxValue = max(lines.flatMap(\.history).max() ?? 0, 1)
        let isSelected = selection == tab
        return MetricChartCard(
            title: title,
            value: value,
            statusColor: statusColor,
            lines: lines,
            maxValue: maxValue,
            height: 50
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : .clear,
                    lineWidth: 2
                )
        }
        .listRowInsets(EdgeInsets(top: 4, leading: 4, bottom: 4, trailing: 4))
    }
}

private struct SidebarToggleButton: View {
    var body: some View {
        Button {
            NSApp.sendAction(#selector(NSSplitViewController.toggleSidebar(_:)), to: nil, from: nil)
        } label: {
            Image(systemName: "sidebar.left")
        }
        .help("Toggle Sidebar")
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings

    private var powerPanelBinding: Binding<Bool> {
        Binding(
            get: { settings.showPowerPanel },
            set: { settings.setPowerPanelVisible($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                settingsSection("System") {
                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                }

                settingsSection("Update Frequency") {
                    Picker("Poll Interval", selection: $settings.pollInterval) {
                        ForEach(AppSettings.pollIntervalOptions, id: \.self) { interval in
                            Text("\(Int(interval)) sec").tag(interval)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                settingsSection("History") {
                    Picker("Retention Period", selection: $settings.historyCapacity) {
                        ForEach(AppSettings.historyCapacityOptions, id: \.value) { option in
                            Text(LocalizedStringKey(option.label)).tag(option.value)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                settingsSection("Process List") {
                    HStack {
                        Text("Display Count")
                        Spacer()
                        Picker("", selection: $settings.processCount) {
                            ForEach([5, 10, 15, 20], id: \.self) { n in
                                Text("\(n) items").tag(n)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }
                }

                settingsSection("Menu Bar Items") {
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("CPU", isOn: $settings.showCPU)
                        Toggle("GPU", isOn: $settings.showGPU)
                        Toggle("Memory", isOn: $settings.showMemory)
                        Toggle("Disk", isOn: $settings.showDisk)
                        Toggle("Network", isOn: $settings.showNetwork)
                        Toggle("Power", isOn: powerPanelBinding)
                        Toggle("Thermal", isOn: $settings.showThermal)
                        Toggle("Fans", isOn: $settings.showFans)
                    }
                    Text("Keep at least one item to avoid hiding the app completely.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func settingsSection(_ title: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
            Divider()
        }
    }
}

// MARK: - Preview

#Preview {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    MainWindowView(settings: settings, monitor: monitor)
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
}
