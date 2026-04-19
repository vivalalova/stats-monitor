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
                ZStack(alignment: .top) {
                    Rectangle().fill(.ultraThickMaterial)
                    sidebar.padding(8)
                }
                .frame(width: SettingsWindowLayout.sidebarWidth)
                .frame(maxHeight: .infinity)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(
            minWidth: SettingsWindowLayout.defaultWidth,
            minHeight: SettingsWindowLayout.defaultHeight
        )
        .toolbar {
            ToolbarItem(placement: .navigation) {
                SidebarToggleButton(isVisible: $isSidebarVisible)
            }
        }
    }

    @ViewBuilder
    private var sidebar: some View {
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

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .cpuCores:   CPUCoreChartsView(settings: settings, monitor: monitor)
        case .gpuEngines: GPUEnginesView(settings: settings, monitor: monitor)
        case .dashboard:  DashboardView(settings: settings, monitor: monitor)
        case .general:    GeneralSettingsView(settings: settings)
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
            sidebarTextRow(for: tab)
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
        .contentShape(Rectangle())
    }

    private func sidebarTextRow(for tab: Tab) -> some View {
        let isSelected = selection == tab
        return Label(tab.localizedTitle, systemImage: tab.icon)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
            )
            .contentShape(Rectangle())
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

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    MainWindowView(settings: settings, monitor: monitor)
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
}
