import AppKit
import SnapshotTesting
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

        let view = detailPopoverSnapshotView(
            panel: .cpu,
            settings: snapshotContext.settings,
            monitor: monitor
        )

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.fittingSize),
            named: "cpu-detail-panel",
            record: snapshotRecordMode
        )
    }

    @Test("GPU detail panel renders a stable screenshot")
    func gpuDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "gpu-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .gpu,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Memory detail panel renders a stable screenshot")
    func memoryDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "memory-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .memory,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Disk detail panel renders a stable screenshot")
    func diskDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "disk-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .disk,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Network detail panel renders a stable screenshot")
    func networkDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "network-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .network,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Thermal detail panel renders a stable screenshot")
    func thermalDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "thermal-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .thermal,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Thermal detail panel shows unavailable temperature when only pressure exists")
    func thermalDetailPanelUnavailableTemperatureScreenshot() {
        let settings = makeTestSettings()
        seedSettingsValues(into: settings)
        let monitor = SystemMonitor(settings: settings)
        monitor.record(thermalPressureState: .nominal)

        assertDetailPanelSnapshot(
            named: "thermal-detail-panel-unavailable-temperature",
            content: DetailPanelSnapshotContent(
                panel: .thermal,
                settings: settings,
                monitor: monitor
            )
        )
    }

    @Test("Power detail panel renders a stable screenshot")
    func powerDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "power-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .power,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Power detail panel shows unavailable temperature when only pressure exists")
    func powerDetailPanelUnavailableTemperatureScreenshot() {
        let snapshotContext = makePressureOnlySnapshotContext(includePowerData: true)
        assertDetailPanelSnapshot(
            named: "power-detail-panel-unavailable-temperature",
            content: DetailPanelSnapshotContent(
                panel: .power,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Fans detail panel renders a stable screenshot")
    func fansDetailPanelScreenshot() {
        let snapshotContext = makeSeededSnapshotContext()
        assertDetailPanelSnapshot(
            named: "fans-detail-panel",
            content: DetailPanelSnapshotContent(
                panel: .fans,
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor
            )
        )
    }

    @Test("Quit confirmation alert renders a stable screenshot")
    func quitConfirmationAlertScreenshot() {
        let alert = QuitConfirmationAlertFactory.makeAlert(locale: Locale(identifier: "en"))
        alert.icon = NSImage(size: NSSize(width: 64, height: 64), flipped: false) { rect in
            NSColor(srgbRed: 0.0, green: 0.478, blue: 1.0, alpha: 1.0).setFill()
            NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12).fill()
            return true
        }
        let view = alertSnapshotView(alert)

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "quit-confirmation-alert",
            record: snapshotRecordMode
        )
    }

    @Test("General main window tab renders a stable screenshot")
    func generalMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .general,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-general",
            record: snapshotRecordMode
        )
    }

    @Test("General tab shows warning hint only when every menu bar item is unchecked")
    func generalMainWindowHintVisibleScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)
        snapshotContext.settings.showCPU = false
        snapshotContext.settings.showGPU = false
        snapshotContext.settings.showMemory = false
        snapshotContext.settings.showDisk = false
        snapshotContext.settings.showNetwork = false
        snapshotContext.settings.showBattery = false
        snapshotContext.settings.showPower = false
        snapshotContext.settings.showThermal = false
        snapshotContext.settings.showFans = false

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .general,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-general-hint-visible",
            record: snapshotRecordMode
        )
    }

    @Test("General tab hides unsupported hardware toggles on desktop-class Mac")
    func generalMainWindowDesktopSubsetScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .general,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-general-desktop-subset",
            record: snapshotRecordMode
        )
    }

    @Test("CPU cores main window tab renders a stable screenshot")
    func cpuCoresMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .cpuCores,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-cpu-cores",
            record: snapshotRecordMode
        )
    }

    @Test("GPU engines main window tab renders a stable screenshot")
    func gpuEnginesMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .gpuEngines,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-gpu-engines",
            record: snapshotRecordMode
        )
    }

    @Test("Memory main window tab renders a stable screenshot")
    func memoryMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .memory,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-memory",
            record: snapshotRecordMode
        )
    }

    @Test("Disk main window tab renders a stable screenshot")
    func diskMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .disk,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-disk",
            record: snapshotRecordMode
        )
    }

    @Test("Network main window tab renders a stable screenshot")
    func networkMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .network,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-network",
            record: snapshotRecordMode
        )
    }

    @Test("Power main window tab renders a stable screenshot")
    func powerMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .power,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-power",
            record: snapshotRecordMode
        )
    }

    @Test("Power main window tab shows the battery charge line while charging")
    func powerMainWindowChargingScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)
        snapshotContext.monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            mediaEngineMilliWatts: 1_450,
            totalMilliWatts: 21_300,
            externalInputMilliWatts: 18_000,
            batteryMilliWatts: 8_000
        ))

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .power,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-power-charging",
            record: snapshotRecordMode
        )
    }

    @Test("About main window tab renders a stable screenshot")
    func aboutMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .about,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-about",
            record: snapshotRecordMode
        )
    }

    @Test("Diagnostics main window tab renders a stable screenshot")
    func diagnosticsMainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                selection: .diagnostics,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-diagnostics",
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

        let view = menuBarSnapshotView(monitor: monitor, settings: settings)

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
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

        let view = menuBarSnapshotView(monitor: monitor, settings: settings)

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "combined-menu-bar-label-thermal-critical",
            record: snapshotRecordMode
        )
    }

    @Test("Combined menu bar label shows low power mode state")
    func combinedMenuBarLabelLowPowerScreenshot() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = false
        settings.showPower = true
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(isLowPowerModeEnabled: true)
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        ))

        let view = menuBarSnapshotView(monitor: monitor, settings: settings)

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "combined-menu-bar-label-low-power",
            record: snapshotRecordMode
        )
    }

    @Test("Combined menu bar label shows low battery state")
    func combinedMenuBarLabelLowBatteryScreenshot() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = false
        settings.showPower = true
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(battery: BatteryUsage(
            percentage: 15, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        ))

        let view = menuBarSnapshotView(monitor: monitor, settings: settings)

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "combined-menu-bar-label-low-battery",
            record: snapshotRecordMode
        )
    }

    @Test("Main window renders a stable screenshot")
    func mainWindowScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window",
            record: snapshotRecordMode
        )
    }

    @Test("Dashboard power card scales the battery charge line correctly while charging")
    func mainWindowDashboardChargingScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        seedMonitorSnapshotData(into: snapshotContext.monitor)
        snapshotContext.monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            mediaEngineMilliWatts: 1_450,
            totalMilliWatts: 21_300,
            externalInputMilliWatts: 18_000,
            batteryMilliWatts: 8_000
        ))

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-dashboard-charging",
            record: snapshotRecordMode
        )
    }

    @Test("Main window shows GPU-only processes in Top Processes table")
    func mainWindowGPUHeavyScreenshot() {
        let snapshotContext = makeSnapshotContext()
        seedSettingsValues(into: snapshotContext.settings)
        snapshotContext.settings.processCount = 5
        seedGPUHeavyMonitorSnapshotData(into: snapshotContext.monitor)

        let view = appWindowSnapshotView(
            title: "Settings",
            contentSize: CGSize(
                width: SettingsWindowLayout.defaultWidth,
                height: SettingsWindowLayout.defaultHeight
            )
        ) {
            MainWindowView(
                settings: snapshotContext.settings,
                monitor: snapshotContext.monitor,
                aboutData: .snapshot
            )
        }

        assertSnapshot(
            of: view,
            as: toleratedImageSnapshot(size: view.frame.size),
            named: "main-window-gpu-heavy",
            record: snapshotRecordMode
        )
    }

    @Test("Snapshot tests do not auto-record missing references by default")
    func snapshotRecordModeDoesNotRecordMissingByDefault() {
        #expect(resolvedSnapshotRecordMode(environment: [:]) == .never)
    }

    @Test("Snapshot tests allow explicit reference re-recording")
    func snapshotRecordModeAllowsExplicitRerecording() {
        #expect(resolvedSnapshotRecordMode(environment: ["RECORD_SNAPSHOTS": "1"]) == .all)
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
private func makeSeededSnapshotContext() -> (settings: AppSettings, monitor: SystemMonitor) {
    let settings = makeTestSettings()
    seedSettingsValues(into: settings)
    let monitor = SystemMonitor(settings: settings)
    seedMonitorSnapshotData(into: monitor)
    return (settings, monitor)
}

@MainActor
private func makePressureOnlySnapshotContext(
    pressure: ProcessInfo.ThermalState = .nominal,
    includePowerData: Bool = false
) -> (settings: AppSettings, monitor: SystemMonitor) {
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

    return (settings, monitor)
}

private var snapshotRecordMode: SnapshotTestingConfiguration.Record {
    resolvedSnapshotRecordMode(environment: ProcessInfo.processInfo.environment)
}

/// Single source of truth for the image comparison tolerance used by every snapshot assertion
/// below. Exact pixel match flakes across runs/machines due to GPU/anti-aliasing rendering jitter
/// (~0.5% pixel diff, max channel delta 86 observed) even with identical fixture data.
private func toleratedImageSnapshot(size: CGSize) -> Snapshotting<NSView, NSImage> {
    .image(precision: 0.99, perceptualPrecision: 0.98, size: size)
}

private func resolvedSnapshotRecordMode(
    environment: [String: String]
) -> SnapshotTestingConfiguration.Record {
    environment["RECORD_SNAPSHOTS"] == "1" ? .all : .never
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
        allocatedMemoryBytes: 6_442_450_944,
        frequency: CPUCoreFrequency(currentHz: 860_000_000, maxHz: 1_398_000_000)
    ))
    monitor.record(memory: MemoryUsage(
        active: 9_663_676_416,
        wired: 2_147_483_648,
        compressed: 1_073_741_824,
        total: 18_253_611_008,
        swapUsed: 1_367_261_184,
        swapTotal: 2_147_483_648,
        availablePercent: 30,
        pageInsPerSec: 524_288,
        pageOutsPerSec: 131_072
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
        ],
        wifi: WiFiLinkInfo(
            rssiDBm: -58,
            noiseDBm: -92,
            linkRateMbps: 1_200,
            channelNumber: 149,
            band: "5 GHz",
            hardwareAddress: "a4:83:e7:00:11:22"
        ),
        tcpConnectionCount: 84,
        udpConnectionCount: 12
    ))
    monitor.record(battery: BatteryUsage(
        percentage: 78,
        isCharging: false,
        isPluggedIn: false,
        timeRemaining: 165,
        cycleCount: 132,
        designCapacity: 5000,
        maxCapacity: 4630,
        health: 92.6,
        voltageMilliVolts: 11_840,
        amperageMilliAmps: -1_240,
        temperatureCelsius: 31.4
    ))
    monitor.record(thermal: ThermalUsage(
        cpuTemperature: 68.4,
        gpuTemperature: 57.2
    ))
    monitor.record(thermalPressureState: .nominal)
    monitor.record(power: PowerUsage(
        cpuMilliWatts: 12_400,
        gpuMilliWatts: 4_200,
        mediaEngineMilliWatts: 1_450,
        totalMilliWatts: 21_300,
        externalInputMilliWatts: 18_000,
        batteryMilliWatts: -3_300
    ))
    monitor.record(fans: [
        FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
        FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
    ])
    monitor.record(isLowPowerModeEnabled: false)
    monitor.record(displayInfo: DisplayInfo(
        widthPixels: 3456,
        heightPixels: 2234,
        refreshRateHz: 120
    ))
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

@MainActor
private func seedGPUHeavyMonitorSnapshotData(into monitor: SystemMonitor) {
    monitor.record(cpu: CPUUsage(
        user: 18,
        system: 9,
        idle: 73,
        perCore: [30, 22, 10, 8],
        coreFrequencies: [
            CPUCoreFrequency(currentHz: 3_000_000_000, maxHz: 3_500_000_000),
            CPUCoreFrequency(currentHz: 2_800_000_000, maxHz: 3_500_000_000),
            CPUCoreFrequency(currentHz: 2_000_000_000, maxHz: 2_420_000_000),
            CPUCoreFrequency(currentHz: 1_900_000_000, maxHz: 2_420_000_000),
        ]
    ))
    monitor.record(gpu: GPUUsage(
        deviceUtilization: 62,
        renderUtilization: 55,
        tilerUtilization: 48,
        engines: ["Compute": 62],
        vramUsed: 3_200_000_000,
        driverMemoryBytes: 120_000_000,
        allocatedMemoryBytes: 5_500_000_000
    ))
    monitor.record(memory: MemoryUsage(
        active: 6_000_000_000,
        wired: 2_000_000_000,
        compressed: 500_000_000,
        total: 16_000_000_000,
        swapUsed: 0,
        swapTotal: 0,
        availablePercent: 47
    ))
    monitor.record(disk: DiskUsage(used: 400_000_000_000, total: 1_000_000_000_000, readBPS: 0, writeBPS: 0))
    monitor.record(network: NetworkUsage(bytesInPerSec: 0, bytesOutPerSec: 0, interfaces: []))
    monitor.topCPUProcesses = [
        ProcInfo(name: "Xcode", cpuPercent: 42.1, memoryBytes: 1_600_000_000),
        ProcInfo(name: "clang", cpuPercent: 18.4, memoryBytes: 320_000_000),
        ProcInfo(name: "StatsMonitor", cpuPercent: 6.7, memoryBytes: 90_000_000),
    ]
    monitor.topMemoryProcesses = monitor.topCPUProcesses
    monitor.topGPUProcesses = [
        GPUProcessInfo(pid: 601, name: "WindowServer", utilizationPercent: 34.8, commandQueueCount: 4),
        GPUProcessInfo(pid: 2050, name: "com.apple.WebKit", utilizationPercent: 21.2, commandQueueCount: 3),
        GPUProcessInfo(pid: 1240, name: "Finder", utilizationPercent: 6.5, commandQueueCount: 1),
        GPUProcessInfo(pid: 1268, name: "com.apple.dock.e", utilizationPercent: 3.1, commandQueueCount: 1),
    ]
    monitor.topDiskProcesses = []
    monitor.topNetworkProcesses = []
    monitor.topPowerProcesses = []
}

private extension AboutView.SnapshotData {
    static let snapshot = AboutView.SnapshotData(
        appName: "StatsMonitor",
        appVersion: "1.2.0",
        appBuild: "120",
        copyright: "© 2026 Lova Shih",
        macModel: "MacBookPro18,3",
        chipName: "Apple M1 Pro",
        osVersion: "macOS 26.0",
        totalRAM: "32 GB",
        uptime: "2d 5h 18m",
        loadAverage: "1.24, 1.02, 0.87",
        processCount: "412",
        display: "3456 × 2234 @ 120 Hz"
    )
}

private struct DetailPanelSnapshotContent {
    let panel: PanelID
    let settings: AppSettings
    let monitor: SystemMonitor
}

@MainActor
private func assertDetailPanelSnapshot(
    named name: String,
    content: DetailPanelSnapshotContent
) {
    let view = detailPopoverSnapshotView(
        panel: content.panel,
        settings: content.settings,
        monitor: content.monitor
    )

    assertSnapshot(
        of: view,
        as: toleratedImageSnapshot(size: view.fittingSize),
        named: name,
        record: snapshotRecordMode
    )
}
