import AppKit
import SnapshotTesting
import SwiftUI
import Testing
@testable import StatsMonitor

@Suite("Snapshot Tests")
@MainActor
struct StatsMonitorSnapshotTests {
    @Test("CPU detail panel renders a stable screenshot")
    func cpuDetailPanelScreenshot() {
        let viewModel = makeSnapshotViewModel()
        viewModel.monitor.stats.cpu = CPUUsage(
            user: 31.2,
            system: 18.4,
            idle: 50.4,
            perCore: [78, 64, 22, 18, 44, 39],
            coreFrequencies: [
                CPUCoreFrequency(currentHz: 3_400_000_000, maxHz: 3_500_000_000),
                CPUCoreFrequency(currentHz: 3_300_000_000, maxHz: 3_500_000_000),
                CPUCoreFrequency(currentHz: 2_400_000_000, maxHz: 2_420_000_000),
                CPUCoreFrequency(currentHz: 2_300_000_000, maxHz: 2_420_000_000),
                CPUCoreFrequency(currentHz: 2_100_000_000, maxHz: 2_420_000_000),
                CPUCoreFrequency(currentHz: 2_000_000_000, maxHz: 2_420_000_000),
            ]
        )
        viewModel.monitor.stats.topCPUProcesses = [
            ProcInfo(name: "Xcode", cpuPercent: 48.2, memoryBytes: 1_610_612_736),
            ProcInfo(name: "StatsMonitor", cpuPercent: 12.7, memoryBytes: 92_274_688),
            ProcInfo(name: "WindowServer", cpuPercent: 7.4, memoryBytes: 421_527_552),
        ]

        let view = hostingView(for: snapshotSurface {
            PanelView {
                CPUDetailView(viewModel: viewModel)
            }
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "cpu-detail-panel",
            record: snapshotRecordMode
        )
    }

    @Test("Combined menu bar label renders a stable screenshot")
    func combinedMenuBarLabelScreenshot() {
        let settings = AppSettings()
        settings.showCPU = true
        settings.showGPU = true
        settings.showMemory = true
        settings.showDisk = true
        settings.showNetwork = true
        settings.showBattery = true
        settings.showThermal = true
        settings.showPower = true
        settings.showFans = true

        let monitor = SystemMonitor(settings: settings)
        let viewModel = StatsViewModel(settings: settings, monitor: monitor, startMonitoring: false)
        viewModel.monitor.stats.cpu = CPUUsage(user: 24, system: 18, idle: 58, perCore: [], coreFrequencies: [])
        viewModel.monitor.stats.gpu = GPUUsage(deviceUtilization: 37, renderUtilization: 25, engines: [:], vramUsed: 0)
        viewModel.monitor.stats.memory = MemoryUsage(
            active: 8_589_934_592,
            wired: 2_147_483_648,
            compressed: 1_073_741_824,
            total: 17_179_869_184
        )
        viewModel.monitor.stats.disk = DiskUsage(used: 400_000_000_000, total: 1_000_000_000_000)
        viewModel.monitor.stats.network = NetworkUsage(bytesInPerSec: 1_572_864, bytesOutPerSec: 262_144)
        viewModel.monitor.stats.battery = BatteryUsage(
            percentage: 78,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: 165,
            cycleCount: 132,
            designCapacity: 5000,
            maxCapacity: 4630,
            health: 92.6
        )
        viewModel.monitor.stats.thermal = ThermalUsage(cpuTemperature: 68.4, gpuTemperature: 57.2)
        viewModel.monitor.stats.power = PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        )
        viewModel.monitor.stats.fans = [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ]

        let view = hostingView(for: snapshotSurface {
            CombinedMenuBarLabel(viewModel: viewModel, settings: settings)
                .padding(8)
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "combined-menu-bar-label",
            record: snapshotRecordMode
        )
    }

    @Test("Settings window renders a stable screenshot")
    func settingsWindowScreenshot() {
        let viewModel = makeSnapshotViewModel()
        seedSettingsWindowData(into: viewModel)

        let view = windowFrameView(
            for: SettingsView(settings: viewModel.settings, viewModel: viewModel),
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        )

        assertSnapshot(
            of: view,
            as: .image(size: view.frame.size),
            named: "settings-window",
            record: snapshotRecordMode
        )
    }
}

@MainActor
private func makeSnapshotViewModel() -> StatsViewModel {
    let settings = AppSettings()
    settings.dashboardColumns = AppSettings.dashboardColumnRange.lowerBound
    settings.processCount = 5
    let monitor = SystemMonitor(settings: settings)
    return StatsViewModel(settings: settings, monitor: monitor, startMonitoring: false)
}

private var snapshotRecordMode: SnapshotTestingConfiguration.Record {
    ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
}

@MainActor
private func seedSettingsWindowData(into viewModel: StatsViewModel) {
    viewModel.monitor.stats.cpu = CPUUsage(
        user: 28,
        system: 14,
        idle: 58,
        perCore: [],
        coreFrequencies: []
    )
    viewModel.monitor.stats.gpu = GPUUsage(
        deviceUtilization: 22,
        renderUtilization: 12,
        engines: [:],
        vramUsed: 4_294_967_296
    )
    viewModel.monitor.stats.memory = MemoryUsage(
        active: 9_663_676_416,
        wired: 2_147_483_648,
        compressed: 1_073_741_824,
        total: 18_253_611_008
    )
    viewModel.monitor.stats.disk = DiskUsage(
        used: 512_000_000_000,
        total: 1_000_000_000_000,
        readBPS: 8_388_608,
        writeBPS: 2_097_152
    )
    viewModel.monitor.stats.network = NetworkUsage(
        bytesInPerSec: 2_621_440,
        bytesOutPerSec: 524_288
    )
    viewModel.monitor.stats.battery = BatteryUsage(
        percentage: 78,
        isCharging: false,
        isPluggedIn: false,
        timeRemaining: 165,
        cycleCount: 132,
        designCapacity: 5000,
        maxCapacity: 4630,
        health: 92.6
    )
    viewModel.monitor.stats.thermal = ThermalUsage(
        cpuTemperature: 68.4,
        gpuTemperature: 57.2
    )
    viewModel.monitor.stats.power = PowerUsage(
        cpuMilliWatts: 12_400,
        gpuMilliWatts: 4_200,
        totalMilliWatts: 21_300
    )
    viewModel.monitor.stats.fans = [
        FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
        FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
    ]
    viewModel.monitor.stats.topCPUProcesses = [
        ProcInfo(name: "Xcode", cpuPercent: 42.8, memoryBytes: 1_824_000_000),
        ProcInfo(name: "Simulator", cpuPercent: 16.2, memoryBytes: 734_000_000),
        ProcInfo(name: "StatsMonitor", cpuPercent: 8.3, memoryBytes: 92_000_000),
    ]
    viewModel.monitor.stats.topMemoryProcesses = viewModel.monitor.stats.topCPUProcesses
    viewModel.monitor.stats.topDiskProcesses = [
        ProcInfo(name: "mdworker", cpuPercent: 1.2, memoryBytes: 120_000_000, diskReadBPS: 4_194_304, diskWriteBPS: 524_288),
        ProcInfo(name: "Xcode", cpuPercent: 42.8, memoryBytes: 1_824_000_000, diskReadBPS: 2_097_152, diskWriteBPS: 1_048_576),
    ]
    viewModel.monitor.stats.topNetworkProcesses = [
        ProcInfo(name: "Safari", cpuPercent: 3.1, memoryBytes: 640_000_000, networkInBPS: 1_572_864, networkOutBPS: 196_608),
        ProcInfo(name: "curl", cpuPercent: 0.4, memoryBytes: 18_000_000, networkInBPS: 262_144, networkOutBPS: 131_072),
    ]
}

private func snapshotSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
}

@MainActor
private func hostingView<Content: View>(for rootView: Content) -> NSHostingView<Content> {
    let view = NSHostingView(rootView: rootView)
    let size = view.fittingSize
    view.frame = CGRect(origin: .zero, size: size)
    return view
}

@MainActor
private func windowFrameView<Content: View>(
    for rootView: Content,
    title: String,
    contentSize: CGSize
) -> NSView {
    let hostingController = NSHostingController(rootView: rootView)
    let contentRect = CGRect(origin: .zero, size: contentSize)
    let window = NSWindow(
        contentRect: contentRect,
        styleMask: [.titled, .closable, .miniaturizable, .resizable],
        backing: .buffered,
        defer: false
    )
    window.title = title
    window.backgroundColor = .windowBackgroundColor
    window.isOpaque = true
    window.contentViewController = hostingController
    window.layoutIfNeeded()
    window.displayIfNeeded()

    guard let frameView = window.contentView?.superview else {
        fatalError("NSWindow frame view unavailable for snapshot")
    }

    frameView.frame = CGRect(origin: .zero, size: window.frame.size)
    return frameView
}
