import AppKit
import SwiftUI

// MARK: - Settings window opener

@MainActor private var settingsWindow: NSWindow?

@MainActor func openSettings(settings: AppSettings, viewModel: StatsViewModel) {
    if settingsWindow == nil {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "StatsMonitor"
        let toolbar = NSToolbar(identifier: "SettingsToolbar")
        toolbar.showsBaselineSeparator = false
        window.toolbar = toolbar
        window.toolbarStyle = .unifiedCompact
        window.contentView = NSHostingView(rootView: SettingsView(settings: settings, viewModel: viewModel))
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        settingsWindow = window
    }
    settingsWindow?.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
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
            .navigationSplitViewColumnWidth(min: 130, ideal: 130, max: 130)
        } detail: {
            switch selection {
            case .dashboard: DashboardView(viewModel: viewModel)
            case .general:   GeneralSettingsView(settings: settings)
            case .about:     AboutView()
            }
        }
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

#Preview(traits: .sizeThatFitsLayout) {
    SettingsView(settings: AppSettings(), viewModel: StatsViewModel())
        .frame(width: 820, height: 520)
}
