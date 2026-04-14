import AppKit
import SwiftUI

// MARK: - Settings window opener

@MainActor private var settingsWindow: NSWindow?

@MainActor func openSettings() {
    if settingsWindow == nil {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 420),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "StatsMonitor Settings"
        window.contentView = NSHostingView(rootView: SettingsView())
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
        case general = "General"
        var icon: String { "gearshape" }
    }

    @State private var selection: Tab = .general

    var body: some View {
        NavigationSplitView {
            List(Tab.allCases, id: \.self, selection: $selection) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
            }
            .navigationSplitViewColumnWidth(min: 150, ideal: 180)
        } detail: {
            GeneralSettingsView()
        }
    }
}

private struct GeneralSettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("General")
                .font(.title2)
                .fontWeight(.semibold)
            Divider()
            Spacer()
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    SettingsView()
        .frame(width: 640, height: 420)
}
