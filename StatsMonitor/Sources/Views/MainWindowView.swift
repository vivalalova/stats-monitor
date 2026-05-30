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
        case memory
        case disk
        case network
        case power
        case dashboard
        case general
        case about

        static let chartTabs: [Tab] = [.cpuCores, .gpuEngines, .memory, .disk, .network, .power]
        static let textTabs: [Tab] = [.dashboard, .general, .about]

        var showsGridSizeSlider: Bool {
            Self.chartTabs.contains(self) || self == .dashboard
        }

        var localizedTitle: LocalizedStringKey {
            switch self {
            case .cpuCores:   "CPU"
            case .gpuEngines: "GPU"
            case .memory:     "Memory"
            case .disk:       "Disk"
            case .network:    "Network"
            case .power:      "Power"
            case .dashboard:  "Dashboard"
            case .general:    "General"
            case .about:      "About"
            }
        }

        var icon: String {
            switch self {
            case .cpuCores:   "cpu"
            case .gpuEngines: "memorychip"
            case .memory:     "memorychip.fill"
            case .disk:       "internaldrive"
            case .network:    "network"
            case .power:      "bolt.fill"
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
    @State private var isSidebarVisible: Bool = true

    init(
        settings: AppSettings,
        monitor: SystemMonitor,
        selection: Tab = .dashboard,
        sidebarVisible: Bool = true,
        aboutData: AboutView.SnapshotData = .live
    ) {
        self.settings = settings
        self.monitor = monitor
        self.aboutData = aboutData
        _selection = State(initialValue: selection)
        _isSidebarVisible = State(initialValue: sidebarVisible)
    }

    var body: some View {
        HStack(spacing: 0) {
            if isSidebarVisible {
                sidebar
                    .padding(8)
                    .frame(width: SettingsWindowLayout.sidebarWidth)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .glassEffect(.regular, in: Rectangle())
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // 視窗尺寸永久鎖定為 820×520（目前最小尺寸）。刻意設計，不接受調整：
        // layout、chart 空間、sidebar 行高、grid 欄寬都以此尺寸為基準校準。
        // 日後任何「讓使用者改大/改小」的需求，先回頭重新審視整套版面計算。
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SidebarToggleButton(isVisible: $isSidebarVisible)
            }
            if selection.showsGridSizeSlider {
                ToolbarItem(placement: .primaryAction) {
                    DashboardColumnsSlider(settings: settings)
                }
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
        GlassEffectContainer(spacing: 4) {
            VStack(spacing: 4) {
                ForEach(Tab.chartTabs, id: \.self) { tab in
                    sidebarRow(for: tab)
                        .contentShape(Rectangle())
                        .onTapGesture { selection = tab }
                }
                Divider()
                    .padding(.vertical, 4)
                ForEach(Tab.textTabs, id: \.self) { tab in
                    sidebarTextRow(for: tab)
                        .onTapGesture { selection = tab }
                }
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .cpuCores:   CPUCoreChartsView(settings: settings, monitor: monitor)
        case .gpuEngines: GPUEnginesView(settings: settings, monitor: monitor)
        case .memory:     MemoryChartsView(settings: settings, monitor: monitor)
        case .disk:       DiskChartsView(settings: settings, monitor: monitor)
        case .network:    NetworkChartsView(settings: settings, monitor: monitor)
        case .power:      PowerChartsView(settings: settings, monitor: monitor)
        case .dashboard:  DashboardView(settings: settings, monitor: monitor)
        case .general:    GeneralSettingsView(settings: settings, monitor: monitor)
        case .about:      AboutView(data: aboutData)
        }
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
                lines: [ChartSeries(history: monitor.paddedCPUHistory, color: .blue)]
            )
        case .gpuEngines:
            sidebarChartRow(
                tab: .gpuEngines,
                title: "GPU",
                value: monitor.gpuPercent,
                statusColor: progressColor(monitor.gpuFraction),
                lines: [ChartSeries(history: monitor.paddedGPUHistory, color: .purple)]
            )
        case .memory:
            sidebarChartRow(
                tab: .memory,
                title: "Memory",
                value: monitor.memoryPercent,
                statusColor: progressColor(monitor.memoryFraction),
                lines: [ChartSeries(history: monitor.paddedMemoryHistory, color: .cyan)]
            )
        case .disk:
            sidebarChartRow(
                tab: .disk,
                title: "Disk",
                value: monitor.diskActivityText,
                statusColor: .blue,
                lines: [
                    ChartSeries(history: monitor.paddedDiskReadHistory, color: .teal),
                    ChartSeries(history: monitor.paddedDiskWriteHistory, color: .orange),
                ]
            )
        case .network:
            sidebarChartRow(
                tab: .network,
                title: "Network",
                value: monitor.networkTotalText,
                statusColor: .blue,
                lines: [
                    ChartSeries(history: monitor.paddedNetworkInHistory, color: .green),
                    ChartSeries(history: monitor.paddedNetworkOutHistory, color: .red),
                ]
            )
        case .power:
            sidebarChartRow(
                tab: .power,
                title: "Power",
                value: monitor.powerText,
                statusColor: powerStatusColor(monitor.power?.totalWatts ?? 0),
                lines: [ChartSeries(history: monitor.paddedPowerHistory, color: .red)]
            )
        default:
            sidebarTextRow(for: tab)
        }
    }

    private func sidebarChartRow(
        tab: Tab,
        title: String,
        value: String,
        statusColor: Color,
        lines: [ChartSeries]
    ) -> some View {
        let maxValue = max(lines.flatMap(\.history).max() ?? 0, 1)
        let isSelected = selection == tab
        return SidebarMetricRow(
            title: title,
            value: value,
            statusColor: statusColor,
            lines: lines,
            maxValue: maxValue
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.accentColor : .clear,
                    lineWidth: 2
                )
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private func sidebarTextRow(for tab: Tab) -> some View {
        let isSelected = selection == tab
        let row = Label(tab.localizedTitle, systemImage: tab.icon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())

        if isSelected {
            row
                .foregroundStyle(Color.accentColor)
                .glassEffect(
                    .regular.tint(.accentColor.opacity(0.25)).interactive(),
                    in: RoundedRectangle(cornerRadius: 6)
                )
        } else {
            row
        }
    }
}

private struct SidebarToggleButton: View {
    @Binding var isVisible: Bool

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                isVisible.toggle()
            }
        } label: {
            Image(systemName: "sidebar.left")
        }
        .help("Toggle Sidebar")
    }
}

// MARK: - General Settings

private struct GeneralSettingsView: View {
    @Bindable var settings: AppSettings
    let monitor: SystemMonitor

    private var powerPanelBinding: Binding<Bool> {
        Binding(
            get: { settings.showPowerPanel },
            set: { settings.setPowerPanelVisible($0) }
        )
    }

    private var anyMenuBarItemChecked: Bool {
        AppSettings.anyMenuBarItemChecked(
            settings: settings,
            hasPower: monitor.hasPower,
            hasThermal: monitor.hasThermal,
            hasFans: monitor.hasFans
        )
    }

    @ViewBuilder
    private var menuBarToggles: some View {
        Toggle("CPU",     isOn: $settings.showCPU)
        Toggle("GPU",     isOn: $settings.showGPU)
        Toggle("Memory",  isOn: $settings.showMemory)
        Toggle("Disk",    isOn: $settings.showDisk)
        Toggle("Network", isOn: $settings.showNetwork)
        if monitor.hasPower   { Toggle("Power",   isOn: powerPanelBinding) }
        if monitor.hasThermal { Toggle("Thermal", isOn: $settings.showThermal) }
        if monitor.hasFans    { Toggle("Fans",    isOn: $settings.showFans) }
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
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { menuBarToggles }
                        VStack(alignment: .leading, spacing: 8) { menuBarToggles }
                    }
                    if !anyMenuBarItemChecked {
                        Text("Keep at least one item to avoid hiding the app completely.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
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

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    MainWindowView(settings: settings, monitor: monitor)
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
}
