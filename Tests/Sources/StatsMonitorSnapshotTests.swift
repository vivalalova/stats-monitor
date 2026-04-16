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
        let snapshotContext = makeSnapshotContext()
        let monitor = snapshotContext.monitor
        monitor.record(cpu: CPUUsage(
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
        ))
        monitor.topCPUProcesses = [
            ProcInfo(name: "Xcode", cpuPercent: 48.2, memoryBytes: 1_610_612_736),
            ProcInfo(name: "StatsMonitor", cpuPercent: 12.7, memoryBytes: 92_274_688),
            ProcInfo(name: "WindowServer", cpuPercent: 7.4, memoryBytes: 421_527_552),
        ]

        let view = hostingView(for: snapshotSurface {
            PanelView {
                CPUDetailView(monitor: monitor)
            }
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "cpu-detail-panel",
            record: snapshotRecordMode
        )
    }

    @Test("GPU detail panel renders a stable screenshot")
    func gpuDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "gpu-detail-panel") {
            GPUDetailView(monitor: monitor)
        }
    }

    @Test("Memory detail panel renders a stable screenshot")
    func memoryDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "memory-detail-panel") {
            MemoryDetailView(monitor: monitor)
        }
    }

    @Test("Disk detail panel renders a stable screenshot")
    func diskDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "disk-detail-panel") {
            DiskDetailView(monitor: monitor)
        }
    }

    @Test("Network detail panel renders a stable screenshot")
    func networkDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "network-detail-panel") {
            NetworkDetailView(monitor: monitor)
        }
    }

    @Test("Thermal detail panel renders a stable screenshot")
    func thermalDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "thermal-detail-panel") {
            ThermalDetailView(monitor: monitor)
        }
    }

    @Test("Thermal detail panel shows unavailable temperature when only pressure exists")
    func thermalDetailPanelUnavailableTemperatureScreenshot() {
        let settings = makeTestSettings()
        seedSettingsValues(into: settings)
        let monitor = SystemMonitor(settings: settings)
        monitor.record(thermalPressureState: .nominal)

        assertDetailPanelSnapshot(named: "thermal-detail-panel-unavailable-temperature") {
            ThermalDetailView(monitor: monitor)
        }
    }

    @Test("Power detail panel renders a stable screenshot")
    func powerDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "power-detail-panel") {
            PowerDetailView(monitor: monitor)
        }
    }

    @Test("Power detail panel shows unavailable temperature when only pressure exists")
    func powerDetailPanelUnavailableTemperatureScreenshot() {
        let monitor = makePressureOnlyMonitor(includePowerData: true)

        assertDetailPanelSnapshot(named: "power-detail-panel-unavailable-temperature") {
            PowerDetailView(monitor: monitor)
        }
    }

    @Test("Fans detail panel renders a stable screenshot")
    func fansDetailPanelScreenshot() {
        let monitor = makeSeededMonitor()
        assertDetailPanelSnapshot(named: "fans-detail-panel") {
            FansDetailView(monitor: monitor)
        }
    }

    @Test("Quit confirmation alert renders a stable screenshot")
    func quitConfirmationAlertScreenshot() {
        let view = hostingView(for: snapshotSurface {
            QuitConfirmationAlertSnapshotView()
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "quit-confirmation-alert",
            record: snapshotRecordMode
        )
    }

    @Test("General settings tab renders a stable screenshot")
    func generalSettingsWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = windowFrameView(
            for: SettingsView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .general,
                aboutData: .snapshot
            ),
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        )

        assertSnapshot(
            of: view,
            as: .image(size: view.frame.size),
            named: "settings-window-general",
            record: snapshotRecordMode
        )
    }

    @Test("About settings tab renders a stable screenshot")
    func aboutSettingsWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)

        let view = windowFrameView(
            for: SettingsView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .about,
                aboutData: .snapshot
            ),
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        )

        assertSnapshot(
            of: view,
            as: .image(size: view.frame.size),
            named: "settings-window-about",
            record: snapshotRecordMode
        )
    }

    @Test("Combined menu bar label renders a stable screenshot")
    func combinedMenuBarLabelScreenshot() {
        let settings = makeTestSettings()
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
        monitor.record(cpu: CPUUsage(user: 24, system: 18, idle: 58, perCore: [], coreFrequencies: []))
        monitor.record(gpu: GPUUsage(deviceUtilization: 37, renderUtilization: 25, engines: [:], vramUsed: 0))
        monitor.record(memory: MemoryUsage(
            active: 8_589_934_592,
            wired: 2_147_483_648,
            compressed: 1_073_741_824,
            total: 17_179_869_184
        ))
        monitor.record(disk: DiskUsage(
            used: 400_000_000_000,
            total: 1_000_000_000_000,
            readBPS: 8_388_608,
            writeBPS: 2_097_152
        ))
        monitor.record(network: NetworkUsage(bytesInPerSec: 1_572_864, bytesOutPerSec: 262_144))
        monitor.record(battery: BatteryUsage(
            percentage: 78,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: 165,
            cycleCount: 132,
            designCapacity: 5000,
            maxCapacity: 4630,
            health: 92.6
        ))
        monitor.record(thermal: ThermalUsage(cpuTemperature: 68.4, gpuTemperature: 57.2))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        ))
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])

        let view = hostingView(for: snapshotSurface {
            CombinedMenuBarLabel(monitor: monitor, settings: settings)
                .padding(8)
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "combined-menu-bar-label",
            record: snapshotRecordMode
        )
    }

    @Test("Combined menu bar label shows thermal critical state")
    func combinedMenuBarLabelCriticalThermalScreenshot() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = true
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(thermalPressureState: .critical)

        let view = hostingView(for: snapshotSurface {
            CombinedMenuBarLabel(monitor: monitor, settings: settings)
                .padding(8)
        })

        assertSnapshot(
            of: view,
            as: .image(size: view.fittingSize),
            named: "combined-menu-bar-label-thermal-critical",
            record: snapshotRecordMode
        )
    }

    @Test("Settings window renders a stable screenshot")
    func settingsWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = windowFrameView(
            for: SettingsView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                aboutData: .snapshot
            ),
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
private func makeSnapshotContext() -> (settings: AppSettings, monitor: SystemMonitor) {
    let settings = makeTestSettings()
    seedSettingsValues(into: settings)
    let monitor = SystemMonitor(settings: settings)
    return (settings, monitor)
}

@MainActor
private func makeSeededMonitor() -> SystemMonitor {
    let settings = makeTestSettings()
    seedSettingsValues(into: settings)
    let monitor = SystemMonitor(settings: settings)
    seedMonitorSnapshotData(into: monitor)
    return monitor
}

@MainActor
private func makePressureOnlyMonitor(
    pressure: ProcessInfo.ThermalState = .nominal,
    includePowerData: Bool = false
) -> SystemMonitor {
    let settings = makeTestSettings()
    seedSettingsValues(into: settings)
    let monitor = SystemMonitor(settings: settings)
    monitor.record(thermalPressureState: pressure)

    if includePowerData {
        monitor.record(battery: BatteryUsage(
            percentage: 78,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: 165,
            cycleCount: 132,
            designCapacity: 5000,
            maxCapacity: 4630,
            health: 92.6
        ))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        ))
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])
    }

    return monitor
}

private var snapshotRecordMode: SnapshotTestingConfiguration.Record {
    ProcessInfo.processInfo.environment["RECORD_SNAPSHOTS"] == "1" ? .all : .missing
}

@MainActor
private func seedSettingsValues(into settings: AppSettings) {
    settings.pollInterval = 5
    settings.historyCapacity = 300
    settings.processCount = 15
    settings.dashboardColumns = 5
    settings.launchAtLogin = true
    settings.showCPU = true
    settings.showGPU = true
    settings.showMemory = true
    settings.showDisk = true
    settings.showNetwork = true
    settings.showBattery = true
    settings.showThermal = true
    settings.showPower = true
    settings.showFans = true
}

@MainActor
private func seedMonitorSnapshotData(into monitor: SystemMonitor) {
    monitor.record(cpu: CPUUsage(
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
    ))
    monitor.record(gpu: GPUUsage(
        deviceUtilization: 37,
        renderUtilization: 25,
        tilerUtilization: 28,
        engines: ["Compute": 42, "Tiler": 28, "Vertex": 17],
        vramUsed: 4_294_967_296,
        driverMemoryBytes: 268_435_456,
        allocatedMemoryBytes: 6_442_450_944
    ))
    monitor.record(memory: MemoryUsage(
        active: 9_663_676_416,
        wired: 2_147_483_648,
        compressed: 1_073_741_824,
        total: 18_253_611_008,
        swapUsed: 1_367_261_184,
        swapTotal: 2_147_483_648,
        availablePercent: 30
    ))
    monitor.record(disk: DiskUsage(
        used: 512_000_000_000,
        total: 1_000_000_000_000,
        readBPS: 8_388_608,
        writeBPS: 2_097_152
    ))
    monitor.record(network: NetworkUsage(
        bytesInPerSec: 2_621_440,
        bytesOutPerSec: 524_288,
        interfaces: [
            NetworkInterfaceUsage(name: "en0", displayName: "Network (en0)", bytesInPerSec: 2_097_152, bytesOutPerSec: 393_216),
            NetworkInterfaceUsage(name: "utun4", displayName: "VPN (utun4)", bytesInPerSec: 524_288, bytesOutPerSec: 131_072),
        ]
    ))
    monitor.record(battery: BatteryUsage(
        percentage: 78,
        isCharging: false,
        isPluggedIn: false,
        timeRemaining: 165,
        cycleCount: 132,
        designCapacity: 5000,
        maxCapacity: 4630,
        health: 92.6
    ))
    monitor.record(thermal: ThermalUsage(
        cpuTemperature: 68.4,
        gpuTemperature: 57.2
    ))
    monitor.record(thermalPressureState: .nominal)
    monitor.record(power: PowerUsage(
        cpuMilliWatts: 12_400,
        gpuMilliWatts: 4_200,
        totalMilliWatts: 21_300,
        externalInputMilliWatts: 18_000,
        batteryMilliWatts: -3_300
    ))
    monitor.record(fans: [
        FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
        FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
    ])
    monitor.topCPUProcesses = [
        ProcInfo(name: "Xcode", cpuPercent: 48.2, memoryBytes: 1_824_000_000),
        ProcInfo(name: "WindowServer", cpuPercent: 16.2, memoryBytes: 734_000_000),
        ProcInfo(name: "StatsMonitor", cpuPercent: 8.3, memoryBytes: 92_000_000),
    ]
    monitor.topMemoryProcesses = monitor.topCPUProcesses
    monitor.topGPUProcesses = [
        GPUProcessInfo(pid: 601, name: "WindowServer", utilizationPercent: 23.5, commandQueueCount: 4),
        GPUProcessInfo(pid: 1235, name: "Safari", utilizationPercent: 9.8, commandQueueCount: 2),
        GPUProcessInfo(pid: 1232, name: "Fork", utilizationPercent: 4.1, commandQueueCount: 1),
    ]
    monitor.topDiskProcesses = [
        ProcInfo(name: "mdworker", cpuPercent: 1.2, memoryBytes: 120_000_000, diskReadBPS: 4_194_304, diskWriteBPS: 524_288),
        ProcInfo(name: "Xcode", cpuPercent: 42.8, memoryBytes: 1_824_000_000, diskReadBPS: 2_097_152, diskWriteBPS: 1_048_576),
    ]
    monitor.topNetworkProcesses = [
        ProcInfo(name: "Safari", cpuPercent: 3.1, memoryBytes: 640_000_000, networkInBPS: 1_572_864, networkOutBPS: 196_608),
        ProcInfo(name: "curl", cpuPercent: 0.4, memoryBytes: 18_000_000, networkInBPS: 262_144, networkOutBPS: 131_072),
    ]
    monitor.topPowerProcesses = [
        ProcInfo(name: "WindowServer", cpuPercent: 16.2, memoryBytes: 734_000_000, powerImpact: 45.1),
        ProcInfo(name: "Xcode", cpuPercent: 48.2, memoryBytes: 1_824_000_000, powerImpact: 14.1),
        ProcInfo(name: "StatsMonitor", cpuPercent: 8.3, memoryBytes: 92_000_000, powerImpact: 12.7),
    ]
}

private extension AboutView.SnapshotData {
    static let snapshot = AboutView.SnapshotData(
        appName: "StatsMonitor",
        appVersion: "1.2.0",
        appBuild: "120",
        copyright: "© 2026 Lova Shih",
        macModel: "MacBookPro18,3",
        chipName: "Apple M1 Pro",
        osVersion: "macOS 15.5 (24F74)",
        totalRAM: "32 GB",
        uptime: "2d 5h 18m"
    )
}

private func snapshotSurface<Content: View>(@ViewBuilder content: () -> Content) -> some View {
    content()
        .padding(12)
        .background(Color(nsColor: .windowBackgroundColor))
}

@MainActor
private func assertDetailPanelSnapshot<Content: View>(
    named name: String,
    @ViewBuilder content: () -> Content
) {
    let view = hostingView(for: snapshotSurface {
        PanelView {
            content()
        }
    })

    assertSnapshot(
        of: view,
        as: .image(size: view.fittingSize),
        named: name,
        record: snapshotRecordMode
    )
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
    hostingView(for: WindowSnapshotFrame(title: title, contentSize: contentSize) {
        rootView
    })
}

private struct QuitConfirmationAlertSnapshotView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.yellow)

                VStack(alignment: .leading, spacing: 6) {
                    Text(QuitConfirmationCopy.title)
                        .font(.system(size: 15, weight: .semibold))
                    Text(QuitConfirmationCopy.message)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                Spacer()
                alertButton(QuitConfirmationCopy.cancel, emphasized: false)
                alertButton(QuitConfirmationCopy.confirm, emphasized: true)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func alertButton(_ title: String, emphasized: Bool) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(emphasized ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(emphasized ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
            )
    }
}

private struct WindowSnapshotFrame<Content: View>: View {
    let title: String
    let contentSize: CGSize
    let content: Content

    init(
        title: String,
        contentSize: CGSize,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.contentSize = contentSize
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            content
                .frame(width: contentSize.width, height: contentSize.height)
                .background(Color(nsColor: .windowBackgroundColor))
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: WindowSnapshotLayout.cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: WindowSnapshotLayout.cornerRadius, style: .continuous)
                .stroke(Color(nsColor: .separatorColor), lineWidth: WindowSnapshotLayout.outerBorderWidth)
        )
        .frame(
            width: contentSize.width,
            height: contentSize.height + WindowSnapshotLayout.titleBarHeight
        )
    }

    private var titleBar: some View {
        ZStack {
            RoundedRectangle(cornerRadius: WindowSnapshotLayout.cornerRadius, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))

            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: WindowSnapshotLayout.trafficLightSpacing) {
                trafficLight(.systemRed)
                trafficLight(.systemYellow)
                trafficLight(.systemGreen)
                Spacer()
            }
            .padding(.horizontal, WindowSnapshotLayout.horizontalPadding)
        }
        .frame(height: WindowSnapshotLayout.titleBarHeight)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private func trafficLight(_ color: NSColor) -> some View {
        Circle()
            .fill(Color(nsColor: color))
            .frame(
                width: WindowSnapshotLayout.trafficLightSize,
                height: WindowSnapshotLayout.trafficLightSize
            )
    }
}

private enum WindowSnapshotLayout {
    static let titleBarHeight: CGFloat = 52
    static let cornerRadius: CGFloat = 10
    static let outerBorderWidth: CGFloat = 1
    static let trafficLightSize: CGFloat = 12
    static let trafficLightSpacing: CGFloat = 8
    static let horizontalPadding: CGFloat = 14
}
