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

struct SettingsView: View {
    enum Tab: String, CaseIterable, Hashable {
        case dashboard = "Dashboard"
        case general   = "General"
        case about     = "About"

        var localizedTitle: LocalizedStringKey {
            switch self {
            case .dashboard: "Dashboard"
            case .general:   "General"
            case .about:     "About"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: "square.grid.2x2"
            case .general:   "gearshape"
            case .about:     "info.circle"
            }
        }
    }

    let settings: AppSettings
    let viewModel: StatsViewModel
    @State private var selection: Tab = .dashboard

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selection) { tab in
                Label(tab.localizedTitle, systemImage: tab.icon)
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
            case .dashboard: DashboardView(viewModel: viewModel)
            case .general:   GeneralSettingsView(settings: settings)
            case .about:     AboutView()
            }
        }
        .frame(
            minWidth: SettingsWindowLayout.defaultWidth,
            minHeight: SettingsWindowLayout.defaultHeight
        )
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
    SettingsView(settings: AppSettings(), viewModel: StatsViewModel())
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
}
