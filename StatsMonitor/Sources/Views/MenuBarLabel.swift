import AppKit
import SwiftUI

// MARK: - Right-click quit menu

/// Traverses the view hierarchy to find NSStatusBarButton and installs a
/// right-click context menu with Quit. Left-click behavior is unaffected.
private struct MenuBarRightClickInstaller: NSViewRepresentable {
    func makeNSView(context: Context) -> RightClickInstallerView {
        RightClickInstallerView()
    }
    func updateNSView(_ nsView: RightClickInstallerView, context: Context) {}
}

private final class RightClickInstallerView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return }
        var ancestor: NSView? = superview
        while let view = ancestor {
            if let button = view as? NSStatusBarButton {
                let menu = NSMenu()
                let item = NSMenuItem(
                    title: "Quit StatsMonitor",
                    action: #selector(NSApplication.terminate(_:)),
                    keyEquivalent: "q"
                )
                menu.addItem(item)
                button.menu = menu
                return
            }
            ancestor = view.superview
        }
    }
}

// MARK: - Labels

struct CPUMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
            Text(viewModel.cpuPercent)
                .monospacedDigit()
        }
        .overlay(MenuBarRightClickInstaller().frame(width: 0, height: 0))
    }
}

struct GPUMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "display")
            Text(viewModel.gpuPercent)
                .monospacedDigit()
        }
        .overlay(MenuBarRightClickInstaller().frame(width: 0, height: 0))
    }
}

struct MemoryMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "memorychip")
            Text(viewModel.memoryPercent)
                .monospacedDigit()
        }
        .overlay(MenuBarRightClickInstaller().frame(width: 0, height: 0))
    }
}

struct DiskMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "internaldrive")
            Text(viewModel.diskPercent)
                .monospacedDigit()
        }
        .overlay(MenuBarRightClickInstaller().frame(width: 0, height: 0))
    }
}

struct NetworkMenuBarLabel: View {
    var viewModel: StatsViewModel

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "network")
            Text("↓\(viewModel.networkIn)")
                .monospacedDigit()
        }
        .overlay(MenuBarRightClickInstaller().frame(width: 0, height: 0))
    }
}
