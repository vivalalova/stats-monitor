import Testing
import SwiftUI
@testable import StatsMonitor

@Suite("StatsMonitor Tests")
struct StatsMonitorTests {

    // MARK: - CPU

    @Test("CPU usage sums user and system")
    func cpuUsedSumsComponents() {
        let cpu = CPUUsage(user: 30, system: 20, idle: 50, perCore: [], coreFrequencies: [])
        #expect(cpu.used == 50)
    }

    @Test("CPU perCore carries through")
    func cpuPerCorePreserved() {
        let cores = [10.0, 20.0, 30.0]
        let cpu = CPUUsage(user: 20, system: 10, idle: 70, perCore: cores, coreFrequencies: [])
        #expect(cpu.perCore == cores)
    }

    @Test("CPUCoreFrequency displayText shows max when current unavailable")
    func coreFreqDisplayMaxOnly() {
        let freq = CPUCoreFrequency(currentHz: 0, maxHz: 3_228_000_000)
        #expect(freq.displayText == "3.2G")
    }

    @Test("CPUCoreFrequency displayText shows current and max")
    func coreFreqDisplayBoth() {
        let freq = CPUCoreFrequency(currentHz: 2_100_000_000, maxHz: 3_228_000_000)
        #expect(freq.displayText.contains("2.1G"))
        #expect(freq.displayText.contains("3.2G"))
    }

    // MARK: - Memory

    @Test("Memory fraction is zero when total is zero")
    func memoryFractionZeroWhenNoTotal() {
        let mem = MemoryUsage(active: 0, wired: 0, compressed: 0, total: 0)
        #expect(mem.usedFraction == 0)
    }

    @Test("Memory fraction stays within 0...1")
    func memoryFractionBounded() {
        let mem = MemoryUsage(active: 2_000_000_000, wired: 1_000_000_000, compressed: 1_000_000_000, total: 8_000_000_000)
        #expect(mem.usedFraction >= 0)
        #expect(mem.usedFraction <= 1)
    }

    @Test("Memory used sums active, wired, compressed")
    func memoryUsedSumsComponents() {
        let mem = MemoryUsage(active: 1_000, wired: 2_000, compressed: 500, total: 8_000_000_000)
        #expect(mem.used == 3_500)
    }

    // MARK: - Disk

    @Test("Disk fraction is zero when total is zero")
    func diskFractionZeroWhenNoTotal() {
        let disk = DiskUsage(used: 0, total: 0)
        #expect(disk.usedFraction == 0)
    }

    // MARK: - GPU

    @Test("GPU used equals deviceUtilization")
    func gpuUsedEqualsDeviceUtilization() {
        let gpu = GPUUsage(deviceUtilization: 42, renderUtilization: 30, engines: [:], vramUsed: 0)
        #expect(gpu.used == 42)
    }

    @Test("GPU zero has no utilization")
    func gpuZeroHasNoUtilization() {
        #expect(GPUUsage.zero.used == 0)
        #expect(GPUUsage.zero.renderUtilization == 0)
        #expect(GPUUsage.zero.engines.isEmpty)
    }

    @Test("GPU engines carried through")
    func gpuEnginesPreserved() {
        let engines = ["Vertex": 55.0, "Fragment": 30.0]
        let gpu = GPUUsage(deviceUtilization: 55, renderUtilization: 30, engines: engines, vramUsed: 0)
        #expect(gpu.engines["Vertex"] == 55.0)
    }

    // MARK: - ProcessInfo

    @Test("ProcessInfo stores name and metrics")
    func processInfoFields() {
        let p = ProcInfo(name: "Xcode", cpuPercent: 12.5, memoryBytes: 500_000_000, powerImpact: 8.4)
        #expect(p.name == "Xcode")
        #expect(p.cpuPercent == 12.5)
        #expect(p.memoryBytes == 500_000_000)
        #expect(p.powerImpact == 8.4)
    }

    @Test("ProcessMonitor parses top POWER output into per-process energy impact")
    func processMonitorParsesTopPowerOutput() {
        let output = """
        Processes: 653 total, 5 running, 648 sleeping, 3730 threads
        PID    COMMAND          POWER
        99935  iconservicesd    0.0
        99934  iconservicesagen 0.0

        Processes: 653 total, 5 running, 648 sleeping, 3730 threads
        PID    COMMAND          POWER
        601    WindowServer     45.1
        72166  iTerm2           14.1
        83863  Codex Helper     13.8
        """

        let powerByPID = ProcessMonitor.parseTopPowerOutput(output)

        #expect(powerByPID[601] == 45.1)
        #expect(powerByPID[72166] == 14.1)
        #expect(powerByPID[83863] == 13.8)
    }

    // MARK: - BatteryUsage

    @Test("BatteryUsage stores all fields")
    func batteryUsageFields() {
        let b = BatteryUsage(percentage: 80, isCharging: true, isPluggedIn: true,
                             timeRemaining: nil, cycleCount: 120,
                             designCapacity: 5000, maxCapacity: 4800, health: 96)
        #expect(b.percentage == 80)
        #expect(b.isCharging == true)
        #expect(b.cycleCount == 120)
        #expect(b.health == 96)
    }

    @Test("BatteryUsage struct preserves raw percentage without clamping")
    func batteryPercentagePassThrough() {
        // IOKit can return CurrentCapacity > MaxCapacity during calibration
        let b = BatteryUsage(percentage: 103, isCharging: false, isPluggedIn: true,
                             timeRemaining: nil, cycleCount: 0,
                             designCapacity: 5000, maxCapacity: 5000, health: 103)
        // struct itself doesn't clamp — BatteryMonitor.sample() clamps before constructing
        #expect(b.percentage == 103)  // pass-through: struct preserves whatever percentage is given
    }

    // MARK: - FanUsage

    @Test("FanUsage fraction is zero when RPM range is zero")
    func fanFractionZeroRange() {
        let fan = FanUsage(id: 0, currentRPM: 1000, minRPM: 1000, maxRPM: 1000, name: "Fan 0")
        #expect(fan.fraction == 0)
    }

    @Test("FanUsage fraction is within 0...1 for normal RPM")
    func fanFractionNormal() {
        let fan = FanUsage(id: 0, currentRPM: 3000, minRPM: 1000, maxRPM: 5000, name: "Fan 0")
        // (3000-1000)/(5000-1000) = 0.5
        #expect(abs(fan.fraction - 0.5) < 0.001)
    }

    @Test("FanUsage fraction clamps to 0 when below minRPM")
    func fanFractionClampedAtZero() {
        let fan = FanUsage(id: 0, currentRPM: 500, minRPM: 1000, maxRPM: 5000, name: "Fan 0")
        #expect(fan.fraction == 0)
    }

    @Test("FanUsage fraction clamps to 1 when above maxRPM")
    func fanFractionClampedAtOne() {
        let fan = FanUsage(id: 0, currentRPM: 7000, minRPM: 1000, maxRPM: 5000, name: "Fan 0")
        #expect(fan.fraction == 1)
    }

    @Test("FanUsage diskTotalBPS-analogue: fraction at boundaries")
    func fanFractionAtBoundaries() {
        let atMin = FanUsage(id: 0, currentRPM: 1000, minRPM: 1000, maxRPM: 5000, name: "Fan 0")
        let atMax = FanUsage(id: 0, currentRPM: 5000, minRPM: 1000, maxRPM: 5000, name: "Fan 0")
        #expect(atMin.fraction == 0)
        #expect(atMax.fraction == 1)
    }

    // MARK: - ThermalUsage

    @Test("ThermalUsage stores CPU temperature")
    func thermalUsageCPUTemp() {
        let t = ThermalUsage(cpuTemperature: 72.5, gpuTemperature: nil)
        #expect(t.cpuTemperature == 72.5)
        #expect(t.gpuTemperature == nil)
    }

    @Test("ThermalUsage stores GPU temperature when present")
    func thermalUsageGPUTemp() {
        let t = ThermalUsage(cpuTemperature: 65.0, gpuTemperature: 58.3)
        #expect(t.gpuTemperature == 58.3)
    }
}

@Suite("BatteryMonitor")
struct BatteryMonitorTests {

    @Test("prefers nominal capacity when reported max capacity is a percentage scale")
    func prefersNominalCapacityForMilliampHours() {
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 80,
            "MaxCapacity": 100,
            "NominalChargeCapacity": 4161,
            "AppleRawMaxCapacity": 4034,
            "DesignCapacity": 4563,
            "IsCharging": false,
            "ExternalConnected": true,
            "CycleCount": 127,
            "TimeRemaining": 65535,
        ])

        #expect(usage != nil)
        #expect(usage?.percentage == 80)
        #expect(usage?.maxCapacity == 4161)
        #expect(usage?.designCapacity == 4563)
        #expect(usage?.cycleCount == 127)
        #expect(usage?.timeRemaining == nil)
        #expect((usage?.health ?? 0) > 90)
    }

    @Test("falls back to reported mAh capacity when nominal capacity is unavailable")
    func fallsBackToReportedCapacity() {
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 2400,
            "MaxCapacity": 3000,
            "DesignCapacity": 3200,
            "IsCharging": true,
            "ExternalConnected": true,
            "CycleCount": 20,
            "TimeRemaining": 45,
        ])

        #expect(usage != nil)
        #expect(usage?.percentage == 80)
        #expect(usage?.maxCapacity == 3000)
        #expect(usage?.designCapacity == 3200)
        #expect(usage?.health == 93.75)
        #expect(usage?.timeRemaining == 45)
    }
}

@Suite("MemoryMonitor")
struct MemoryMonitorTests {

    @Test("maps available memory percentage to user-facing pressure levels")
    func mapsAvailablePercentToPressureLevels() {
        #expect(MemoryMonitor.pressureLevel(forAvailablePercent: 50) == .normal)
        #expect(MemoryMonitor.pressureLevel(forAvailablePercent: 30) == .warning)
        #expect(MemoryMonitor.pressureLevel(forAvailablePercent: 15) == .urgent)
        #expect(MemoryMonitor.pressureLevel(forAvailablePercent: 5) == .critical)
        #expect(MemoryMonitor.pressureLevel(forAvailablePercent: nil) == .unknown)
    }
}

@Suite("ThermalMonitor")
struct ThermalMonitorTests {

    @Test("rejects denormal sensor values that round to zero")
    func rejectsNearZeroSensorNoise() {
        #expect(ThermalMonitor.sanitizeTemperature(0.00000000014764814) == nil)
        #expect(ThermalMonitor.sanitizeTemperature(-0.003) == nil)
    }

    @Test("keeps plausible thermal readings")
    func keepsPlausibleTemperatures() {
        #expect(ThermalMonitor.sanitizeTemperature(34.5) == 34.5)
        #expect(ThermalMonitor.sanitizeTemperature(92.0) == 92.0)
    }

    @Test("formats thermal pressure states for display")
    func formatsThermalPressureStates() {
        #expect(SystemMonitor.thermalPressureText(for: .nominal) == "Nominal")
        #expect(SystemMonitor.thermalPressureText(for: .fair) == "Fair")
        #expect(SystemMonitor.thermalPressureText(for: .serious) == "Serious")
        #expect(SystemMonitor.thermalPressureText(for: .critical) == "Critical")
    }
}

@Suite("PowerMonitor")
struct PowerMonitorTests {

    @Test("prefers system load from battery telemetry when available")
    func prefersSystemLoadTelemetry() {
        let milliWatts = PowerMonitor.telemetryTotalMilliWatts(from: [
            "SystemLoad": 24_085,
            "SystemPowerIn": 12_420,
            "BatteryPower": UInt64.max - 11_664
        ])

        #expect(milliWatts == 24_085)
    }

    @Test("reads external input from battery telemetry")
    func readsExternalInputTelemetry() {
        let milliWatts = PowerMonitor.telemetryExternalInputMilliWatts(from: [
            "SystemLoad": 24_085,
            "SystemPowerIn": 12_420,
            "BatteryPower": UInt64.max - 11_664
        ])

        #expect(milliWatts == 12_420)
    }

    @Test("reads signed battery power from battery telemetry")
    func readsSignedBatteryPowerTelemetry() {
        let dischargingMilliWatts = PowerMonitor.telemetryBatteryMilliWatts(from: [
            "BatteryPower": UInt64.max - 11_664
        ])
        let chargingMilliWatts = PowerMonitor.telemetryBatteryMilliWatts(from: [
            "BatteryPower": 2_450
        ])

        #expect(dischargingMilliWatts == -11_665)
        #expect(chargingMilliWatts == 2_450)
    }

    @Test("derives total load from adapter plus battery discharge when system load is missing")
    func derivesTotalLoadFromSources() {
        let milliWatts = PowerMonitor.telemetryTotalMilliWatts(from: [
            "SystemPowerIn": 12_420,
            "BatteryPower": UInt64.max - 11_664
        ])

        #expect(milliWatts == 24_085)
    }
}

@Suite("GPUMonitor")
struct GPUMonitorTests {

    @Test("parses tiler utilization and gpu memory breakdown from performance statistics")
    func parsesPerformanceStatistics() {
        let usage = GPUMonitor.parseUsage(from: [
            "Device Utilization %": 20,
            "Renderer Utilization %": 19,
            "Tiler Utilization %": 17,
            "In use system memory": 685_047_808,
            "In use system memory (driver)": 52_428_800,
            "Alloc system memory": 10_747_871_232,
        ])

        #expect(usage.deviceUtilization == 20)
        #expect(usage.renderUtilization == 19)
        #expect(usage.tilerUtilization == 17)
        #expect(usage.vramUsed == 685_047_808)
        #expect(usage.driverMemoryBytes == 52_428_800)
        #expect(usage.allocatedMemoryBytes == 10_747_871_232)
    }

    @Test("computes top gpu apps from accumulated gpu time deltas")
    func computesTopGPUAppsFromDeltas() {
        let currentSnapshots = [
            GPUMonitor.AppUsageSnapshot(
                pid: 601,
                name: "WindowServer",
                accumulatedGPUTime: 1_500_000_000,
                commandQueueCount: 4
            ),
            GPUMonitor.AppUsageSnapshot(
                pid: 83863,
                name: "Codex Helper",
                accumulatedGPUTime: 1_250_000_000,
                commandQueueCount: 2
            ),
            GPUMonitor.AppUsageSnapshot(
                pid: 72166,
                name: "iTerm2",
                accumulatedGPUTime: 1_020_000_000,
                commandQueueCount: 1
            ),
        ]

        let result = GPUMonitor.computeTopApps(
            currentSnapshots: currentSnapshots,
            previousTotalsByPID: [
                601: 1_000_000_000,
                83863: 1_000_000_000,
                72166: 1_000_000_000,
            ],
            intervalSeconds: 1,
            processCount: 2
        )

        #expect(result.apps.count == 2)
        #expect(result.apps[0].name == "WindowServer")
        #expect(result.apps[0].utilizationPercent == 50)
        #expect(result.apps[0].commandQueueCount == 4)
        #expect(result.apps[1].name == "Codex Helper")
        #expect(result.apps[1].utilizationPercent == 25)
        #expect(result.updatedTotalsByPID[601] == 1_500_000_000)
        #expect(result.updatedTotalsByPID[83863] == 1_250_000_000)
        #expect(result.updatedTotalsByPID[72166] == 1_020_000_000)
    }
}

@Suite("NetworkMonitor")
struct NetworkMonitorTests {

    @Test("computes active interface throughput deltas and sorts by total traffic")
    func computesInterfaceUsage() {
        let usage = NetworkMonitor.computeInterfaceUsage(
            currentCounters: [
                "en0": (bytesIn: 3_145_728, bytesOut: 1_048_576),
                "utun4": (bytesIn: 786_432, bytesOut: 524_288),
            ],
            previousCounters: [
                "en0": (bytesIn: 2_097_152, bytesOut: 524_288),
                "utun4": (bytesIn: 262_144, bytesOut: 262_144),
            ],
            elapsed: 1
        )

        #expect(usage.count == 2)
        #expect(usage[0].name == "en0")
        #expect(usage[0].displayName == "Network (en0)")
        #expect(usage[0].bytesInPerSec == 1_048_576)
        #expect(usage[0].bytesOutPerSec == 524_288)
        #expect(usage[1].displayName == "VPN (utun4)")
    }
}

// MARK: - SystemMonitor Presentation Tests

@Suite("SystemMonitor Presentation")
@MainActor
struct SystemMonitorPresentationTests {

    private func makeMonitor() -> SystemMonitor {
        SystemMonitor(settings: makeTestSettings())
    }

    // MARK: - Lifecycle

    @Test("init and stop do not crash")
    func lifecycle() {
        let monitor = makeMonitor()
        monitor.stop()
    }

    @Test("start and stop do not crash")
    func startStop() {
        let monitor = makeMonitor()
        monitor.stop()
        monitor.start()
        monitor.stop()
    }

    @Test("start returns self for chaining")
    func startReturnsSelf() {
        let monitor = makeMonitor()
        defer { monitor.stop() }

        #expect(monitor.start() === monitor)
    }

    // MARK: - Formatted properties with known raw sample input

    @Test("cpuPercent shows sum of user and system with one decimal")
    func cpuPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(cpu: CPUUsage(
            user: 30,
            system: 20,
            idle: 50,
            perCore: [],
            coreFrequencies: [
                CPUCoreFrequency(currentHz: 3_400_000_000, maxHz: 3_500_000_000),
                CPUCoreFrequency(currentHz: 2_600_000_000, maxHz: 3_200_000_000),
            ]
        ))
        #expect(monitor.cpuPercent == "50.0%")
        #expect(monitor.cpuUserPercent == "30.0%")
        #expect(monitor.cpuSystemPercent == "20.0%")
        #expect(monitor.cpuAverageFrequencyText == "3.0G")
        #expect(monitor.cpuPeakFrequencyText == "3.4G")
    }

    @Test("memoryPercent reflects usedFraction with one decimal")
    func memoryPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        // active(2GB) + wired(1GB) + compressed(1GB) = 4GB used; total = 8GB → 50%
        monitor.record(memory: MemoryUsage(
            active: 2_147_483_648, wired: 1_073_741_824,
            compressed: 1_073_741_824, total: 8_589_934_592
        ))
        #expect(monitor.memoryPercent == "50.0%")
        #expect(monitor.memoryFreeText == "4.0 GB")
    }

    @Test("diskPercent reflects usedFraction with one decimal")
    func diskPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(disk: DiskUsage(
            used: 250_000_000_000,
            total: 500_000_000_000,
            readBPS: 1_048_576,
            writeBPS: 524_288
        ))
        #expect(monitor.diskPercent == "50.0%")
        #expect(monitor.diskActivityText == "1.5 MB/s")
    }

    @Test("networkTotalText sums inbound and outbound throughput")
    func networkTotalTextKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(network: NetworkUsage(bytesInPerSec: 1_048_576, bytesOutPerSec: 524_288))
        #expect(monitor.networkTotalText == "1.5 MB/s")
    }

    @Test("batteryPercent returns N/A when battery is nil")
    func batteryPercentNoBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        #expect(monitor.batteryPercent == "N/A")
    }

    @Test("batteryPercent returns formatted value when battery present")
    func batteryPercentWithBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 80, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))
        #expect(monitor.batteryPercent == "80%")
    }

    @Test("powerMenuText shows only system power when battery and power are both available")
    func powerMenuTextShowsOnlySystemPower() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 78, isCharging: false, isPluggedIn: false,
            timeRemaining: 165, cycleCount: 132,
            designCapacity: 5000, maxCapacity: 4630, health: 92.6
        ))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 21_300
        ))

        #expect(monitor.powerMenuText == "21W")
    }

    @Test("powerMenuText is unavailable when power telemetry is unavailable")
    func powerMenuTextWithoutPowerTelemetry() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 61, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 88,
            designCapacity: 5000, maxCapacity: 4700, health: 94
        ))

        #expect(monitor.powerMenuText == "N/A")
    }

    @Test("power detail exposes external input, discharge, and balance")
    func powerDetailFormattingShowsDeficit() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 2_300,
            gpuMilliWatts: 200,
            totalMilliWatts: 11_500,
            externalInputMilliWatts: 10_466,
            batteryMilliWatts: -636
        ))

        #expect(monitor.powerText == "11.5 W")
        #expect(monitor.externalInputPowerText == "10.5 W")
        #expect(monitor.batteryDischargePowerText == "0.6 W")
        #expect(monitor.batteryChargePowerText.isEmpty)
        #expect(monitor.powerBalanceText == "-1.0 W")
    }

    @Test("power detail exposes battery charging power when surplus is available")
    func powerDetailFormattingShowsChargePower() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 2_300,
            gpuMilliWatts: 200,
            totalMilliWatts: 11_500,
            externalInputMilliWatts: 15_000,
            batteryMilliWatts: 2_450
        ))

        #expect(monitor.batteryChargePowerText == "2.5 W")
        #expect(monitor.batteryDischargePowerText.isEmpty)
        #expect(monitor.powerBalanceText == "+3.5 W")
    }

    @Test("gpu detail exposes tiler and gpu memory breakdown")
    func gpuDetailFormattingShowsMoreContext() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(gpu: GPUUsage(
            deviceUtilization: 20,
            renderUtilization: 19,
            tilerUtilization: 17,
            engines: ["Device": 20, "Renderer": 19, "Tiler": 17],
            vramUsed: 685_047_808,
            driverMemoryBytes: 52_428_800,
            allocatedMemoryBytes: 10_747_871_232
        ))
        monitor.topGPUProcesses = [
            GPUProcessInfo(pid: 601, name: "WindowServer", utilizationPercent: 23.5, commandQueueCount: 4)
        ]

        #expect(monitor.gpuTilerPercent == "17.0%")
        #expect(monitor.gpuVramUsedText == "653 MB")
        #expect(monitor.gpuDriverMemoryText == "50 MB")
        #expect(monitor.gpuAllocatedMemoryText == "10.0 GB")
        #expect(monitor.formatProcessGPU(monitor.topGPUProcesses[0]) == "23.5%")
    }

    @Test("memory detail exposes pressure and swap summary")
    func memoryDetailFormattingShowsPressureAndSwap() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(memory: MemoryUsage(
            active: 9_663_676_416,
            wired: 2_147_483_648,
            compressed: 1_073_741_824,
            total: 18_253_611_008,
            swapUsed: 1_367_261_184,
            swapTotal: 2_147_483_648,
            availablePercent: 30
        ))

        #expect(monitor.memoryPressureText == "Warning")
        #expect(monitor.memoryAvailablePercentText == "30%")
        #expect(monitor.memorySwapSummaryText == "1.3 GB / 2.0 GB")
    }

    @Test("network detail exposes active interfaces")
    func networkDetailFormattingShowsInterfaces() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(network: NetworkUsage(
            bytesInPerSec: 1_048_576,
            bytesOutPerSec: 524_288,
            interfaces: [
                NetworkInterfaceUsage(
                    name: "en0",
                    displayName: "Network (en0)",
                    bytesInPerSec: 786_432,
                    bytesOutPerSec: 262_144
                )
            ]
        ))

        #expect(monitor.activeNetworkInterfaces.count == 1)
        #expect(monitor.formatNetworkInterface(monitor.activeNetworkInterfaces[0]) == "↓768 KB/s ↑256 KB/s")
    }

    // MARK: - batteryStatus branching

    @Test("batteryStatus is Charging when isCharging")
    func batteryStatusCharging() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 60, isCharging: true, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        ))
        #expect(monitor.batteryStatusText == "Charging")
    }

    @Test("batteryStatus is Plugged In when plugged in but not charging")
    func batteryStatusPluggedIn() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 100, isCharging: false, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        ))
        #expect(monitor.batteryStatusText == "Plugged In")
    }

    @Test("batteryStatus shows hours and minutes when on battery with estimate ≥ 60m")
    func batteryStatusTimeRemainingHoursAndMinutes() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: 90, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        ))
        #expect(monitor.batteryStatusText == "1h 30m")
    }

    @Test("batteryStatus shows minutes only when less than 1 hour remaining")
    func batteryStatusTimeRemainingMinutesOnly() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 10, isCharging: false, isPluggedIn: false,
            timeRemaining: 45, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        ))
        #expect(monitor.batteryStatusText == "45m")
    }

    @Test("batteryStatus is On Battery when no charging and no time estimate")
    func batteryStatusOnBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        ))
        #expect(monitor.batteryStatusText == "On Battery")
    }

    // MARK: - anePowerStr branching

    @Test("anePowerStr shows mW when below 1000 mW")
    func anePowerMW() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(gpu: GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 500
        ))
        #expect(monitor.anePowerText == "500 mW")
    }

    @Test("anePowerStr shows W when 1000 mW or more")
    func anePowerW() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(gpu: GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 2500
        ))
        #expect(monitor.anePowerText == "2.5 W")
    }

    @Test("fanCountText uses pluralized count")
    func fanCountText() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2400, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2500, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])
        #expect(monitor.fanCountText == "2 fans")
    }

    @Test("thermal display falls back to pressure when no temperature is available")
    func thermalDisplayFallsBackToPressure() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(thermalPressureState: .nominal)

        #expect(monitor.hasThermal)
        #expect(!monitor.hasTemperatureReadings)
        #expect(monitor.thermalTemperatureStatusText == "Unavailable on this Mac")
        #expect(monitor.thermalMenuText == "OK")
        #expect(monitor.thermalMenuColor == .labelColor)
        #expect(monitor.thermalMenuSymbolPaletteColors == nil)
    }

    @Test("thermal menu styling turns red and multicolor at critical pressure")
    func thermalMenuStylingAtCriticalPressure() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(thermalPressureState: .critical)

        #expect(monitor.thermalMenuText == "CR")
        #expect(monitor.thermalMenuColor == NSColor.systemRed)
        #expect(monitor.thermalMenuSymbolPaletteColors?.count == 2)
        #expect(monitor.thermalMenuSymbolPaletteColors?[0] == NSColor.systemRed)
        #expect(monitor.thermalMenuSymbolPaletteColors?[1] == NSColor.systemOrange)
    }

    // MARK: - formatProcess helpers (known input → known output)

    @Test("formatProcessCPU formats one decimal percent")
    func formatProcessCPU() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        #expect(monitor.formatProcessCPU(50.0)  == "50.0%")
        #expect(monitor.formatProcessCPU(0.0)   == "0.0%")
        #expect(monitor.formatProcessCPU(100.0) == "100.0%")
    }

    @Test("formatProcessMemory formats bytes to human-readable")
    func formatProcessMemory() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        #expect(monitor.formatProcessMemory(1_073_741_824) == "1.0 GB")
        #expect(monitor.formatProcessMemory(1_048_576)     == "1 MB")
        #expect(monitor.formatProcessMemory(0)             == "0 B")
    }

    @Test("formatProcessDisk formats throughput")
    func formatProcessDisk() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        #expect(monitor.formatProcessDisk(1_048_576) == "1.0 MB/s")
        #expect(monitor.formatProcessDisk(0)         == "0 KB/s")
    }

    @Test("formatProcessPower formats one decimal energy impact score")
    func formatProcessPower() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        let process = ProcInfo(name: "Xcode", cpuPercent: 12.5, memoryBytes: 500_000_000, powerImpact: 14.16)
        #expect(monitor.formatProcessPower(process) == "14.2 impact")
    }
}

@Suite("SystemMonitor")
@MainActor
struct SystemMonitorTests {

    @Test("record appends raw samples and latest display reads from history")
    func recordAppendsRawSamplesAndDisplaysLatest() {
        let monitor = SystemMonitor(settings: makeTestSettings())

        monitor.record(cpu: CPUUsage(user: 8.5, system: 4.0, idle: 87.5, perCore: [], coreFrequencies: []))
        monitor.record(cpu: CPUUsage(user: 10.0, system: 8.0, idle: 82.0, perCore: [], coreFrequencies: []))
        monitor.record(battery: BatteryUsage(
            percentage: 77,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: nil,
            cycleCount: 10,
            designCapacity: 5000,
            maxCapacity: 4800,
            health: 96
        ))
        monitor.record(thermal: ThermalUsage(cpuTemperature: 64.2, gpuTemperature: nil))

        #expect(monitor.cpuSamples.values.map(\.used) == [12.5, 18.0])
        #expect(monitor.batterySamples.values.map(\.percentage) == [77.0])
        #expect(monitor.thermalSamples.values.map(\.cpuTemperature) == [64.2])
        #expect(monitor.cpuPercent == "18.0%")
        #expect(monitor.batteryPercent == "77%")
        #expect(monitor.cpuTempText == "64.2°C")
    }

    @Test("history-derived values stay at defaults until a history sample is recorded")
    func historyDerivedValuesStayAtDefaultsWithoutHistorySample() {
        let monitor = SystemMonitor(settings: makeTestSettings())

        #expect(monitor.cpuPercent == "0.0%")
        #expect(monitor.networkInText == "0 KB/s")
        #expect(monitor.networkOutText == "0 KB/s")
        #expect(monitor.cpuSamples.values.isEmpty)
        #expect(monitor.networkSamples.values.isEmpty)
    }

    @Test("padded history zero-fills until enough raw samples arrive")
    func paddedHistoryZeroFillsBeforeCapacityIsReached() {
        let settings = makeTestSettings()
        settings.historyCapacity = 4
        let monitor = SystemMonitor(settings: settings)

        monitor.record(cpu: CPUUsage(user: 8, system: 4, idle: 88, perCore: [], coreFrequencies: []))
        monitor.record(network: NetworkUsage(bytesInPerSec: 2_048, bytesOutPerSec: 4_096))

        #expect(monitor.paddedCPUHistory == [0, 0, 0, 12])
        #expect(monitor.paddedNetworkInHistory == [0, 0, 0, 2_048])
        #expect(monitor.paddedNetworkOutHistory == [0, 0, 0, 4_096])
    }

    @Test("historyCapacity changes recreate buffers without a view-model adapter")
    func historyCapacityChangeRecreatesBuffersViaSettingsObservation() async throws {
        let settings = makeTestSettings()
        settings.historyCapacity = 60
        let monitor = SystemMonitor(settings: settings)

        monitor.record(cpu: CPUUsage(user: 30, system: 12, idle: 58, perCore: [], coreFrequencies: []))
        #expect(monitor.cpuSamples.values.map(\.used) == [42])

        settings.historyCapacity = 300
        try await Task.sleep(for: .milliseconds(50))

        #expect(monitor.cpuSamples.capacity == 300)
        #expect(monitor.cpuSamples.values.isEmpty)
    }

    @Test("resetHistories keeps current buffers until historyCapacity changes, then recreates them")
    func resetHistoriesRecreatesBuffersOnCapacityChange() {
        let defaults = makeTestDefaults()
        let key = "historyCapacity"
        defaults.set(60, forKey: key)
        let settings = makeTestSettings(defaults: defaults)
        let monitor = SystemMonitor(settings: settings)
        monitor.start()
        defer { monitor.stop() }

        #expect(!monitor.cpuSamples.values.isEmpty)
        #expect(!monitor.gpuSamples.values.isEmpty)
        #expect(!monitor.networkSamples.values.isEmpty)

        monitor.resetHistories()
        #expect(monitor.cpuSamples.capacity == 60)
        #expect(!monitor.cpuSamples.values.isEmpty)
        #expect(!monitor.gpuSamples.values.isEmpty)
        #expect(!monitor.networkSamples.values.isEmpty)
        #expect(monitor.thermalSamples.capacity == 60)
        #expect(monitor.fansSamples.capacity == 60)

        settings.historyCapacity = 300
        monitor.resetHistories()

        #expect(monitor.cpuSamples.capacity == 300)
        #expect(monitor.gpuSamples.capacity == 300)
        #expect(monitor.networkSamples.capacity == 300)
        #expect(monitor.thermalSamples.capacity == 300)
        #expect(monitor.fansSamples.capacity == 300)
        #expect(monitor.cpuSamples.values.isEmpty)
        #expect(monitor.gpuSamples.values.isEmpty)
        #expect(monitor.networkSamples.values.isEmpty)
    }
}

@Suite("Settings Window")
struct SettingsWindowTests {

    @Test("settings window uses a stable scene identifier and size contract")
    func stableWindowConfiguration() {
        #expect(AppSceneID.settingsWindow == "settings-window")
        #expect(SettingsWindowLayout.defaultWidth == 820)
        #expect(SettingsWindowLayout.defaultHeight == 520)
        #expect(SettingsWindowLayout.sidebarWidth == 130)
        #expect(SettingsWindowLayout.defaultWidth > SettingsWindowLayout.sidebarWidth)
    }
}

@Suite("Dashboard Toolbar")
@MainActor
struct DashboardToolbarTests {
    @Test("dashboard column default comes from app settings contract")
    func dashboardColumnDefault() {
        let defaults = makeTestDefaults()
        let key = "dashboardColumns"
        defaults.removeObject(forKey: key)
        let settings = makeTestSettings(defaults: defaults)

        #expect(settings.dashboardColumns == AppSettings.defaultDashboardColumns)
    }

    @Test("dashboard column restores persisted values within supported range")
    func dashboardColumnRestoreClampsOutOfRangeValues() {
        let defaults = makeTestDefaults()
        let key = "dashboardColumns"
        defaults.set(2, forKey: key)
        #expect(makeTestSettings(defaults: defaults).dashboardColumns == AppSettings.dashboardColumnRange.lowerBound)

        defaults.set(7, forKey: key)
        #expect(makeTestSettings(defaults: defaults).dashboardColumns == AppSettings.dashboardColumnRange.upperBound)
    }

    @Test("all supported menu bar monitor items default to visible")
    func monitorItemVisibilityDefaults() {
        let defaults = makeTestDefaults()
        let keys = [
            "showCPU",
            "showGPU",
            "showMemory",
            "showDisk",
            "showNetwork",
            "showBattery",
            "showThermal",
            "showPower",
            "showFans",
        ]
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        let settings = makeTestSettings(defaults: defaults)

        #expect(settings.showCPU)
        #expect(settings.showGPU)
        #expect(settings.showMemory)
        #expect(settings.showDisk)
        #expect(settings.showNetwork)
        #expect(settings.showBattery)
        #expect(settings.showThermal)
        #expect(settings.showPower)
        #expect(settings.showFans)
    }

    @Test("columns slider binding reflects and rounds dashboard column count")
    func columnsSliderBindingRoundsToNearestWholeNumber() {
        let defaults = makeTestDefaults()
        let settings = makeTestSettings(defaults: defaults)
        settings.dashboardColumns = AppSettings.dashboardColumnRange.lowerBound

        let binding = DashboardColumnsSlider.binding(for: settings)

        #expect(binding.wrappedValue == Double(AppSettings.dashboardColumnRange.lowerBound))

        binding.wrappedValue = 4.6
        #expect(settings.dashboardColumns == 5)

        binding.wrappedValue = 1.2
        #expect(settings.dashboardColumns == AppSettings.dashboardColumnRange.lowerBound)

        binding.wrappedValue = 7.2
        #expect(settings.dashboardColumns == AppSettings.dashboardColumnRange.upperBound)
    }

    @Test("isolated settings writes do not leak into standard defaults")
    func isolatedSettingsDoNotPolluteStandardDefaults() {
        let standardDefaults = UserDefaults.standard
        let key = "historyCapacity"
        let originalValue = standardDefaults.object(forKey: key)
        defer {
            if let originalValue {
                standardDefaults.set(originalValue, forKey: key)
            } else {
                standardDefaults.removeObject(forKey: key)
            }
        }

        standardDefaults.set(60, forKey: key)

        let defaults = makeTestDefaults()
        let settings = makeTestSettings(defaults: defaults)
        settings.historyCapacity = 300

        #expect(defaults.integer(forKey: key) == 300)
        #expect(standardDefaults.integer(forKey: key) == 60)
    }
}

@Suite("Detail Panels")
@MainActor
struct DetailPanelTests {

    @Test("each detail view owns its panel title")
    func detailViewsExposeTheirOwnTitles() {
        let titles = [
            CPUDetailView.panelTitle,
            GPUDetailView.panelTitle,
            MemoryDetailView.panelTitle,
            DiskDetailView.panelTitle,
            NetworkDetailView.panelTitle,
            ThermalDetailView.panelTitle,
            PowerDetailView.panelTitle,
            FansDetailView.panelTitle,
        ]

        #expect(titles == ["CPU", "GPU", "Memory", "Disk", "Network", "Thermal", "Power", "Fans"])
        #expect(Set(titles).count == PanelID.allCases.count)
    }
}

@Suite("Status Bar")
@MainActor
struct StatusBarTests {

    @Test("menu bar items follow settings visibility and ordering")
    func menuBarItemsFollowVisibilityAndOrdering() {
        let settings = makeTestSettings()
        settings.showCPU = true
        settings.showGPU = false
        settings.showMemory = true
        settings.showDisk = false
        settings.showNetwork = true
        settings.showBattery = true
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(cpu: CPUUsage(user: 20, system: 5, idle: 75, perCore: [], coreFrequencies: []))
        monitor.record(memory: MemoryUsage(
            active: 2_147_483_648,
            wired: 1_073_741_824,
            compressed: 1_073_741_824,
            total: 8_589_934_592
        ))
        monitor.record(network: NetworkUsage(bytesInPerSec: 2_048, bytesOutPerSec: 1_024))
        monitor.record(battery: BatteryUsage(
            percentage: 80,
            isCharging: false,
            isPluggedIn: true,
            timeRemaining: nil,
            cycleCount: 100,
            designCapacity: 5000,
            maxCapacity: 4800,
            health: 96
        ))

        let items = monitor.menuBarItems(settings: settings)
        #expect(items.map(\.panel) == [.cpu, .memory, .network])
        #expect(items.map(\.text) == ["25%", "50%", "2K"])
    }

    @Test("menu bar items carry thermal critical styling")
    func menuBarItemsCarryThermalCriticalStyling() {
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

        #expect(monitor.menuBarItems(settings: settings) == [
            MenuBarItem(
                panel: .thermal,
                symbol: "thermometer.medium",
                text: "CR",
                color: .systemRed,
                symbolPaletteColors: [NSColor.systemRed, NSColor.systemOrange]
            )
        ])
    }

    @Test("status bar label renderer builds one segment per enabled monitor")
    func statusBarLabelRendererBuildsExpectedSegments() {
        let settings = makeTestSettings()
        settings.showCPU = true
        settings.showGPU = false
        settings.showMemory = true
        settings.showDisk = false
        settings.showNetwork = true
        settings.showBattery = true
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(cpu: CPUUsage(user: 20, system: 5, idle: 75, perCore: [], coreFrequencies: []))
        monitor.record(memory: MemoryUsage(
            active: 2_147_483_648,
            wired: 1_073_741_824,
            compressed: 1_073_741_824,
            total: 8_589_934_592
        ))
        monitor.record(network: NetworkUsage(bytesInPerSec: 2_048, bytesOutPerSec: 1_024))
        monitor.record(battery: BatteryUsage(
            percentage: 80,
            isCharging: false,
            isPluggedIn: true,
            timeRemaining: nil,
            cycleCount: 100,
            designCapacity: 5000,
            maxCapacity: 4800,
            health: 96
        ))

        #expect(StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings).map(\.text) == [
            "25%",
            "50%",
            "2K",
        ])
        #expect(StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings).map(\.panel) == [
            .cpu,
            .memory,
            .network,
        ])
    }

    @Test("status bar shows disk total io instead of usage percent")
    func statusBarShowsDiskTotalIO() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = true
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(disk: DiskUsage(
            used: 400_000_000_000,
            total: 1_000_000_000_000,
            readBPS: 8_388_608,
            writeBPS: 2_097_152
        ))

        #expect(StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings) == [
            MenuBarItem(panel: .disk, symbol: "internaldrive", text: "10M", color: .labelColor)
        ])
    }

    @Test("status bar merges battery and power into one power segment")
    func statusBarRendererMergesBatteryAndPower() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = true
        settings.showThermal = false
        settings.showPower = true
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
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

        #expect(StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings) == [
            MenuBarItem(panel: .power, symbol: "bolt.fill", text: "21W", color: .labelColor)
        ])
    }

    @Test("status bar thermal segment shows pressure when temperature is unavailable")
    func statusBarThermalSegmentFallsBackToPressure() {
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
        monitor.record(thermalPressureState: .nominal)

        #expect(StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings) == [
            MenuBarItem(panel: .thermal, symbol: "thermometer.medium", text: "OK", color: .labelColor)
        ])
    }

    @Test("status bar thermal segment turns critical red")
    func statusBarThermalSegmentTurnsCriticalRed() {
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

        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        #expect(segments == [
            MenuBarItem(
                panel: .thermal,
                symbol: "thermometer.medium",
                text: "CR",
                color: .systemRed,
                symbolPaletteColors: [NSColor.systemRed, NSColor.systemOrange]
            )
        ])

        let attributedTitle = StatusBarLabelRenderer.makeAttributedTitle(monitor: monitor, settings: settings)
        let textColor = attributedTitle.attribute(.foregroundColor, at: 2, effectiveRange: nil) as? NSColor
        #expect(textColor == .systemRed)

        let criticalAttachment = attributedTitle.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        #expect(criticalAttachment?.image?.tiffRepresentation != nil)
        let criticalConfigurationDescription = String(describing: criticalAttachment?.image?.symbolConfiguration)
        #expect(criticalConfigurationDescription.contains("prefers multicolor: YES"))

        monitor.record(thermalPressureState: .nominal)
        let nominalTitle = StatusBarLabelRenderer.makeAttributedTitle(monitor: monitor, settings: settings)
        let nominalAttachment = nominalTitle.attribute(.attachment, at: 0, effectiveRange: nil) as? NSTextAttachment
        #expect(criticalAttachment?.image?.tiffRepresentation != nominalAttachment?.image?.tiffRepresentation)
    }

    @Test("status bar hit testing follows rendered segment widths instead of equal slots")
    func statusBarHitTestingUsesMeasuredWidths() {
        let settings = makeTestSettings()
        settings.showCPU = true
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = true
        settings.showBattery = true
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(cpu: CPUUsage(user: 98, system: 1, idle: 1, perCore: [], coreFrequencies: []))
        monitor.record(network: NetworkUsage(bytesInPerSec: 2_048, bytesOutPerSec: 1_024))
        monitor.record(battery: BatteryUsage(
            percentage: 80,
            isCharging: false,
            isPluggedIn: true,
            timeRemaining: nil,
            cycleCount: 100,
            designCapacity: 5000,
            maxCapacity: 4800,
            health: 96
        ))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 7_400,
            gpuMilliWatts: 1_200,
            totalMilliWatts: 9_800
        ))

        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        #expect(segments.map(\.panel) == [.cpu, .network, .power])

        let firstBoundary = StatusBarLabelRenderer.measuredTitleWidth(for: Array(segments.prefix(1)))
        let secondBoundary = StatusBarLabelRenderer.measuredTitleWidth(for: Array(segments.prefix(2)))

        #expect(StatusBarLabelRenderer.panel(at: firstBoundary / 2 + 6, in: segments) == .cpu)
        #expect(StatusBarLabelRenderer.panel(at: (firstBoundary + secondBoundary) / 2 + 6, in: segments) == .network)
        #expect(StatusBarLabelRenderer.panel(at: secondBoundary + 12, in: segments) == .power)
    }

    @Test("status bar keeps a stable measured width when menu values change")
    func statusBarWidthRemainsStableAcrossValueChanges() {
        let settings = makeTestSettings()
        settings.showCPU = true
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = true
        settings.showBattery = false
        settings.showThermal = true
        settings.showPower = true
        settings.showFans = true

        let lowMonitor = SystemMonitor(settings: settings)
        lowMonitor.record(cpu: CPUUsage(user: 4, system: 1, idle: 95, perCore: [], coreFrequencies: []))
        lowMonitor.record(network: NetworkUsage(bytesInPerSec: 512, bytesOutPerSec: 0))
        lowMonitor.record(thermal: ThermalUsage(cpuTemperature: 39.2, gpuTemperature: nil))
        lowMonitor.record(power: PowerUsage(
            cpuMilliWatts: 4_100,
            gpuMilliWatts: 2_400,
            totalMilliWatts: 9_800
        ))
        lowMonitor.record(fans: [
            FanUsage(id: 0, currentRPM: 950, minRPM: 800, maxRPM: 5_000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 1_050, minRPM: 800, maxRPM: 5_000, name: "Right Fan"),
        ])

        let highMonitor = SystemMonitor(settings: settings)
        highMonitor.record(cpu: CPUUsage(user: 98, system: 2, idle: 0, perCore: [], coreFrequencies: []))
        highMonitor.record(network: NetworkUsage(bytesInPerSec: 12 * 1_048_576, bytesOutPerSec: 0))
        highMonitor.record(thermal: ThermalUsage(cpuTemperature: 100.0, gpuTemperature: nil))
        highMonitor.record(power: PowerUsage(
            cpuMilliWatts: 88_500,
            gpuMilliWatts: 12_300,
            totalMilliWatts: 125_300
        ))
        highMonitor.record(fans: [
            FanUsage(id: 0, currentRPM: 5_100, minRPM: 800, maxRPM: 6_000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 5_360, minRPM: 800, maxRPM: 6_000, name: "Right Fan"),
        ])

        let lowWidth = StatusBarLabelRenderer.measuredTitleWidth(
            for: StatusBarLabelRenderer.makeSegments(monitor: lowMonitor, settings: settings)
        )
        let highWidth = StatusBarLabelRenderer.measuredTitleWidth(
            for: StatusBarLabelRenderer.makeSegments(monitor: highMonitor, settings: settings)
        )

        #expect(lowWidth == highWidth)
    }

    @Test("menu bar uses narrower fixed widths for compact metrics")
    func menuBarUsesPanelSpecificFixedWidths() {
        #expect(MenuBarTextLayout.slotLength(for: .cpu) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .gpu) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .memory) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .disk) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .network) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .power) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .thermal) == 4)
        #expect(MenuBarTextLayout.slotLength(for: .fans) == 4)
        #expect(MenuBarTextLayout.slotWidth(for: .cpu) == MenuBarTextLayout.slotWidth(for: .disk))
    }

    @Test("status bar button handles click on mouse down to avoid popover click-through")
    func statusBarButtonHandlesClickOnMouseDown() {
        let button = NSStatusBarButton(frame: .init(x: 0, y: 0, width: 120, height: 22))

        StatusBarController.configureClickBehavior(for: button)

        #expect(button.sendAction(on: []) == StatusBarController.clickActionMask.rawValue)
    }
}

@Suite("Quit Confirmation")
@MainActor
struct QuitConfirmationTests {

    @Test("requesting quit presents confirmation before termination")
    func requestQuitPresentsConfirmation() {
        var terminateCallCount = 0
        let confirmation = QuitConfirmationController {
            terminateCallCount += 1
        }

        confirmation.requestQuit()

        #expect(confirmation.isPresented)
        #expect(terminateCallCount == 0)
    }

    @Test("cancel dismisses confirmation without terminating the app")
    func cancelDismissesWithoutTermination() {
        var terminateCallCount = 0
        let confirmation = QuitConfirmationController {
            terminateCallCount += 1
        }
        confirmation.requestQuit()

        confirmation.cancel()

        #expect(!confirmation.isPresented)
        #expect(terminateCallCount == 0)
    }

    @Test("confirm dismisses confirmation and terminates the app")
    func confirmDismissesAndTerminates() {
        var terminateCallCount = 0
        let confirmation = QuitConfirmationController {
            terminateCallCount += 1
        }
        confirmation.requestQuit()

        confirmation.confirm()

        #expect(!confirmation.isPresented)
        #expect(terminateCallCount == 1)
    }

    @Test("termination gate authorizes only the next terminate request")
    func terminationGateConsumesAuthorizationOnce() {
        let gate = AppTerminationGate()

        #expect(gate.consumeAuthorization() == false)

        gate.authorizeNextTermination()

        #expect(gate.consumeAuthorization() == true)
        #expect(gate.consumeAuthorization() == false)
    }

    @Test("closing the last transient window does not terminate the app")
    func appDoesNotTerminateAfterLastWindowClosed() {
        let delegate = AppDelegate()

        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared) == false)
    }
}

// MARK: - Service Integration Tests

@Suite("MemoryMonitor Integration")
struct MemoryMonitorIntegrationTests {

    @Test("sample() total is positive")
    func totalIsPositive() {
        #expect(MemoryMonitor().sample().total > 0)
    }

    @Test("sample() usedFraction is in 0...1")
    func usedFractionInRange() {
        let result = MemoryMonitor().sample()
        #expect(result.usedFraction >= 0)
        #expect(result.usedFraction <= 1)
    }
}

@Suite("DiskMonitor Integration")
struct DiskMonitorIntegrationTests {

    @Test("sample() total is positive")
    func totalIsPositive() {
        var m = DiskMonitor()
        #expect(m.sample().total > 0)
    }

    @Test("sample() used does not exceed total")
    func usedDoesNotExceedTotal() {
        var m = DiskMonitor()
        let d = m.sample()
        #expect(d.used <= d.total)
    }
}

@Suite("NetworkMonitor Integration")
struct NetworkMonitorIntegrationTests {

    @Test("initial sample() has non-negative bytesInPerSec")
    func bytesInNonNegative() {
        var m = NetworkMonitor()
        #expect(m.sample().bytesInPerSec >= 0)
    }

    @Test("initial sample() has non-negative bytesOutPerSec")
    func bytesOutNonNegative() {
        var m = NetworkMonitor()
        #expect(m.sample().bytesOutPerSec >= 0)
    }
}
