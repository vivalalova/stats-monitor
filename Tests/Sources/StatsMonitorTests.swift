import Foundation
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

    @Test("CPUCoreFrequency isPerformanceCore stores per-core P/E cluster membership")
    func coreFreqStoresPerformanceCoreFlag() {
        let eCore = CPUCoreFrequency(currentHz: 2_400_000_000, maxHz: 2_420_000_000, isPerformanceCore: false)
        let pCore = CPUCoreFrequency(currentHz: 3_400_000_000, maxHz: 3_500_000_000, isPerformanceCore: true)
        let unknownCluster = CPUCoreFrequency(currentHz: 2_100_000_000, maxHz: 3_228_000_000)

        #expect(eCore.isPerformanceCore == false)
        #expect(pCore.isPerformanceCore == true)
        #expect(unknownCluster.isPerformanceCore == nil)
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
        let p = ProcInfo(pid: 101, name: "Xcode", cpuPercent: 12.5, memoryBytes: 500_000_000, powerImpact: 8.4, gpuPercent: 42.5)
        #expect(p.name == "Xcode")
        #expect(p.cpuPercent == 12.5)
        #expect(p.memoryBytes == 500_000_000)
        #expect(p.powerImpact == 8.4)
        #expect(p.gpuPercent == 42.5)
    }

    @Test("PowerMonitor parses top POWER output into per-process energy impact")
    func powerMonitorParsesTopPowerOutput() {
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

        let powerByPID = PowerMonitor.parseTopPowerOutput(output)

        #expect(powerByPID[601] == 45.1)
        #expect(powerByPID[72166] == 14.1)
        #expect(powerByPID[83863] == 13.8)
    }

    @Test("PowerMonitor drains large process output before waiting for exit")
    func powerMonitorDrainsLargeProcessOutputBeforeWaitingForExit() throws {
        let output = try #require(PowerMonitor.runProcessCapturingOutput(
            executableURL: URL(fileURLWithPath: "/bin/sh"),
            arguments: [
                "-c",
                """
                i=1
                while [ "$i" -le 12000 ]; do
                  printf '%05d abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz abcdefghijklmnopqrstuvwxyz\\n' "$i"
                  i=$((i + 1))
                done
                """
            ]
        ))

        #expect(output.terminationStatus == 0)
        #expect(output.stdout.contains("12000 abcdefghijklmnopqrstuvwxyz"))
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

    @Test("computes top memory processes from process snapshots")
    func computesTopMemoryProcesses() {
        let snapshot = ProcessCountersSnapshot(
            entries: [
                .init(pid: 601, name: "WindowServer", cpuTicks: 2_000, memoryBytes: 4_000, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
                .init(pid: 72166, name: "iTerm2", cpuTicks: 1_000, memoryBytes: 9_000, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
                .init(pid: 83863, name: "Codex Helper", cpuTicks: 500, memoryBytes: 7_000, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
            ],
            date: Date(timeIntervalSince1970: 1_000)
        )

        let processes = MemoryMonitor.computeTopProcesses(snapshot: snapshot, processCount: 2)

        #expect(processes.count == 2)
        #expect(processes[0].name == "iTerm2")
        #expect(processes[0].memoryBytes == 9_000)
        #expect(processes[1].name == "Codex Helper")
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

    @Test("computes top power processes sorted by impact then name")
    func computesTopPowerProcesses() {
        let snapshot = ProcessCountersSnapshot(
            entries: [
                .init(pid: 601, name: "WindowServer", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 45.1),
                .init(pid: 72166, name: "iTerm2", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 14.1),
                .init(pid: 83863, name: "Codex Helper", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 14.1),
                .init(pid: 99935, name: "idle", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
            ],
            date: Date(timeIntervalSince1970: 1_000)
        )

        let processes = PowerMonitor.computeTopProcesses(snapshot: snapshot, processCount: 3)

        #expect(processes.count == 3)
        #expect(processes[0].name == "WindowServer")
        #expect(processes[1].name == "Codex Helper")
        #expect(processes[2].name == "iTerm2")
    }
}

@Suite("CPUMonitor")
struct CPUMonitorTests {

    @Test("computes top cpu processes from tick deltas")
    func computesTopCPUProcesses() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = ProcessCountersSnapshot(
            entries: [
                .init(pid: 601, name: "WindowServer", cpuTicks: 5_000_000_000, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
                .init(pid: 72166, name: "iTerm2", cpuTicks: 3_000_000_000, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
                .init(pid: 83863, name: "Codex Helper", cpuTicks: 2_500_000_000, memoryBytes: 0, diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
            ],
            date: now
        )

        let processes = CPUMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: [
                601: CPUMonitor.ProcessSnapshot(ticks: 3_000_000_000, date: now.addingTimeInterval(-2)),
                72166: CPUMonitor.ProcessSnapshot(ticks: 2_000_000_000, date: now.addingTimeInterval(-2)),
                83863: CPUMonitor.ProcessSnapshot(ticks: 2_400_000_000, date: now.addingTimeInterval(-2))
            ],
            processCount: 2,
            nanosecondsPerTick: 1.0
        )

        #expect(processes.count == 2)
        #expect(processes[0].name == "WindowServer")
        #expect(processes[0].cpuPercent == 100)
        #expect(processes[1].name == "iTerm2")
        #expect(processes[1].cpuPercent == 50)
    }

    @Test("cpuPercent converts mach ticks via timebase (Apple Silicon 125/3 ratio)")
    func cpuPercentConvertsMachTicks() {
        let now = Date(timeIntervalSince1970: 1_000)
        // Apple Silicon: hw.tbfrequency = 24_000_000 → 1 full core for 2 sec = 48_000_000 ticks.
        let snapshot = ProcessCountersSnapshot(
            entries: [
                .init(pid: 601, name: "FullCore", cpuTicks: 48_000_000, memoryBytes: 0,
                      diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0),
                .init(pid: 602, name: "HalfCore", cpuTicks: 24_000_000, memoryBytes: 0,
                      diskReadBytes: 0, diskWriteBytes: 0, powerImpact: 0)
            ],
            date: now
        )

        let processes = CPUMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: [
                601: CPUMonitor.ProcessSnapshot(ticks: 0, date: now.addingTimeInterval(-2)),
                602: CPUMonitor.ProcessSnapshot(ticks: 0, date: now.addingTimeInterval(-2))
            ],
            processCount: 2,
            nanosecondsPerTick: 125.0 / 3.0
        )

        #expect(processes.count == 2)
        #expect(processes[0].name == "FullCore")
        #expect(abs((processes[0].cpuPercent ?? 0) - 100.0) < 0.01)
        #expect(processes[1].name == "HalfCore")
        #expect(abs((processes[1].cpuPercent ?? 0) - 50.0) < 0.01)
    }

    @Test("CPU tick deltas handle 32-bit counter wrap")
    func cpuTickDeltaHandlesCounterWrap() {
        #expect(CPUMonitor.cpuTickDelta(current: 4, previous: UInt32.max - 2) == 7)
    }

    /// 高耗能行程表借 CPU% 時要看該輪 CPU 全表，而不是只看 top N：
    /// 進 power 榜卻沒進 CPU 前 N 名的行程，CPU% 在同一份 snapshot 裡算得出來，
    /// 顯示成「量不到」是假的。全表版負責不截斷，top 版只是它的 prefix。
    @Test("全表版不截斷：每個有 delta 的行程都在，且依 CPU% 遞減")
    func computesAllProcessesWithoutTruncation() {
        let now = Date(timeIntervalSince1970: 1_000)
        let entryCount = 12
        let snapshot = ProcessCountersSnapshot(
            entries: (0..<entryCount).map { index in
                .init(
                    pid: Int32(1_000 + index),
                    name: "proc\(index)",
                    cpuTicks: UInt64((entryCount - index) * 100_000_000),
                    memoryBytes: 0,
                    diskReadBytes: 0,
                    diskWriteBytes: 0,
                    powerImpact: 0
                )
            },
            date: now
        )
        let previous = Dictionary(uniqueKeysWithValues: (0..<entryCount).map { index in
            (Int32(1_000 + index), CPUMonitor.ProcessSnapshot(ticks: 0, date: now.addingTimeInterval(-2)))
        })

        let all = CPUMonitor.computeAllProcesses(
            snapshot: snapshot,
            previousSnapshots: previous,
            nanosecondsPerTick: 1.0
        )

        #expect(all.count == entryCount)
        #expect(all.map(\.name) == (0..<entryCount).map { "proc\($0)" })

        // top 版 = 全表 prefix，兩者不得各自為政。
        let top = CPUMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: previous,
            processCount: 3,
            nanosecondsPerTick: 1.0
        )
        #expect(top.map(\.name) == Array(all.prefix(3)).map(\.name))
        #expect(top.count == 3)
    }

    /// `CPUProcessSampler` 的 previousSnapshots 有副作用，一輪只能取樣一次 ——
    /// 所以那一次必須拿到全表，top N 由呼叫端自己 prefix。
    @Test("sampleAllProcesses：首輪無前值回空，次輪回全表不截斷")
    func sampleAllProcessesReturnsFullTable() {
        let monitor = CPUMonitor()
        let start = Date(timeIntervalSince1970: 1_000)
        let entryCount = 12
        func makeSnapshot(ticks: UInt64, date: Date) -> ProcessCountersSnapshot {
            ProcessCountersSnapshot(
                entries: (0..<entryCount).map { index in
                    .init(
                        pid: Int32(1_000 + index),
                        name: "proc\(index)",
                        cpuTicks: ticks * UInt64(entryCount - index),
                        memoryBytes: 0,
                        diskReadBytes: 0,
                        diskWriteBytes: 0,
                        powerImpact: 0
                    )
                },
                date: date
            )
        }

        let first = monitor.sampleAllProcesses(from: makeSnapshot(ticks: 0, date: start))
        #expect(first.isEmpty)

        let second = monitor.sampleAllProcesses(
            from: makeSnapshot(ticks: 100_000_000, date: start.addingTimeInterval(2))
        )
        #expect(second.count == entryCount)
        #expect(second.allSatisfy { ($0.cpuPercent ?? 0) > 0 })
    }
}

@Suite("DiskMonitor")
struct DiskMonitorProcessTests {

    @Test("computes top disk processes from cumulative io deltas")
    func computesTopDiskProcesses() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = ProcessCountersSnapshot(
            entries: [
                .init(pid: 601, name: "WindowServer", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 5_000, diskWriteBytes: 1_000, powerImpact: 0),
                .init(pid: 72166, name: "iTerm2", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 2_000, diskWriteBytes: 4_000, powerImpact: 0),
                .init(pid: 83863, name: "Codex Helper", cpuTicks: 0, memoryBytes: 0, diskReadBytes: 100, diskWriteBytes: 100, powerImpact: 0),
            ],
            date: now
        )

        let processes = DiskMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: [
                601: DiskMonitor.ProcessSnapshot(readBytes: 1_000, writeBytes: 500, date: now.addingTimeInterval(-2)),
                72166: DiskMonitor.ProcessSnapshot(readBytes: 1_000, writeBytes: 1_000, date: now.addingTimeInterval(-2)),
                83863: DiskMonitor.ProcessSnapshot(readBytes: 100, writeBytes: 100, date: now.addingTimeInterval(-2)),
            ],
            processCount: 2
        )

        #expect(processes.count == 2)
        #expect(processes[0].name == "WindowServer")
        #expect(processes[0].diskReadBPS == 2_000)
        #expect(processes[0].diskWriteBPS == 250)
        #expect(processes[1].name == "iTerm2")
        #expect(processes[1].diskTotalBPS == 2_000)
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

    @Test("parses AppUsage snapshot when value is strongly typed [[String: Any]]")
    func parsesSnapshotFromStrictlyTypedDict() {
        let snapshot = GPUMonitor.parseAppUsageSnapshot(from: [
            "IOUserClientCreator": "pid 601, WindowServer",
            "AppUsage": [
                ["accumulatedGPUTime": UInt64(1_500_000_000), "API": "Metal"] as [String: Any],
                ["accumulatedGPUTime": UInt64(500_000_000), "API": "Metal"] as [String: Any],
            ],
            "CommandQueueCount": 4,
        ])

        #expect(snapshot?.pid == 601)
        #expect(snapshot?.name == "WindowServer")
        #expect(snapshot?.accumulatedGPUTime == 2_000_000_000)
        #expect(snapshot?.commandQueueCount == 4)
    }

    @Test("parses AppUsage snapshot when value arrives type-erased as [Any]")
    func parsesSnapshotFromTypeErasedArray() {
        let rawEntries: [Any] = [
            ["accumulatedGPUTime": UInt64(3_000_000_000), "API": "Metal"] as [String: Any]
        ]
        let snapshot = GPUMonitor.parseAppUsageSnapshot(from: [
            "IOUserClientCreator": "pid 1240, Finder",
            "AppUsage": rawEntries,
        ])

        #expect(snapshot?.pid == 1240)
        #expect(snapshot?.name == "Finder")
        #expect(snapshot?.accumulatedGPUTime == 3_000_000_000)
        #expect(snapshot?.commandQueueCount == 0)
    }

    @Test("returns nil when AppUsage is empty")
    func returnsNilForEmptyAppUsage() {
        let snapshot = GPUMonitor.parseAppUsageSnapshot(from: [
            "IOUserClientCreator": "pid 606, runningboardd",
            "AppUsage": [] as [Any],
        ])
        #expect(snapshot == nil)
    }

    @Test("returns nil when AppUsage key is missing")
    func returnsNilWhenAppUsageMissing() {
        let snapshot = GPUMonitor.parseAppUsageSnapshot(from: [
            "IOUserClientCreator": "pid 606, runningboardd",
        ])
        #expect(snapshot == nil)
    }

    @Test("returns nil when accumulated GPU time is zero")
    func returnsNilForZeroAccumulatedTime() {
        let snapshot = GPUMonitor.parseAppUsageSnapshot(from: [
            "IOUserClientCreator": "pid 601, WindowServer",
            "AppUsage": [
                ["accumulatedGPUTime": UInt64(0), "API": "Metal"] as [String: Any],
            ],
        ])
        #expect(snapshot == nil)
    }

    @Test("coerces heterogeneous AppUsage elements to typed dicts")
    func coercesHeterogeneousElements() {
        let mixed: [Any] = [
            ["accumulatedGPUTime": UInt64(100)] as [String: Any],
            "unexpected string",
            ["accumulatedGPUTime": UInt64(200)] as [String: Any],
        ]
        let coerced = GPUMonitor.coerceAppUsageArray(mixed)
        #expect(coerced.count == 2)
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

    @Test("network byte rate returns zero when counters reset")
    func byteRateReturnsZeroWhenCountersReset() {
        #expect(NetworkMonitor.bytesPerSecond(current: 500, previous: 1_000, elapsed: 2) == 0)
        #expect(NetworkMonitor.bytesPerSecond(current: 1_500, previous: 500, elapsed: 2) == 500)
        #expect(NetworkMonitor.bytesPerSecond(current: 1_500, previous: 500, elapsed: 0) == 0)
    }

    @Test("computes top network processes from cumulative samples")
    func computesTopNetworkProcesses() {
        let now = Date(timeIntervalSince1970: 1_000)
        let previous = [
            "Safari.123": NetworkMonitor.ProcessSnapshot(bytesIn: 1_000, bytesOut: 500, date: now.addingTimeInterval(-2)),
            "Slack.456": NetworkMonitor.ProcessSnapshot(bytesIn: 500, bytesOut: 500, date: now.addingTimeInterval(-2)),
        ]

        let processes = NetworkMonitor.computeTopProcesses(
            currentCounters: [
                "Safari.123": (bytesIn: 5_000, bytesOut: 1_500),
                "Slack.456": (bytesIn: 700, bytesOut: 700),
            ],
            previousSnapshots: previous,
            now: now,
            processCount: 2
        )

        #expect(processes.count == 2)
        #expect(processes[0].name == "Safari")
        #expect(processes[0].networkInBPS == 2_000)
        #expect(processes[0].networkOutBPS == 500)
        #expect(processes[1].name == "Slack")
        #expect(processes[1].networkTotalBPS == 200)
    }

    @Test("network process sampler state survives monitor copies")
    func networkProcessSamplerStateSurvivesMonitorCopies() {
        let sampler = NetworkProcessSampler()
        let monitor = NetworkMonitor(processSampler: sampler)
        let backgroundCopy = monitor
        let start = Date(timeIntervalSince1970: 1_000)

        _ = backgroundCopy.sampleTopProcesses(
            currentCounters: ["Safari.601": (bytesIn: 100, bytesOut: 50)],
            now: start,
            processCount: 3
        )

        let processes = monitor.sampleTopProcesses(
            currentCounters: ["Safari.601": (bytesIn: 700, bytesOut: 250)],
            now: start.addingTimeInterval(2),
            processCount: 3
        )

        #expect(processes.count == 1)
        #expect(processes[0].name == "Safari")
        #expect(processes[0].networkInBPS == 300)
        #expect(processes[0].networkOutBPS == 100)
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

    // MARK: - Power chart lines (dual-line power chart: consumption + external input)

    @Test("powerChartLines includes a green external input line when external input power is present")
    func powerChartLinesIncludesExternalInputLineWhenPresent() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 2_300,
            gpuMilliWatts: 200,
            totalMilliWatts: 11_500,
            externalInputMilliWatts: 15_000
        ))

        let lines = powerChartLines(monitor: monitor)

        #expect(lines.count == 2)
        #expect(lines[0].color == .red)
        #expect(lines[0].history == monitor.paddedPowerHistory)
        #expect(lines[1].color == .green)
        #expect(lines[1].history == monitor.paddedExternalInputPowerHistory)
    }

    @Test("powerChartLines omits the external input line when external input power is unavailable")
    func powerChartLinesOmitsExternalInputLineWithoutExternalInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 2_300,
            gpuMilliWatts: 200,
            totalMilliWatts: 11_500
        ))

        let lines = powerChartLines(monitor: monitor)

        #expect(lines.count == 1)
        #expect(lines[0].color == .red)
        #expect(lines[0].history == monitor.paddedPowerHistory)
    }

    @Test("powerChartUpperBound scales to the larger of consumption and external input peaks")
    func powerChartUpperBoundUsesLargerOfConsumptionAndExternalInputPeaks() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 0,
            gpuMilliWatts: 0,
            totalMilliWatts: 20_000,
            externalInputMilliWatts: 40_000
        ))

        #expect(powerChartUpperBound(monitor: monitor) == 40)
    }

    @Test("powerChartUpperBound falls back to the consumption peak when there is no external input")
    func powerChartUpperBoundUsesConsumptionPeakWithoutExternalInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(power: PowerUsage(cpuMilliWatts: 0, gpuMilliWatts: 0, totalMilliWatts: 20_000))

        #expect(powerChartUpperBound(monitor: monitor) == 20)
    }

    @Test("powerChartUpperBound defaults to 1 when no power history has been recorded")
    func powerChartUpperBoundDefaultsToOneWhenEmpty() {
        let monitor = makeMonitor()
        defer { monitor.stop() }

        #expect(powerChartUpperBound(monitor: monitor) == 1)
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
            ProcInfo(pid: 601, name: "WindowServer", gpuPercent: 23.5)
        ]

        #expect(monitor.gpuTilerPercent == "17.0%")
        #expect(monitor.gpuVramUsedText == "653 MB")
        #expect(monitor.gpuDriverMemoryText == "50 MB")
        #expect(monitor.gpuAllocatedMemoryText == "10.0 GB")
        #expect(monitor.formatProcessGPU(monitor.topGPUProcesses[0].gpuPercent) == "23.5%")
        #expect(monitor.formatProcessGPU(42.5) == "42.5%")
        #expect(monitor.formatProcessGPU(0) == "0.0%")
    }

    @Test("gpu detail exposes frequency when available")
    func gpuDetailFormattingShowsFrequency() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(gpu: GPUUsage(
            deviceUtilization: 20,
            renderUtilization: 19,
            tilerUtilization: 17,
            engines: ["Device": 20],
            vramUsed: 685_047_808,
            frequency: CPUCoreFrequency(currentHz: 860_000_000, maxHz: 1_398_000_000)
        ))

        #expect(monitor.gpuFrequencyText == "860M")
        #expect(monitor.gpuFrequencyMaxHz == 1_398_000_000)
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

    @Test("power menu styling is normal by default")
    func powerMenuStylingDefault() {
        let monitor = makeMonitor()
        defer { monitor.stop() }

        #expect(monitor.powerMenuColor == .labelColor)
        #expect(monitor.powerMenuSymbolPaletteColors == nil)
    }

    @Test("power menu styling turns yellow when low power mode is enabled")
    func powerMenuStylingLowPowerMode() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(isLowPowerModeEnabled: true)

        #expect(monitor.powerMenuColor == NSColor.systemYellow)
        #expect(monitor.powerMenuSymbolPaletteColors?.count == 2)
        #expect(monitor.powerMenuSymbolPaletteColors?[0] == NSColor.systemYellow)
        #expect(monitor.powerMenuSymbolPaletteColors?[1] == NSColor.systemOrange)
    }

    @Test("power menu styling turns red at low battery threshold (20%)")
    func powerMenuStylingLowBatteryAtThreshold() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 20, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))

        #expect(monitor.powerMenuColor == NSColor.systemRed)
        #expect(monitor.powerMenuSymbolPaletteColors?.count == 2)
        #expect(monitor.powerMenuSymbolPaletteColors?[0] == NSColor.systemRed)
        #expect(monitor.powerMenuSymbolPaletteColors?[1] == NSColor.systemOrange)
    }

    @Test("power menu styling stays normal just above low battery threshold (21%)")
    func powerMenuStylingAboveLowBatteryThreshold() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 21, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))

        #expect(monitor.powerMenuColor == .labelColor)
        #expect(monitor.powerMenuSymbolPaletteColors == nil)
    }

    @Test("power menu styling ignores low battery while charging")
    func powerMenuStylingLowBatteryWhileCharging() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 15, isCharging: true, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))

        #expect(monitor.powerMenuColor == .labelColor)
        #expect(monitor.powerMenuSymbolPaletteColors == nil)
    }

    @Test("power menu styling ignores low battery while plugged in")
    func powerMenuStylingLowBatteryWhilePluggedIn() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(battery: BatteryUsage(
            percentage: 15, isCharging: false, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))

        #expect(monitor.powerMenuColor == .labelColor)
        #expect(monitor.powerMenuSymbolPaletteColors == nil)
    }

    @Test("power menu styling prefers red when low battery and low power mode are both active")
    func powerMenuStylingLowBatteryTakesPriorityOverLowPowerMode() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.record(isLowPowerModeEnabled: true)
        monitor.record(battery: BatteryUsage(
            percentage: 15, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        ))

        #expect(monitor.powerMenuColor == NSColor.systemRed)
        #expect(monitor.powerMenuSymbolPaletteColors?.count == 2)
        #expect(monitor.powerMenuSymbolPaletteColors?[0] == NSColor.systemRed)
        #expect(monitor.powerMenuSymbolPaletteColors?[1] == NSColor.systemOrange)
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
        let process = ProcInfo(pid: 102, name: "Xcode", cpuPercent: 12.5, memoryBytes: 500_000_000, powerImpact: 14.16)
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

    @Test("cpu per-core histories stay aligned with recorded samples")
    func paddedCPUPerCoreHistoriesStayAligned() {
        let settings = makeTestSettings()
        settings.historyCapacity = 4
        let monitor = SystemMonitor(settings: settings)

        monitor.record(cpu: CPUUsage(user: 8, system: 4, idle: 88, perCore: [10, 20], coreFrequencies: []))
        monitor.record(cpu: CPUUsage(user: 20, system: 10, idle: 70, perCore: [30, 40], coreFrequencies: []))

        #expect(monitor.paddedCPUPerCoreHistories == [
            [0, 0, 10, 30],
            [0, 0, 20, 40],
        ])
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

    @Test("optional telemetry nil samples clear stale current values without deleting history")
    func optionalTelemetryNilSamplesClearStaleCurrentValuesWithoutDeletingHistory() {
        let monitor = SystemMonitor(settings: makeTestSettings())
        monitor.record(battery: BatteryUsage(
            percentage: 77,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: nil,
            cycleCount: 10,
            designCapacity: 5_000,
            maxCapacity: 4_700,
            health: 94
        ))
        monitor.record(thermal: ThermalUsage(cpuTemperature: 64.2, gpuTemperature: nil))
        monitor.record(power: PowerUsage(cpuMilliWatts: 2_000, gpuMilliWatts: 1_000, totalMilliWatts: 3_000))

        monitor.record(battery: nil)
        monitor.record(thermal: nil)
        monitor.record(power: nil)

        #expect(monitor.batterySamples.values.map(\.percentage) == [77])
        #expect(monitor.thermalSamples.values.map(\.cpuTemperature) == [64.2])
        #expect(monitor.powerSamples.values.map(\.totalMilliWatts) == [3_000])
        #expect(monitor.batteryPercent == "N/A")
        #expect(monitor.cpuTempText == "N/A")
        #expect(monitor.powerText == "N/A")
    }

    @Test("sample interval tracker uses elapsed wall time after first poll")
    func sampleIntervalTrackerUsesElapsedWallTime() {
        var tracker = SampleIntervalTracker(fallbackInterval: 2)
        let start = Date(timeIntervalSince1970: 1_000)

        #expect(tracker.interval(at: start) == 2)
        #expect(tracker.interval(at: start.addingTimeInterval(5.5)) == 5.5)
        #expect(tracker.interval(at: start.addingTimeInterval(5.0)) == 2)
    }
}

@Suite("Diagnostics")
@MainActor
struct DiagnosticsTests {

    private func makeAboutData() -> AboutView.SnapshotData {
        AboutView.SnapshotData(
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

    private func makeSeededMonitor(settings: AppSettings) -> SystemMonitor {
        let monitor = SystemMonitor(settings: settings)
        monitor.record(cpu: CPUUsage(user: 20, system: 5, idle: 75, perCore: [], coreFrequencies: []))
        monitor.record(gpu: GPUUsage(
            deviceUtilization: 42,
            renderUtilization: 30,
            engines: [:],
            vramUsed: 0,
            frequency: CPUCoreFrequency(currentHz: 860_000_000, maxHz: 1_398_000_000)
        ))
        monitor.record(memory: MemoryUsage(active: 4_000_000_000, wired: 2_000_000_000, compressed: 1_000_000_000, total: 16_000_000_000))
        monitor.record(disk: DiskUsage(used: 500_000_000_000, total: 1_000_000_000_000, readBPS: 1_048_576, writeBPS: 524_288))
        monitor.record(network: NetworkUsage(
            bytesInPerSec: 2_097_152,
            bytesOutPerSec: 524_288,
            wifi: WiFiLinkInfo(
                rssiDBm: -58,
                noiseDBm: -92,
                linkRateMbps: 1_200,
                channelNumber: 149,
                band: "5 GHz",
                hardwareAddress: "a4:83:e7:00:11:22"
            )
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
        monitor.record(thermal: ThermalUsage(cpuTemperature: 68.4, gpuTemperature: 57.2))
        monitor.record(thermalPressureState: .nominal)
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            mediaEngineMilliWatts: 1_450,
            totalMilliWatts: 21_300
        ))
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])
        monitor.record(displayInfo: DisplayInfo(widthPixels: 3456, heightPixels: 2234, refreshRateHz: 120))
        return monitor
    }

    @Test("hardware diagnostics classify support from monitor samples")
    func hardwareDiagnosticsClassifySupport() {
        let settings = makeTestSettings()
        let monitor = makeSeededMonitor(settings: settings)

        let diagnostics = HardwareDiagnosticsSnapshot.make(monitor: monitor)

        #expect(diagnostics.item(id: .battery)?.availability == .available)
        #expect(diagnostics.item(id: .powerTelemetry)?.availability == .available)
        #expect(diagnostics.item(id: .thermalSensors)?.availability == .available)
        #expect(diagnostics.item(id: .fanSensors)?.availability == .available)
        #expect(diagnostics.item(id: .wifiLink)?.availability == .available)
        #expect(diagnostics.item(id: .gpuFrequency)?.availability == .available)
        #expect(diagnostics.item(id: .mediaEnginePower)?.availability == .available)
        #expect(diagnostics.item(id: .displayMode)?.detail == "3456 × 2234 @ 120 Hz")
    }

    @Test("hardware diagnostics mark optional telemetry unavailable without samples")
    func hardwareDiagnosticsMarkUnavailableTelemetry() {
        let monitor = SystemMonitor(settings: makeTestSettings())

        let diagnostics = HardwareDiagnosticsSnapshot.make(monitor: monitor)

        #expect(diagnostics.item(id: .battery)?.availability == .unavailable)
        #expect(diagnostics.item(id: .powerTelemetry)?.availability == .unavailable)
        #expect(diagnostics.item(id: .thermalSensors)?.availability == .unavailable)
        #expect(diagnostics.item(id: .fanSensors)?.availability == .unavailable)
        #expect(diagnostics.item(id: .wifiLink)?.availability == .unavailable)
        #expect(diagnostics.item(id: .displayMode)?.availability == .unavailable)
    }

    @Test("diagnostics report renders app, settings, hardware, samples, and crash summaries")
    func diagnosticsReportRendersCompleteSections() {
        let settings = makeTestSettings()
        settings.pollInterval = 5
        settings.historyCapacity = 300
        settings.processCount = 15
        settings.dashboardColumns = 5
        settings.launchAtLogin = true
        let monitor = makeSeededMonitor(settings: settings)
        let generatedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let crashReports = CrashReportScanResult.reports([
            CrashReportSummary(
                fileName: "StatsMonitor-2026-05-30-171207.ips",
                modifiedAt: Date(timeIntervalSince1970: 1_800_000_100),
                exception: "EXC_BREAKPOINT",
                signal: "SIGTRAP",
                termination: "SIGNAL 5"
            )
        ])

        let report = DiagnosticsReport.make(
            aboutData: makeAboutData(),
            settings: settings,
            monitor: monitor,
            generatedAt: generatedAt,
            crashReports: crashReports
        )
        let text = report.renderMarkdown()

        #expect(text.contains("# StatsMonitor Diagnostics"))
        #expect(text.contains("- Version: 1.2.0 (120)"))
        #expect(text.contains("- Poll Interval: 5 sec"))
        #expect(text.contains("- History Capacity: 300 samples"))
        #expect(text.contains("- Battery: Available — 78%, 2h 45m"))
        #expect(text.contains("- CPU Samples: 1 / 300"))
        #expect(text.contains("- StatsMonitor-2026-05-30-171207.ips: EXC_BREAKPOINT / SIGTRAP, SIGNAL 5"))
    }

    @Test("crash report scanner orders recent reports and parses exception metadata")
    func crashReportScannerParsesRecentReports() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("StatsMonitorCrashReports-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let older = directory.appendingPathComponent("StatsMonitor-2026-05-30-160000.ips")
        let newer = directory.appendingPathComponent("StatsMonitor-2026-05-30-171207.ips")
        let otherApp = directory.appendingPathComponent("OtherApp-2026-05-30-171207.ips")
        let crashJSON = """
        {
          "exception" : { "type" : "EXC_BREAKPOINT", "signal" : "SIGTRAP" },
          "termination" : { "namespace" : "SIGNAL", "code" : 5 }
        }
        """
        try crashJSON.write(to: older, atomically: true, encoding: .utf8)
        try crashJSON.write(to: newer, atomically: true, encoding: .utf8)
        try crashJSON.write(to: otherApp, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_000)], ofItemAtPath: older.path)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_100)], ofItemAtPath: newer.path)

        let result = CrashReportReader.scan(appName: "StatsMonitor", directory: directory, limit: 1)

        guard case let .reports(reports) = result else {
            Issue.record("Expected reports, got \(result)")
            return
        }
        #expect(reports.count == 1)
        #expect(reports[0].fileName == "StatsMonitor-2026-05-30-171207.ips")
        #expect(reports[0].exception == "EXC_BREAKPOINT")
        #expect(reports[0].signal == "SIGTRAP")
        #expect(reports[0].termination == "SIGNAL 5")
    }

    @Test("crash report scanner limits recent reports before reading bodies")
    func crashReportScannerLimitsBeforeReadingBodies() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("StatsMonitorCrashReportLimit-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let older = directory.appendingPathComponent("StatsMonitor-2026-05-30-160000.ips")
        let newer = directory.appendingPathComponent("StatsMonitor-2026-05-30-171207.ips")
        let crashJSON = """
        {
          "exception" : { "type" : "EXC_BREAKPOINT", "signal" : "SIGTRAP" },
          "termination" : { "namespace" : "SIGNAL", "code" : 5 }
        }
        """
        try crashJSON.write(to: older, atomically: true, encoding: .utf8)
        try crashJSON.write(to: newer, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_000)], ofItemAtPath: older.path)
        try fileManager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 1_800_000_100)], ofItemAtPath: newer.path)

        var readFileNames: [String] = []
        let result = CrashReportReader.scan(
            appName: "StatsMonitor",
            directory: directory,
            limit: 1,
            readData: { url in
                readFileNames.append(url.lastPathComponent)
                return try Data(contentsOf: url)
            }
        )

        guard case let .reports(reports) = result else {
            Issue.record("Expected reports, got \(result)")
            return
        }
        #expect(reports.map { $0.fileName } == ["StatsMonitor-2026-05-30-171207.ips"])
        #expect(readFileNames == ["StatsMonitor-2026-05-30-171207.ips"])
    }
}

@Suite("AppSettings Menu Bar Predicate")
@MainActor
struct AppSettingsMenuBarPredicateTests {

    private func makeSettings(allOff: Bool = false) -> AppSettings {
        let defaults = UserDefaults(suiteName: "menu-bar-predicate-\(UUID().uuidString)")!
        let settings = AppSettings(defaults: defaults, launchAtLoginStateProvider: { false }, launchAtLoginHandler: { _ in })
        if allOff {
            settings.showCPU = false
            settings.showGPU = false
            settings.showMemory = false
            settings.showDisk = false
            settings.showNetwork = false
            settings.showBattery = false
            settings.showPower = false
            settings.showThermal = false
            settings.showFans = false
        }
        return settings
    }

    @Test("hint hidden when an always-available item is checked")
    func alwaysAvailableCheckedHidesHint() {
        let settings = makeSettings(allOff: true)
        settings.showCPU = true
        #expect(AppSettings.anyMenuBarItemChecked(settings: settings, hasPower: false, hasThermal: false, hasFans: false))
    }

    @Test("hint shown when every available item is unchecked on full-hardware Mac")
    func allUncheckedShowsHint() {
        let settings = makeSettings(allOff: true)
        #expect(!AppSettings.anyMenuBarItemChecked(settings: settings, hasPower: true, hasThermal: true, hasFans: true))
    }

    @Test("hardware-gated toggle does not suppress hint when hardware absent")
    func hardwareAbsentIgnoresGatedToggles() {
        let settings = makeSettings(allOff: true)
        settings.showFans = true
        settings.showPower = true
        settings.showThermal = true
        #expect(!AppSettings.anyMenuBarItemChecked(settings: settings, hasPower: false, hasThermal: false, hasFans: false))
    }

    @Test("hint hidden when the only checked item is supported hardware")
    func supportedHardwareOnlyCheckedHidesHint() {
        let settings = makeSettings(allOff: true)
        settings.showFans = true
        #expect(AppSettings.anyMenuBarItemChecked(settings: settings, hasPower: false, hasThermal: false, hasFans: true))
    }

    @Test("Power toggle counted via showPowerPanel when battery-only is enabled")
    func powerPanelBatteryOnlyHidesHint() {
        let settings = makeSettings(allOff: true)
        settings.showBattery = true
        settings.showPower = false
        #expect(settings.showPowerPanel)
        #expect(AppSettings.anyMenuBarItemChecked(settings: settings, hasPower: true, hasThermal: false, hasFans: false))
    }
}

@Suite("AppSettings Launch at Login")
@MainActor
struct AppSettingsLaunchAtLoginTests {
    private enum LaunchAtLoginTestError: Error {
        case failed
    }

    @Test("launch at login applies successful changes through the service handler")
    func launchAtLoginAppliesSuccessfulChanges() {
        let defaults = makeTestDefaults()
        var requests: [Bool] = []
        let settings = AppSettings(
            defaults: defaults,
            launchAtLoginStateProvider: { false },
            launchAtLoginHandler: { enabled in requests.append(enabled) }
        )

        settings.launchAtLogin = true

        #expect(settings.launchAtLogin)
        #expect(requests == [true])
    }

    @Test("launch at login rolls back to actual system state when service update fails")
    func launchAtLoginRollsBackWhenHandlerFails() {
        let defaults = makeTestDefaults()
        let settings = AppSettings(
            defaults: defaults,
            launchAtLoginStateProvider: { false },
            launchAtLoginHandler: { _ in throw LaunchAtLoginTestError.failed }
        )

        settings.launchAtLogin = true

        #expect(settings.launchAtLogin == false)
    }
}

@Suite("Settings Window")
struct SettingsWindowTests {

    @Test("settings window uses a stable scene identifier and size contract")
    func stableWindowConfiguration() {
        #expect(AppSceneID.settingsWindow == "settings-window")
        #expect(SettingsWindowLayout.defaultWidth == 820)
        #expect(SettingsWindowLayout.defaultHeight == 600)
        #expect(SettingsWindowLayout.sidebarWidth == 130)
        #expect(SettingsWindowLayout.defaultWidth > SettingsWindowLayout.sidebarWidth)
    }

    @Test("settings window exposes all chart tabs for hardware metrics")
    func settingsWindowTabConfiguration() {
        #expect(MainWindowView.Tab.chartTabs == [.cpuCores, .gpuEngines, .memory, .disk, .network, .power])
        #expect(MainWindowView.Tab.textTabs == [.dashboard, .diagnostics, .general, .about])
        #expect(MainWindowView.Tab.memory.icon == "memorychip.fill")
        #expect(MainWindowView.Tab.disk.icon == "internaldrive")
        #expect(MainWindowView.Tab.network.icon == "network")
        #expect(MainWindowView.Tab.power.icon == "bolt.fill")
        #expect(MainWindowView.Tab.diagnostics.icon == "stethoscope")
        #expect(MainWindowView.Tab.cpuCores.showsGridSizeSlider)
        #expect(MainWindowView.Tab.gpuEngines.showsGridSizeSlider)
        #expect(MainWindowView.Tab.memory.showsGridSizeSlider)
        #expect(MainWindowView.Tab.disk.showsGridSizeSlider)
        #expect(MainWindowView.Tab.network.showsGridSizeSlider)
        #expect(MainWindowView.Tab.power.showsGridSizeSlider)
        #expect(MainWindowView.Tab.dashboard.showsGridSizeSlider)
        #expect(!MainWindowView.Tab.diagnostics.showsGridSizeSlider)
        #expect(!MainWindowView.Tab.general.showsGridSizeSlider)
        #expect(!MainWindowView.Tab.about.showsGridSizeSlider)
    }
}

@Suite("App Resources")
struct AppResourceTests {
    @Test("app icon asset catalog references real files")
    func appIconAssetCatalogReferencesRealFiles() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let projectRoot = testFile
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let iconDirectory = projectRoot.appendingPathComponent(
            "StatsMonitor/Resources/Assets.xcassets/AppIcon.appiconset",
            isDirectory: true
        )
        let data = try Data(contentsOf: iconDirectory.appendingPathComponent("Contents.json"))
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let images = try #require(json["images"] as? [[String: Any]])
        let filenames = images.compactMap { $0["filename"] as? String }

        #expect(!filenames.isEmpty)
        for filename in filenames {
            #expect(FileManager.default.fileExists(atPath: iconDirectory.appendingPathComponent(filename).path))
        }
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

    @Test("invalid persisted numeric settings fall back to safe defaults")
    func invalidPersistedNumericSettingsFallBackToSafeDefaults() {
        let defaults = makeTestDefaults()
        defaults.set(0.0, forKey: "pollInterval")
        defaults.set(1_000_000_000, forKey: "historyCapacity")
        defaults.set(-1, forKey: "processCount")

        let settings = makeTestSettings(defaults: defaults)

        #expect(settings.pollInterval == AppSettings.defaultPollInterval)
        #expect(settings.historyCapacity == AppSettings.defaultHistoryCapacity)
        #expect(settings.processCount == AppSettings.defaultProcessCount)
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

    @Test("chart tabs derive grid item width from the shared dashboard slider")
    func chartTabsUseSharedDashboardSliderValue() {
        #expect(MainWindowMetricGridLayout.minimumCardWidth(for: 3) == 219)
        #expect(MainWindowMetricGridLayout.minimumCardWidth(for: 6) == 120)
        #expect(
            MainWindowMetricGridLayout.minimumCardWidth(for: 3)
                > MainWindowMetricGridLayout.minimumCardWidth(for: 6)
        )
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

    @Test("menu bar items carry power low power mode styling")
    func menuBarItemsCarryPowerLowPowerModeStyling() {
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

        #expect(monitor.menuBarItems(settings: settings) == [
            MenuBarItem(
                panel: .power,
                symbol: "bolt.fill",
                text: "21W",
                color: .systemYellow,
                symbolPaletteColors: [NSColor.systemYellow, NSColor.systemOrange]
            )
        ])
    }

    @Test("menu bar items carry power low battery styling")
    func menuBarItemsCarryPowerLowBatteryStyling() {
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

        #expect(monitor.menuBarItems(settings: settings) == [
            MenuBarItem(
                panel: .power,
                symbol: "bolt.fill",
                text: "21W",
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
        let textColor = attributedTitle.attribute(.foregroundColor, at: 1, effectiveRange: nil) as? NSColor
        #expect(textColor == .systemRed)

        #expect(attributedTitle.attribute(.attachment, at: 0, effectiveRange: nil) == nil)

        let criticalAttachmentIndex = attributedTitle.length - 1
        let criticalAttachment = attributedTitle.attribute(.attachment, at: criticalAttachmentIndex, effectiveRange: nil) as? NSTextAttachment
        #expect(criticalAttachment?.image?.tiffRepresentation != nil)
        let criticalConfigurationDescription = String(describing: criticalAttachment?.image?.symbolConfiguration)
        #expect(criticalConfigurationDescription.contains("prefers multicolor: YES"))

        monitor.record(thermalPressureState: .nominal)
        let nominalTitle = StatusBarLabelRenderer.makeAttributedTitle(monitor: monitor, settings: settings)
        let nominalAttachment = nominalTitle.attribute(.attachment, at: nominalTitle.length - 1, effectiveRange: nil) as? NSTextAttachment
        #expect(criticalAttachment?.image?.tiffRepresentation != nominalAttachment?.image?.tiffRepresentation)
    }

    @Test("status bar hit testing follows rendered segment frames across compact rows")
    func statusBarHitTestingUsesRenderedFrames() throws {
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
        monitor.record(cpu: CPUUsage(user: 98, system: 1, idle: 1, perCore: [], coreFrequencies: []))
        monitor.record(gpu: GPUUsage(deviceUtilization: 42, renderUtilization: 21, engines: [:], vramUsed: 0))
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
        monitor.record(thermal: ThermalUsage(cpuTemperature: 68.4, gpuTemperature: 57.2))
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])

        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        #expect(segments.map(\.panel) == [.cpu, .gpu, .memory, .disk, .network, .power, .thermal, .fans])

        let layout = StatusBarLabelRenderer.layout(for: segments)
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: layout.itemWidth,
            height: MenuBarTextLayout.statusItemHeight
        )

        for panel in [PanelID.cpu, .disk, .network, .fans] {
            let frame = try #require(layout.frame(for: panel, in: bounds))
            let point = CGPoint(x: frame.midX, y: frame.midY)
            #expect(StatusBarLabelRenderer.panel(at: point, in: segments, bounds: bounds) == panel)
        }
    }

    @Test("status bar normalizes flipped button coordinates before resolving compact rows")
    func statusBarNormalizesFlippedButtonCoordinates() throws {
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
        monitor.record(cpu: CPUUsage(user: 32, system: 0, idle: 68, perCore: [], coreFrequencies: []))
        monitor.record(gpu: GPUUsage(deviceUtilization: 9, renderUtilization: 4, engines: [:], vramUsed: 0))
        monitor.record(memory: MemoryUsage(
            active: 8_589_934_592,
            wired: 2_147_483_648,
            compressed: 1_073_741_824,
            total: 17_179_869_184
        ))
        monitor.record(disk: DiskUsage(
            used: 400_000_000_000,
            total: 1_000_000_000_000,
            readBPS: 1_048_576,
            writeBPS: 314_572.8
        ))
        monitor.record(network: NetworkUsage(bytesInPerSec: 2_048, bytesOutPerSec: 0))
        monitor.record(battery: BatteryUsage(
            percentage: 79,
            isCharging: false,
            isPluggedIn: false,
            timeRemaining: 180,
            cycleCount: 132,
            designCapacity: 5000,
            maxCapacity: 4630,
            health: 92.6
        ))
        monitor.record(thermal: ThermalUsage(cpuTemperature: 68.4, gpuTemperature: 57.2))
        monitor.record(power: PowerUsage(
            cpuMilliWatts: 12_400,
            gpuMilliWatts: 4_200,
            totalMilliWatts: 18_000
        ))
        monitor.record(fans: [
            FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
            FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
        ])

        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        let layout = StatusBarLabelRenderer.layout(for: segments)
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: layout.itemWidth,
            height: MenuBarTextLayout.statusItemHeight
        )

        let cpuFrame = try #require(layout.frame(for: .cpu, in: bounds))
        let diskFrame = try #require(layout.frame(for: .disk, in: bounds))

        let flippedCPUPoint = CGPoint(x: cpuFrame.midX, y: bounds.height - cpuFrame.midY)
        let flippedDiskPoint = CGPoint(x: diskFrame.midX, y: bounds.height - diskFrame.midY)

        let normalizedCPUPoint = StatusBarController.normalizeClickPoint(flippedCPUPoint, in: bounds, isFlipped: true)
        let normalizedDiskPoint = StatusBarController.normalizeClickPoint(flippedDiskPoint, in: bounds, isFlipped: true)

        #expect(StatusBarLabelRenderer.panel(at: normalizedCPUPoint, in: segments, bounds: bounds) == .cpu)
        #expect(StatusBarLabelRenderer.panel(at: normalizedDiskPoint, in: segments, bounds: bounds) == .disk)
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

    @Test("status bar switches to a two-row compact layout without dropping visible monitors")
    func statusBarUsesCompactTwoRowLayoutForDenseConfiguration() {
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

        let segments = StatusBarLabelRenderer.makeSegments(monitor: monitor, settings: settings)
        let layout = StatusBarLabelRenderer.layout(for: segments)

        #expect(layout.rowCount == 2)
        #expect(layout.style.textFontSize >= 10)
        #expect(Set(layout.placedSegments.map(\.segment.panel)) == Set(segments.map(\.panel)))
        #expect(layout.placedSegments.allSatisfy { $0.icon != nil && $0.iconFrame.width > 0 })
        let topRowIconCenters = layout.placedSegments.filter { $0.rowIndex == 0 }.map { $0.iconFrame.midY }
        let bottomRowIconCenters = layout.placedSegments.filter { $0.rowIndex == 1 }.map { $0.iconFrame.midY }
        #expect(Set(topRowIconCenters).count == 1)
        #expect(Set(bottomRowIconCenters).count == 1)
        #expect(layout.placedSegments.allSatisfy { $0.iconFrame.width == layout.style.iconSlotSize })
        #expect(layout.itemWidth < StatusBarLabelRenderer.singleRowWidth(for: segments))
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

    @Test("snapshot menu bar button reuses the same production presentation path")
    func snapshotMenuBarButtonUsesProductionPresentationPath() {
        let settings = makeTestSettings()
        settings.showCPU = true
        settings.showGPU = true
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false

        let monitor = SystemMonitor(settings: settings)
        monitor.record(cpu: CPUUsage(user: 32, system: 0, idle: 68, perCore: [], coreFrequencies: []))
        monitor.record(gpu: GPUUsage(deviceUtilization: 9, renderUtilization: 4, engines: [:], vramUsed: 0))

        let state = StatusBarButtonPresentation.state(monitor: monitor, settings: settings)
        let button = StatusBarButtonPresentation.makeStandaloneButton(monitor: monitor, settings: settings)

        #expect(button.frame.width == state.itemLength)
        #expect(button.frame.height == MenuBarTextLayout.statusItemHeight)
        #expect(button.subviews.contains { $0 is StatusBarLabelView })
    }

    @Test("all-off menu bar presentation falls back to a CPU item so the status item stays clickable")
    func allOffMenuBarPresentationFallsBackToCPUItem() {
        let settings = makeTestSettings()
        settings.showCPU = false
        settings.showGPU = false
        settings.showMemory = false
        settings.showDisk = false
        settings.showNetwork = false
        settings.showBattery = false
        settings.showThermal = false
        settings.showPower = false
        settings.showFans = false
        let monitor = SystemMonitor(settings: settings)
        let items = monitor.menuBarItems(settings: settings)
        let state = StatusBarButtonPresentation.state(monitor: monitor, settings: settings)
        let statusItem = NSStatusBar.system.statusItem(withLength: 120)
        defer { NSStatusBar.system.removeStatusItem(statusItem) }
        let button = try! #require(statusItem.button)

        StatusBarButtonPresentation.apply(state, to: statusItem, button: button)

        #expect(items.map(\.panel) == [.cpu])
        #expect(state.itemLength > 0)
        #expect(statusItem.length > 0)
        #expect(StatusBarController.resolvedPanel(
            at: CGPoint(x: 10, y: 10),
            in: items,
            bounds: CGRect(x: 0, y: 0, width: 120, height: MenuBarTextLayout.statusItemHeight)
        ) == .cpu)
        #expect(StatusBarController.resolvedPanel(
            at: CGPoint(x: 10, y: 10),
            in: [],
            bounds: CGRect(x: 0, y: 0, width: 120, height: MenuBarTextLayout.statusItemHeight)
        ) == nil)
    }

    @Test("status bar button handles click on mouse down to avoid popover click-through")
    func statusBarButtonHandlesClickOnMouseDown() {
        let button = NSStatusBarButton(frame: .init(x: 0, y: 0, width: 120, height: 22))

        StatusBarController.configureClickBehavior(for: button)

        #expect(button.sendAction(on: []) == StatusBarController.clickActionMask.rawValue)
    }

    @Test("local dismiss monitor lets status bar clicks reach panel toggle")
    func localDismissMonitorLetsStatusBarClicksReachPanelToggle() {
        let detailPanel = NSPanel()
        let statusWindow = NSWindow(contentRect: .init(x: 0, y: 0, width: 120, height: 22), styleMask: [], backing: .buffered, defer: false)
        let button = NSStatusBarButton(frame: .init(x: 0, y: 0, width: 120, height: 22))
        statusWindow.contentView?.addSubview(button)
        let otherWindow = NSWindow(contentRect: .init(x: 0, y: 0, width: 80, height: 80), styleMask: [], backing: .buffered, defer: false)

        func shouldDismiss(_ window: NSWindow?, eventType: NSEvent.EventType = .leftMouseDown) -> Bool {
            StatusBarController.shouldDismissPanel(
                forEventWindow: window,
                eventType: eventType,
                detailPanel: detailPanel,
                statusButton: button
            )
        }

        #expect(!shouldDismiss(detailPanel))
        #expect(!shouldDismiss(statusWindow))
        #expect(shouldDismiss(statusWindow, eventType: .rightMouseDown))
        #expect(shouldDismiss(otherWindow))
        #expect(shouldDismiss(nil))
    }

    @Test("global dismiss monitor ignores left clicks on the system-hosted status item")
    func globalDismissMonitorIgnoresStatusItemClicks() {
        let statusItemFrame = CGRect(x: 1951, y: 1410, width: 140, height: 30)

        func shouldDismiss(_ point: CGPoint, eventType: NSEvent.EventType = .leftMouseDown, frame: CGRect? = statusItemFrame) -> Bool {
            StatusBarController.shouldDismissPanel(forGlobalClickAt: point, eventType: eventType, statusItemFrame: frame)
        }

        #expect(!shouldDismiss(CGPoint(x: 1984, y: 1437)))
        #expect(shouldDismiss(CGPoint(x: 1984, y: 1437), eventType: .rightMouseDown))
        #expect(shouldDismiss(CGPoint(x: 800, y: 600)))
        #expect(shouldDismiss(CGPoint(x: 1984, y: 1437), frame: nil))
    }

    @Test("status bar panel is borderless, transparent, and floats above other windows")
    func statusBarPanelUsesLiquidGlassChrome() {
        let panel = NSPanel()

        StatusBarController.configureDetailPanel(panel)

        #expect(panel.styleMask.contains(.borderless))
        #expect(panel.styleMask.contains(.nonactivatingPanel))
        #expect(panel.isOpaque == false)
        #expect(panel.backgroundColor == .clear)
        #expect(!panel.hasShadow)
        #expect(panel.isFloatingPanel)
        #expect(panel.level == .statusBar)
        #expect(panel.animationBehavior == .none)
    }
}

@Suite("Quit Confirmation")
@MainActor
struct QuitConfirmationTests {

    @Test("alert factory uses quit-confirmation copy and button ordering")
    func alertFactoryMatchesCopy() {
        let alert = QuitConfirmationAlertFactory.makeAlert()

        #expect(alert.messageText == QuitConfirmationCopy.title())
        #expect(alert.informativeText == QuitConfirmationCopy.message())
        #expect(alert.alertStyle == .warning)
        #expect(alert.buttons.map(\.title) == [QuitConfirmationCopy.confirm(), QuitConfirmationCopy.cancel()])
    }

    @Test("alert copy has Traditional Chinese localization")
    func alertCopyHasTraditionalChineseLocalization() {
        let locale = Locale(identifier: "zh-Hant")

        #expect(QuitConfirmationCopy.title(locale: locale) == "結束 StatsMonitor？")
        #expect(QuitConfirmationCopy.message(locale: locale) == "StatsMonitor 將停止監控並關閉。")
        #expect(QuitConfirmationCopy.confirm(locale: locale) == "結束")
        #expect(QuitConfirmationCopy.cancel(locale: locale) == "取消")
    }

    @Test("alert copy can be pinned to English regardless of current locale")
    func alertCopyCanBePinnedToEnglish() {
        let locale = Locale(identifier: "en")

        #expect(QuitConfirmationCopy.title(locale: locale) == "Quit StatsMonitor?")
        #expect(QuitConfirmationCopy.message(locale: locale) == "StatsMonitor will stop monitoring and close.")
        #expect(QuitConfirmationCopy.confirm(locale: locale) == "Quit")
        #expect(QuitConfirmationCopy.cancel(locale: locale) == "Cancel")
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
        var monitor = MemoryMonitor()
        #expect(monitor.sample().total > 0)
    }

    @Test("sample() usedFraction is in 0...1")
    func usedFractionInRange() {
        var monitor = MemoryMonitor()
        let result = monitor.sample()
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

@Suite("SystemLoadMonitor")
struct SystemLoadMonitorTests {

    @Test("readProcessCount returns a positive value on the host")
    func processCountIsPositive() {
        #expect(SystemLoadMonitor.readProcessCount() > 0)
    }

    @Test("readLoadAverage returns non-negative values")
    func loadAverageNonNegative() {
        let load = SystemLoadMonitor.readLoadAverage()
        #expect(load.one >= 0)
        #expect(load.five >= 0)
        #expect(load.fifteen >= 0)
    }

}

@Suite("DisplayInfo")
struct DisplayInfoTests {

    @Test("renders text with resolution and refresh rate")
    func rendersFullText() {
        let info = DisplayInfo(widthPixels: 3456, heightPixels: 2234, refreshRateHz: 120)
        #expect(info.text == "3456 × 2234 @ 120 Hz")
    }

    @Test("rounds refresh rate to nearest integer")
    func roundsRefreshRate() {
        let info = DisplayInfo(widthPixels: 2560, heightPixels: 1440, refreshRateHz: 59.94)
        #expect(info.text == "2560 × 1440 @ 60 Hz")
    }

    @Test("omits refresh section when rate is zero (variable or unknown)")
    func omitsRefreshWhenZero() {
        let info = DisplayInfo(widthPixels: 3024, heightPixels: 1964, refreshRateHz: 0)
        #expect(info.text == "3024 × 1964")
    }

    @Test("returns dash when dimensions are zero")
    func dashWhenZero() {
        #expect(DisplayInfo.zero.text == "—")
    }

    @Test("live monitor reports positive width and height on attached display")
    func liveMonitorProducesRealDisplay() {
        let info = DisplayInfoMonitor().sample()
        #expect(info.widthPixels > 0)
        #expect(info.heightPixels > 0)
    }
}

@Suite("BatteryMonitor Electrical")
struct BatteryMonitorElectricalTests {

    @Test("reads voltage and signed amperage while charging")
    func readsWhileCharging() {
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 3000,
            "MaxCapacity": 5000,
            "DesignCapacity": 5200,
            "IsCharging": true,
            "ExternalConnected": true,
            "CycleCount": 42,
            "Voltage": 12_340,
            "InstantAmperage": 1_230,
            "Temperature": 3_015,
        ])

        #expect(usage?.voltageMilliVolts == 12_340)
        #expect(usage?.amperageMilliAmps == 1_230)
        #expect(usage?.temperatureCelsius != nil)
        #expect(((usage?.temperatureCelsius ?? 0) - 30.15).magnitude < 0.001)
    }

    @Test("signs amperage negative while discharging")
    func signsDischargeNegative() {
        let raw = BatteryMonitor.signedAmperage(800, isCharging: false)
        #expect(raw == -800)
    }

    @Test("keeps amperage zero when battery idle")
    func idleAmperageStaysZero() {
        #expect(BatteryMonitor.signedAmperage(0, isCharging: false) == 0)
        #expect(BatteryMonitor.signedAmperage(0, isCharging: true) == 0)
    }

    @Test("falls back to steady Amperage when instant reading missing")
    func fallsBackToSteadyAmperage() {
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 3_000,
            "MaxCapacity": 5_000,
            "DesignCapacity": 5_200,
            "IsCharging": false,
            "ExternalConnected": false,
            "CycleCount": 42,
            "Amperage": -950,
        ])
        // Raw already negative; should pass through unchanged.
        #expect(usage?.amperageMilliAmps == -950)
    }

    @Test("omits temperature when sensor missing")
    func omitsMissingTemperature() {
        let usage = BatteryMonitor.parseUsage(from: [
            "CurrentCapacity": 3_000,
            "MaxCapacity": 5_000,
            "DesignCapacity": 5_200,
            "IsCharging": false,
            "ExternalConnected": false,
            "CycleCount": 42,
        ])
        #expect(usage?.temperatureCelsius == nil)
    }
}

@Suite("MemoryMonitor Paging")
struct MemoryMonitorPagingTests {

    @Test("computes page-in rate as bytes per second between two counters")
    func computesRate() {
        let pageSize: UInt64 = 16_384
        // 100 pages over 2 seconds -> 100 * 16384 / 2 = 819_200 B/s
        let rate = MemoryMonitor.rate(current: 1_100, previous: 1_000, elapsed: 2, pageSize: pageSize)
        #expect(rate == 819_200)
    }

    @Test("returns zero when counter goes backwards (guards against overflow)")
    func guardsAgainstCounterReset() {
        let rate = MemoryMonitor.rate(current: 50, previous: 100, elapsed: 1, pageSize: 16_384)
        #expect(rate == 0)
    }

    @Test("returns zero when elapsed is zero")
    func returnsZeroWhenElapsedZero() {
        let rate = MemoryMonitor.rate(current: 200, previous: 100, elapsed: 0, pageSize: 16_384)
        #expect(rate == 0)
    }

    @Test("first sample() produces zero paging rates (no previous state)")
    func firstSampleHasZeroPagingRates() {
        var monitor = MemoryMonitor()
        let usage = monitor.sample()
        #expect(usage.pageInsPerSec == 0)
        #expect(usage.pageOutsPerSec == 0)
    }
}

@Suite("WiFiMonitor")
struct WiFiMonitorTests {

    @Test("maps 2.4 GHz band enum to label")
    func maps2GhzLabel() {
        #expect(WiFiMonitor.bandLabel(for: .band2GHz) == "2.4 GHz")
    }

    @Test("maps 5 GHz band enum to label")
    func maps5GhzLabel() {
        #expect(WiFiMonitor.bandLabel(for: .band5GHz) == "5 GHz")
    }

    @Test("maps 6 GHz band enum to label")
    func maps6GhzLabel() {
        #expect(WiFiMonitor.bandLabel(for: .band6GHz) == "6 GHz")
    }

    @Test("unknown band has no label")
    func unknownBand() {
        #expect(WiFiMonitor.bandLabel(for: .bandUnknown) == nil)
    }
}

@Suite("NetworkMonitor Connections")
struct NetworkMonitorConnectionTests {

    @Test("parseConnectionCount ignores netstat header lines")
    func ignoresHeaderLines() {
        let sample = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        tcp4       0      0  192.168.1.10.52341     17.57.146.10.443       ESTABLISHED
        tcp4       0      0  192.168.1.10.52342     17.57.146.11.443       ESTABLISHED
        tcp6       0      0  fe80::1.123            *.*                    LISTEN
        """
        #expect(NetworkMonitor.parseConnectionCount(output: sample) == 3)
    }

    @Test("parseConnectionCount returns zero for empty output")
    func emptyOutputZero() {
        #expect(NetworkMonitor.parseConnectionCount(output: "") == 0)
    }

    @Test("parseConnectionCount returns zero for header-only output")
    func headerOnlyZero() {
        let sample = """
        Active Internet connections (including servers)
        Proto Recv-Q Send-Q  Local Address          Foreign Address        (state)
        """
        #expect(NetworkMonitor.parseConnectionCount(output: sample) == 0)
    }
}

@Suite("SystemMonitor Presentation Additions")
@MainActor
struct SystemMonitorPresentationAdditionsTests {

    @Test("lowPowerModeText reflects scalar state")
    func formatsLowPowerMode() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(isLowPowerModeEnabled: false)
        #expect(monitor.lowPowerModeText == "Off")
        monitor.record(isLowPowerModeEnabled: true)
        #expect(monitor.lowPowerModeText == "On")
    }

    @Test("battery voltage text formats to two decimals in volts")
    func formatsBatteryVoltage() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(battery: BatteryUsage(
            percentage: 75, isCharging: true, isPluggedIn: true,
            timeRemaining: 60, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4700, health: 94,
            voltageMilliVolts: 12_340, amperageMilliAmps: 1_250, temperatureCelsius: 30.5
        ))
        #expect(monitor.batteryVoltageText == "12.34 V")
        #expect(monitor.batteryCurrentText == "+1.25 A")
        #expect(monitor.batteryTemperatureText == "30.5 °C")
    }

    @Test("wifi signal text reports dBm or empty when absent")
    func formatsWiFiSignal() {
        let monitor = SystemMonitor(settings: AppSettings())
        var sample = NetworkUsage.zero
        sample.wifi = WiFiLinkInfo(
            rssiDBm: -58, noiseDBm: -92, linkRateMbps: 1_200,
            channelNumber: 149, band: "5 GHz", hardwareAddress: "aa:bb"
        )
        monitor.record(network: sample)
        #expect(monitor.wifiSignalText == "-58 dBm")
        #expect(monitor.wifiLinkRateText == "1.20 Gbps")
        #expect(monitor.wifiChannelText == "Channel 149 (5 GHz)")
    }

    @Test("tcp/udp count texts reflect NetworkUsage state")
    func formatsConnectionCounts() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(network: NetworkUsage(
            bytesInPerSec: 0, bytesOutPerSec: 0,
            tcpConnectionCount: 42, udpConnectionCount: 7
        ))
        #expect(monitor.tcpConnectionCountText == "42")
        #expect(monitor.udpConnectionCountText == "7")
        #expect(monitor.hasConnectionCounts)
    }

    @Test("displayInfoText reflects scalar state")
    func formatsDisplayInfo() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(displayInfo: DisplayInfo(widthPixels: 3456, heightPixels: 2234, refreshRateHz: 120))
        #expect(monitor.displayInfoText == "3456 × 2234 @ 120 Hz")
        #expect(monitor.hasDisplayInfo)
    }
}

@Suite("SystemMonitor Power Telemetry")
@MainActor
struct SystemMonitorPowerTelemetryTests {
    private func makeMonitor() -> SystemMonitor {
        SystemMonitor(settings: makeTestSettings())
    }

    private func samplePower() -> PowerUsage {
        PowerUsage(
            cpuMilliWatts: 12_000,
            gpuMilliWatts: 4_000,
            totalMilliWatts: 18_000
        )
    }

    @Test("hasPowerTelemetry stays false until a non-nil power sample is recorded")
    func hasPowerTelemetryFalseBeforeFirstSample() {
        let monitor = makeMonitor()
        #expect(!monitor.hasPowerTelemetry)

        monitor.record(power: nil)
        #expect(!monitor.hasPowerTelemetry)
    }

    @Test("hasPowerTelemetry latches true after first non-nil power sample")
    func hasPowerTelemetryLatchesTrueOnFirstSample() {
        let monitor = makeMonitor()
        monitor.record(power: samplePower())
        #expect(monitor.hasPowerTelemetry)
    }

    @Test("hasPowerTelemetry stays true after a later nil power sample")
    func hasPowerTelemetryStaysTrueAfterLaterNilSample() {
        let monitor = makeMonitor()
        monitor.record(power: samplePower())
        monitor.record(power: nil)
        #expect(monitor.hasPowerTelemetry)
    }

    @Test("hasPowerTelemetry stays true after resetHistories recreates buffers")
    func hasPowerTelemetryStaysTrueAfterResetHistories() {
        let settings = makeTestSettings()
        settings.historyCapacity = 60
        let monitor = SystemMonitor(settings: settings)
        monitor.record(power: samplePower())

        settings.historyCapacity = 300
        monitor.resetHistories()

        #expect(monitor.hasPowerTelemetry)
        #expect(monitor.powerSamples.capacity == 300)
    }
}

@Suite("AppDelegate system-initiated quit detection")
@MainActor
struct AppDelegateSystemInitiatedQuitTests {
    private func makeQuitEvent(reason: OSType?) -> NSAppleEventDescriptor {
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEQuitApplication),
            targetDescriptor: nil,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        if let reason {
            event.setParam(NSAppleEventDescriptor(enumCode: reason), forKeyword: AEKeyword(kAEQuitReason))
        }
        return event
    }

    @Test("nil event is not a system-initiated quit")
    func nilEventIsNotSystemInitiated() {
        #expect(!AppDelegate.isSystemInitiatedQuit(nil))
    }

    @Test("quit event without a reason is not system-initiated")
    func missingReasonIsNotSystemInitiated() {
        #expect(!AppDelegate.isSystemInitiatedQuit(makeQuitEvent(reason: nil)))
    }

    @Test("quit event with an unknown reason is not system-initiated")
    func unknownReasonIsNotSystemInitiated() {
        // Not one of kAEQuitAll/kAELogOut/kAEReallyLogOut/kAEShowRestartDialog/kAERestart/kAEShowShutdownDialog/kAEShutDown.
        let unknownReason = OSType(999)
        #expect(!AppDelegate.isSystemInitiatedQuit(makeQuitEvent(reason: unknownReason)))
    }

    @Test("logout/restart/shutdown reasons are system-initiated", arguments: [
        OSType(kAEReallyLogOut),
        OSType(kAEShutDown),
        OSType(kAERestart),
    ])
    func systemReasonsAreSystemInitiated(reason: OSType) {
        #expect(AppDelegate.isSystemInitiatedQuit(makeQuitEvent(reason: reason)))
    }
}

// MARK: - Network Chart Palette (#4)

@Suite("Network Chart Palette")
@MainActor
struct NetworkChartPaletteTests {

    @Test("網路上下行配色為單一來源常數，沿用 Dashboard 藍（in）／綠（out）")
    func paletteIsSingleSource() {
        #expect(NetworkChartPalette.inbound == Color.blue)
        #expect(NetworkChartPalette.outbound == Color.green)
        #expect(NetworkChartPalette.inbound != NetworkChartPalette.outbound)
    }

    @Test("共用 networkChartLines 依序回傳 in／out 兩線並取用同一組常數")
    func sharedNetworkChartLinesUsePalette() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(network: NetworkUsage(
            bytesInPerSec: 2_048, bytesOutPerSec: 1_024,
            tcpConnectionCount: 0, udpConnectionCount: 0
        ))

        let lines = networkChartLines(monitor: monitor)

        #expect(lines.count == 2)
        #expect(lines.map(\.color) == [NetworkChartPalette.inbound, NetworkChartPalette.outbound])
        #expect(lines[0].history == monitor.paddedNetworkInHistory)
        #expect(lines[1].history == monitor.paddedNetworkOutHistory)
    }

    @Test("單向卡片的線色同樣來自共用常數")
    func singleDirectionLinesUsePalette() {
        let monitor = SystemMonitor(settings: AppSettings())
        monitor.record(network: NetworkUsage(
            bytesInPerSec: 2_048, bytesOutPerSec: 1_024,
            tcpConnectionCount: 0, udpConnectionCount: 0
        ))

        #expect(networkInChartLine(monitor: monitor).color == NetworkChartPalette.inbound)
        #expect(networkOutChartLine(monitor: monitor).color == NetworkChartPalette.outbound)
    }
}

// MARK: - Dashboard Visual Refresh (#1)

@Suite("Dashboard Visual Refresh")
@MainActor
struct DashboardVisualRefreshTests {

    @Test("Dashboard 預設欄數為 3")
    func defaultDashboardColumnsIsThree() {
        #expect(DashboardGridSizing.defaultColumnCount == 3)
        #expect(AppSettings.defaultDashboardColumns == 3)
        #expect(AppSettings.dashboardColumnRange == 3...6)
    }

    @Test("metric 卡片高度：chart 區縮到原本七成（72→~51pt），legend 卡補回 legend 高度，無 chart 維持 72")
    func metricCardHeightIsCompact() {
        let line = ChartSeries(history: [0.5], color: .blue)
        #expect(dashboardCardHeight(lines: [line], hasLegend: false) == 112)
        #expect(dashboardCardHeight(lines: [line], hasLegend: true) == 128)
        #expect(dashboardCardHeight(lines: [], hasLegend: false) == 72)
    }

    @Test("使用率門檻分級，含 0.6／0.8 邊界")
    func metricStatusFractionThresholds() {
        #expect(MetricStatus(fraction: 0.1) == .normal)
        #expect(MetricStatus(fraction: 0.599) == .normal)
        #expect(MetricStatus(fraction: 0.6) == .elevated)
        #expect(MetricStatus(fraction: 0.799) == .elevated)
        #expect(MetricStatus(fraction: 0.8) == .high)
        #expect(MetricStatus(fraction: 0.95) == .high)
    }

    @Test("功耗門檻分級，含 10 W／30 W 邊界")
    func metricStatusWattThresholds() {
        #expect(MetricStatus(watts: 5) == .normal)
        #expect(MetricStatus(watts: 10) == .elevated)
        #expect(MetricStatus(watts: 20) == .elevated)
        #expect(MetricStatus(watts: 30) == .high)
        #expect(MetricStatus(watts: 50) == .high)
    }

    @Test("狀態 capsule 文案與配色對映三級")
    func metricStatusCaptionAndColor() {
        #expect(MetricStatus.normal.caption == LocalizedStringKey("Normal"))
        #expect(MetricStatus.elevated.caption == LocalizedStringKey("Elevated"))
        #expect(MetricStatus.high.caption == LocalizedStringKey("High"))
        #expect(MetricStatus.normal.color == .green)
        #expect(MetricStatus.elevated.color == .orange)
        #expect(MetricStatus.high.color == .red)
    }

    @Test("progressColor 與 MetricStatus 共用同一組門檻")
    func progressColorDelegatesToMetricStatus() {
        for fraction in [0.0, 0.3, 0.599, 0.6, 0.75, 0.8, 1.2] {
            #expect(progressColor(fraction) == MetricStatus(fraction: fraction).color)
        }
    }

    @Test("未指定狀態的卡片不顯示 capsule（裝飾色卡片一律走這條）")
    func metricChartCardHasNoStatusByDefault() {
        let card = MetricChartCard(
            title: "Read",
            value: "1.0 MB/s",
            lines: [ChartSeries(history: [1, 2, 3], color: .teal)],
            maxValue: 3
        )
        #expect(card.status == nil)
    }

    @Test("狀態 capsule 新 key 在 xcstrings 皆有 zh-Hant 譯文")
    func statusCaptionKeysHaveTraditionalChinese() throws {
        let catalog = try loadLocalizableStringCatalog()
        let expected = [
            "Normal": "正常",
            "Elevated": "偏高",
            "High": "過高",
        ]

        for (key, translation) in expected {
            let unit = try #require(
                catalog[key]?["localizations"]
                    .flatMap { $0 as? [String: Any] }?["zh-Hant"]
                    .flatMap { $0 as? [String: Any] }?["stringUnit"]
                    .flatMap { $0 as? [String: Any] },
                "缺少 \(key) 的 zh-Hant 譯文"
            )
            #expect(unit["state"] as? String == "translated")
            #expect(unit["value"] as? String == translation)
        }
    }
}

/// 直接讀取專案的 String Catalog，才驗得到 `state: translated` 這個檔案層事實。
private func loadLocalizableStringCatalog(file: StaticString = #filePath) throws -> [String: [String: Any]] {
    let testsFile = URL(fileURLWithPath: "\(file)")
    let repoRoot = testsFile
        .deletingLastPathComponent()   // Tests/Sources
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
    let catalogURL = repoRoot
        .appendingPathComponent("StatsMonitor/Resources/Localizable.xcstrings")
    let data = try Data(contentsOf: catalogURL)
    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    return try #require(json?["strings"] as? [String: [String: Any]], "無法解析 Localizable.xcstrings")
}

// MARK: - #2 熱門行程表空值 formatter

@Suite("Top Processes Value Formatting")
@MainActor
struct TopProcessesValueFormattingTests {

    private func makeMonitor() -> SystemMonitor {
        SystemMonitor(settings: makeTestSettings())
    }

    @Test("CPU 欄：nil 顯示破折號、0 與正值顯示數值")
    func formatsProcessCPUEmptyState() {
        let monitor = makeMonitor()
        #expect(monitor.formatProcessCPU(nil as Double?) == "—")
        #expect(monitor.formatProcessCPU(0 as Double?) == "0.0%")
        #expect(monitor.formatProcessCPU(48.2 as Double?) == "48.2%")
    }

    @Test("GPU 欄：nil 顯示破折號、0 與正值顯示數值")
    func formatsProcessGPUEmptyState() {
        let monitor = makeMonitor()
        #expect(monitor.formatProcessGPU(nil as Double?) == "—")
        #expect(monitor.formatProcessGPU(0 as Double?) == "0.0%")
        #expect(monitor.formatProcessGPU(23.5 as Double?) == "23.5%")
    }

    @Test("記憶體欄：nil 顯示破折號、0 顯示 0 B")
    func formatsProcessMemoryEmptyState() {
        let monitor = makeMonitor()
        #expect(monitor.formatProcessMemory(nil as UInt64?) == "—")
        #expect(monitor.formatProcessMemory(0 as UInt64?) == "0 B")
        #expect(monitor.formatProcessMemory(1_073_741_824 as UInt64?) == "1.0 GB")
    }

    @Test("磁碟欄：nil 顯示破折號、0 顯示 0 KB/s")
    func formatsProcessDiskEmptyState() {
        let monitor = makeMonitor()
        #expect(monitor.formatProcessDisk(nil as Double?) == "—")
        #expect(monitor.formatProcessDisk(0 as Double?) == "0 KB/s")
        #expect(monitor.formatProcessDisk(1_048_576 as Double?) == "1.0 MB/s")
    }

    @Test("網路欄：nil 顯示破折號、0 顯示 0 KB/s")
    func formatsProcessNetworkEmptyState() {
        let monitor = makeMonitor()
        #expect(monitor.formatProcessNetwork(nil as Double?) == "—")
        #expect(monitor.formatProcessNetwork(0 as Double?) == "0 KB/s")
        #expect(monitor.formatProcessNetwork(262_144 as Double?) == "256 KB/s")
    }
}

// MARK: - #3 ProcInfo 帶 pid 與名稱解析

@Suite("Top Processes Merge By PID")
@MainActor
struct TopProcessesMergeTests {

    @Test("同名不同 pid 不合併")
    func keepsSameNameDifferentPIDSeparate() {
        let merged = SystemMonitor.mergeTopProcesses(
            cpu: [
                ProcInfo(pid: 101, name: "Google Chrome Helper", cpuPercent: 12, memoryBytes: 100),
                ProcInfo(pid: 102, name: "Google Chrome Helper", cpuPercent: 4, memoryBytes: 200),
            ],
            memory: [],
            disk: [],
            network: [],
            gpu: []
        )
        #expect(merged.count == 2)
        #expect(Set(merged.map(\.pid)) == [101, 102])
    }

    @Test("同 pid 跨清單合併並取各欄最大值")
    func mergesSamePIDAcrossLists() {
        let merged = SystemMonitor.mergeTopProcesses(
            cpu: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2, memoryBytes: 100)],
            memory: [ProcInfo(pid: 601, name: "WindowServer", memoryBytes: 734_000_000)],
            disk: [ProcInfo(pid: 601, name: "WindowServer", memoryBytes: 0, diskReadBPS: 4_194_304)],
            network: [ProcInfo(pid: 601, name: "WindowServer", memoryBytes: 0, networkInBPS: 262_144)],
            gpu: [ProcInfo(pid: 601, name: "WindowServer", gpuPercent: 23.5)]
        )
        #expect(merged.count == 1)
        guard let proc = merged.first else { return }
        #expect(proc.pid == 601)
        #expect(proc.cpuPercent == 16.2)
        #expect(proc.memoryBytes == 734_000_000)
        #expect(proc.diskReadBPS == 4_194_304)
        #expect(proc.networkInBPS == 262_144)
        #expect(proc.gpuPercent == 23.5)
    }

    @Test("只出現在非 CPU 清單的行程，CPU 欄維持無資料而非 0")
    func keepsCPUNilForProcessMissingFromCPUList() {
        let merged = SystemMonitor.mergeTopProcesses(
            cpu: [],
            memory: [],
            disk: [],
            network: [ProcInfo(pid: 777, name: "netdaemon", networkInBPS: 262_144)],
            gpu: [ProcInfo(pid: 888, name: "WindowServer", gpuPercent: 12.5)]
        )
        #expect(merged.count == 2)
        #expect(merged.allSatisfy { $0.cpuPercent == nil })

        let monitor = SystemMonitor(settings: makeTestSettings())
        #expect(monitor.formatProcessCPU(merged[0].cpuPercent) == "—")
    }
}

// MARK: - 高耗能行程表的 CPU% 欄：以 pid 併 CPU list

/// `PowerMonitor` 產出的列本來就沒有 CPU%，CPU% 欄要靠 pid 對上 CPU top list 才有值。
/// 與 `mergeTopProcesses` 的規則不同：這裡 power list 是主，CPU list 只借出 `cpuPercent` 一欄，
/// 不取最大值、不補列、不改名，所以另立契約而非重用 `ProcInfo.merged(with:)`。
@Suite("Power Processes CPU Merge")
@MainActor
struct PowerProcessesCPUMergeTests {

    @Test("同 pid：CPU% 取 CPU list 的值")
    func takesCPUPercentFromCPUListForMatchingPID() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [ProcInfo(pid: 601, name: "WindowServer", memoryBytes: 734_000_000, powerImpact: 45.1)],
            cpu: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2, memoryBytes: 734_000_000)]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.cpuPercent == 16.2)
    }

    @Test("同 pid：CPU list 的值較小也照用，不取兩邊最大值")
    func overwritesStalePowerRowCPUPercentWithSmallerCPUListValue() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 99.9, memoryBytes: 734_000_000, powerImpact: 45.1)],
            cpu: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2, memoryBytes: 734_000_000)]
        )
        #expect(merged.first?.cpuPercent == 16.2)
    }

    @Test("pid 不在 CPU list：CPU% 為無資料，power 列身上的舊值不留")
    func clearsCPUPercentForPIDMissingFromCPUList() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [ProcInfo(pid: 2002, name: "backupd", cpuPercent: 5.5, memoryBytes: 62_000_000, powerImpact: 9.4)],
            cpu: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2, memoryBytes: 734_000_000)]
        )
        #expect(merged.count == 1)
        #expect(merged.first?.cpuPercent == nil)

        let monitor = SystemMonitor(settings: makeTestSettings())
        #expect(monitor.formatProcessCPU(merged.first?.cpuPercent) == "—")
    }

    @Test("CPU list 為空：所有列的 CPU% 都是無資料")
    func clearsCPUPercentWhenCPUListIsEmpty() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [
                ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2, powerImpact: 45.1),
                ProcInfo(pid: 1001, name: "Xcode", cpuPercent: 48.2, powerImpact: 14.1),
            ],
            cpu: []
        )
        #expect(merged.count == 2)
        #expect(merged.allSatisfy { $0.cpuPercent == nil })
    }

    @Test("以 pid 對應而非名稱：同名不同 pid 不借值")
    func matchesByPIDNotByName() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [ProcInfo(pid: 101, name: "Google Chrome Helper", powerImpact: 21.0)],
            cpu: [ProcInfo(pid: 102, name: "Google Chrome Helper", cpuPercent: 33.3)]
        )
        #expect(merged.first?.cpuPercent == nil)
    }

    @Test("除 CPU% 外各欄維持 power 列的值")
    func keepsPowerRowValuesForEveryOtherColumn() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [
                ProcInfo(
                    pid: 1001,
                    name: "Xcode",
                    memoryBytes: 1_824_000_000,
                    powerImpact: 14.1,
                    iconPath: "/Applications/Xcode.app"
                )
            ],
            // CPU list 同 pid 但名稱更長、記憶體更大、powerImpact 更高、無 icon 路徑：
            // 取最大值或取較長名稱的實作都會在這裡露餡。
            cpu: [
                ProcInfo(
                    pid: 1001,
                    name: "Xcode Beta Build Service",
                    cpuPercent: 48.2,
                    memoryBytes: 9_000_000_000,
                    powerImpact: 99.9
                )
            ]
        )
        #expect(merged.count == 1)
        guard let proc = merged.first else { return }
        #expect(proc.pid == 1001)
        #expect(proc.name == "Xcode")
        #expect(proc.memoryBytes == 1_824_000_000)
        #expect(proc.powerImpact == 14.1)
        #expect(proc.iconPath == "/Applications/Xcode.app")
        #expect(proc.cpuPercent == 48.2)
    }

    @Test("順序與列數比照 power list：不重排、不補進只在 CPU list 的行程")
    func preservesPowerListOrderAndDoesNotAppendCPUOnlyProcesses() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [
                ProcInfo(pid: 601, name: "WindowServer", powerImpact: 45.1),
                ProcInfo(pid: 2002, name: "backupd", powerImpact: 9.4),
                ProcInfo(pid: 1001, name: "Xcode", powerImpact: 14.1),
            ],
            cpu: [
                ProcInfo(pid: 1001, name: "Xcode", cpuPercent: 48.2),
                ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2),
                ProcInfo(pid: 1002, name: "StatsMonitor", cpuPercent: 8.3),
            ]
        )
        #expect(merged.map(\.pid) == [601, 2002, 1001])
        #expect(merged.map(\.cpuPercent) == [16.2, nil, 48.2])
    }

    @Test("power list 為空：結果為空")
    func returnsEmptyForEmptyPowerList() {
        let merged = SystemMonitor.mergePowerProcesses(
            power: [],
            cpu: [ProcInfo(pid: 601, name: "WindowServer", cpuPercent: 16.2)]
        )
        #expect(merged.isEmpty)
    }
}

@Suite("Process Name Resolution")
struct ProcessNameResolverTests {

    @Test("能定位 bundle 時顯示 bundle display name")
    func prefersBundleDisplayName() {
        #expect(ProcessNameResolver.displayName(
            bundleDisplayName: "Google Chrome",
            executableFileName: "Google Chrome Helper",
            commName: "Google Chrome He"
        ) == "Google Chrome")
    }

    @Test("無 bundle 時 fallback 執行檔檔名")
    func fallsBackToExecutableFileName() {
        #expect(ProcessNameResolver.displayName(
            bundleDisplayName: nil,
            executableFileName: "com.apple.WebKit.WebContent",
            commName: "com.apple.WebKi"
        ) == "com.apple.WebKit.WebContent")
    }

    @Test("bundle 與執行檔路徑都取不到才 fallback p_comm")
    func fallsBackToCommName() {
        #expect(ProcessNameResolver.displayName(
            bundleDisplayName: nil,
            executableFileName: nil,
            commName: "2.1.241"
        ) == "2.1.241")
    }

    @Test("執行檔路徑往上找到最近的 .app bundle")
    func findsNearestAppBundleAncestor() {
        let path = "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app/Contents/MacOS/Google Chrome Helper"
        #expect(ProcessNameResolver.appBundlePath(forExecutablePath: path)
            == "/Applications/Google Chrome.app/Contents/Frameworks/Google Chrome Framework.framework/Helpers/Google Chrome Helper.app")
    }

    @Test("非 app 執行檔沒有 bundle 路徑")
    func returnsNilForNonAppExecutable() {
        #expect(ProcessNameResolver.appBundlePath(forExecutablePath: "/usr/bin/zsh") == nil)
    }
}

// MARK: - #4 行程表右鍵結束 process

/// `kill(2)` 替身：記錄實際收到的 (pid, signal)，並在回傳 -1 時把 `errno` 設成指定值，
/// 逼 `ProcessTerminator` 走真實的 errno 判讀路徑（而不是靠回傳值猜錯誤種類）。
private final class KillSpy {
    private(set) var calls: [(pid: Int32, signal: Int32)] = []
    private let result: Int32
    private let errorNumber: Int32

    init(result: Int32, errorNumber: Int32 = 0) {
        self.result = result
        self.errorNumber = errorNumber
    }

    func kill(_ pid: Int32, _ signal: Int32) -> Int32 {
        calls.append((pid: pid, signal: signal))
        if result == -1 { errno = errorNumber }
        return result
    }
}

private func strerrorText(_ code: Int32) -> String {
    String(cString: strerror(code))
}

/// 讀專案原始碼本文，才驗得到「兩張表共用同一實作」這種檔案層事實。
private func loadProjectSource(_ relativePath: String, file: StaticString = #filePath) throws -> String {
    let repoRoot = URL(fileURLWithPath: "\(file)")
        .deletingLastPathComponent()   // Tests/Sources
        .deletingLastPathComponent()   // Tests
        .deletingLastPathComponent()   // repo root
    return try String(contentsOf: repoRoot.appendingPathComponent(relativePath), encoding: .utf8)
}

@Suite("Process Termination")
struct ProcessTerminationTests {

    /// 回傳 terminate 丟出的錯誤；沒丟錯回 nil，讓「該丟沒丟」也算失敗。
    private func captureError(_ body: () throws -> Void) -> ProcessTerminationError? {
        do {
            try body()
            return nil
        } catch let error as ProcessTerminationError {
            return error
        } catch {
            Issue.record("預期 ProcessTerminationError，實得 \(error)")
            return nil
        }
    }

    // MARK: signal 對映

    @Test("signal 對映 SIGTERM / SIGKILL")
    func signalNumbersMatchPOSIX() {
        #expect(ProcessTerminationSignal.terminate.signalNumber == SIGTERM)
        #expect(ProcessTerminationSignal.forceKill.signalNumber == SIGKILL)
        // 兩個常數互換仍會通過上面兩行，所以連原始數值一起釘死。
        #expect(ProcessTerminationSignal.terminate.signalNumber == 15)
        #expect(ProcessTerminationSignal.forceKill.signalNumber == 9)
    }

    // MARK: 無效 pid

    @Test("pid 0 直接拒絕且完全不呼叫 kill（kill(0, SIGKILL) 會殺掉整個 process group）")
    func rejectsZeroPIDWithoutCallingKill() {
        let spy = KillSpy(result: 0)

        let error = captureError {
            try ProcessTerminator.terminate(pid: 0, signal: .forceKill, kill: spy.kill)
        }

        #expect(error == .invalidPID(0))
        #expect(spy.calls.isEmpty)
    }

    @Test("負 pid 直接拒絕且不呼叫 kill（kill(-1, …) 會掃掉整個使用者的行程）")
    func rejectsNegativePIDWithoutCallingKill() {
        let spy = KillSpy(result: 0)

        let error = captureError {
            try ProcessTerminator.terminate(pid: -1, signal: .terminate, kill: spy.kill)
        }

        #expect(error == .invalidPID(-1))
        #expect(spy.calls.isEmpty)
    }

    @Test("超出 pid_t 範圍的 pid 直接拒絕，不做會 trap 的 Int32 轉型")
    func rejectsOutOfRangePID() {
        let spy = KillSpy(result: 0)
        let outOfRange = Int(Int32.max) + 1

        let error = captureError {
            try ProcessTerminator.terminate(pid: outOfRange, signal: .terminate, kill: spy.kill)
        }

        #expect(error == .invalidPID(outOfRange))
        #expect(spy.calls.isEmpty)
    }

    @Test("canTerminate 判斷選單項是否可點：只有落在 pid_t 正數範圍內才可結束")
    func canTerminateMatchesPIDValidity() {
        #expect(ProcessTerminator.canTerminate(pid: 0) == false)
        #expect(ProcessTerminator.canTerminate(pid: -1) == false)
        #expect(ProcessTerminator.canTerminate(pid: Int(Int32.max) + 1) == false)
        // currentPID 明確指定，避免測試 runner 自己的 pid 恰好撞上底下的正數樣本。
        #expect(ProcessTerminator.canTerminate(pid: 1, currentPID: 99999) == true)
        #expect(ProcessTerminator.canTerminate(pid: 4321, currentPID: 99999) == true)
        #expect(ProcessTerminator.canTerminate(pid: Int(Int32.max), currentPID: 99999) == true)
    }

    @Test("canTerminate 排除自己：選單不能提供結束 StatsMonitor 本身的入口")
    func canTerminateExcludesOwnPID() {
        #expect(ProcessTerminator.canTerminate(pid: 4321, currentPID: 4321) == false)
        // 同一個 pid 換成別人的行程仍可結束，證明排除的是「自身」而非這個數值。
        #expect(ProcessTerminator.canTerminate(pid: 4321, currentPID: 4322) == true)
        // 預設值必須是本行程 pid，否則 UI 端拿不到這層保護。
        let ownPID = Int(ProcessInfo.processInfo.processIdentifier)
        #expect(ProcessTerminator.canTerminate(pid: ownPID) == false)
    }

    @Test("右鍵選單 Quit 走 app terminate 路由、Force Quit 才直接送 signal")
    func contextMenuRoutesQuitThroughAppTermination() throws {
        let source = try loadProjectSource("StatsMonitor/Sources/Views/Shared/ProcessTerminationContextMenu.swift")

        #expect(source.contains("ProcessTerminator.quit("), "Quit 應走 ProcessTerminator.quit，而非直接送 SIGTERM")
        #expect(
            source.contains(".forceKill"),
            "Force Quit 應維持走 terminate(signal: .forceKill)"
        )
        #expect(
            !source.contains("terminate(signal: .terminate)"),
            "Quit 不該再直送 SIGTERM，Cocoa app 收 SIGTERM 會直接死、來不及存檔"
        )
    }

    // MARK: 成功路徑

    @Test("SIGTERM 成功：pid 與 signal 原封不動送進 kill，且不丟錯")
    func sendsTerminateSignalOnSuccess() throws {
        let spy = KillSpy(result: 0)

        try ProcessTerminator.terminate(pid: 4321, signal: .terminate, kill: spy.kill)

        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.pid == 4321)
        #expect(spy.calls.first?.signal == SIGTERM)
    }

    @Test("SIGKILL 成功：送出 signal 9")
    func sendsForceKillSignalOnSuccess() throws {
        let spy = KillSpy(result: 0)

        try ProcessTerminator.terminate(pid: 99, signal: .forceKill, kill: spy.kill)

        #expect(spy.calls.count == 1)
        #expect(spy.calls.first?.pid == 99)
        #expect(spy.calls.first?.signal == SIGKILL)
    }

    // MARK: 失敗路徑（不吞錯）

    @Test("kill 回 -1 且 errno 為 EPERM → permissionDenied")
    func mapsEPERMToPermissionDenied() {
        let spy = KillSpy(result: -1, errorNumber: EPERM)

        let error = captureError {
            try ProcessTerminator.terminate(pid: 1, signal: .terminate, kill: spy.kill)
        }

        #expect(error == .permissionDenied)
        #expect(spy.calls.count == 1)
    }

    @Test("kill 回 -1 且 errno 為 ESRCH → noSuchProcess")
    func mapsESRCHToNoSuchProcess() {
        let spy = KillSpy(result: -1, errorNumber: ESRCH)

        let error = captureError {
            try ProcessTerminator.terminate(pid: 4321, signal: .forceKill, kill: spy.kill)
        }

        #expect(error == .noSuchProcess)
    }

    @Test("kill 回 -1 且 errno 是其他值 → other 帶原始 errno")
    func mapsUnknownErrnoToOther() {
        let spy = KillSpy(result: -1, errorNumber: EINVAL)

        let error = captureError {
            try ProcessTerminator.terminate(pid: 4321, signal: .terminate, kill: spy.kill)
        }

        #expect(error == .other(errorNumber: EINVAL))
    }

    @Test("kill 預設參數就是真正的 Darwin.kill：對不存在的 pid 回報 noSuchProcess")
    func defaultKillCallsRealSyscall() {
        // macOS pid 上限遠小於 Int32.max，此 pid 必不存在；signal 不會落到任何行程上。
        let error = captureError {
            try ProcessTerminator.terminate(pid: Int(Int32.max), signal: .terminate)
        }

        #expect(error == .noSuchProcess)
    }

    // MARK: 文案

    @Test("alert 文案可釘死英文")
    func copyCanBePinnedToEnglish() {
        let locale = Locale(identifier: "en")

        #expect(ProcessTerminationCopy.forceQuitTitle(processName: "Xcode", locale: locale)
            == "Force Quit Xcode?")
        #expect(ProcessTerminationCopy.forceQuitMessage(locale: locale)
            == "Force quitting ends the process immediately. Unsaved changes will be lost.")
        #expect(ProcessTerminationCopy.forceQuitConfirm(locale: locale) == "Force Quit")
        #expect(ProcessTerminationCopy.cancel(locale: locale) == "Cancel")
        #expect(ProcessTerminationCopy.dismiss(locale: locale) == "OK")
        #expect(ProcessTerminationCopy.failureTitle(processName: "Xcode", locale: locale)
            == "Unable to quit Xcode")
    }

    @Test("失敗訊息＝人話句子＋errno 描述，四種錯誤各有自己的說法")
    func failureMessageCombinesHumanSentenceAndErrno() {
        let locale = Locale(identifier: "en")

        #expect(ProcessTerminationCopy.failureMessage(error: .permissionDenied, locale: locale)
            == "StatsMonitor does not have permission to quit this process. (\(strerrorText(EPERM)))")
        #expect(ProcessTerminationCopy.failureMessage(error: .noSuchProcess, locale: locale)
            == "The process is no longer running. (\(strerrorText(ESRCH)))")
        #expect(ProcessTerminationCopy.failureMessage(error: .other(errorNumber: EINVAL), locale: locale)
            == "The process could not be quit. (\(strerrorText(EINVAL)))")
        // invalidPID 不是 errno 失敗，不能硬掛一個 strerror 上去。
        #expect(ProcessTerminationCopy.failureMessage(error: .invalidPID(0), locale: locale)
            == "This process does not report a valid process ID.")
    }

    @Test("alert 文案有 zh-Hant 譯文")
    func copyHasTraditionalChineseLocalization() {
        let locale = Locale(identifier: "zh-Hant")

        #expect(ProcessTerminationCopy.forceQuitTitle(processName: "Xcode", locale: locale)
            == "強制結束 Xcode？")
        #expect(ProcessTerminationCopy.forceQuitMessage(locale: locale)
            == "強制結束會立即終止此行程，未儲存的變更將會遺失。")
        #expect(ProcessTerminationCopy.forceQuitConfirm(locale: locale) == "強制結束")
        #expect(ProcessTerminationCopy.cancel(locale: locale) == "取消")
        #expect(ProcessTerminationCopy.dismiss(locale: locale) == "好")
        #expect(ProcessTerminationCopy.failureTitle(processName: "Xcode", locale: locale)
            == "無法結束 Xcode")
        #expect(ProcessTerminationCopy.failureMessage(error: .permissionDenied, locale: locale)
            == "StatsMonitor 沒有結束此行程的權限。 (\(strerrorText(EPERM)))")
        #expect(ProcessTerminationCopy.failureMessage(error: .noSuchProcess, locale: locale)
            == "此行程已不在執行中。 (\(strerrorText(ESRCH)))")
        #expect(ProcessTerminationCopy.failureMessage(error: .invalidPID(0), locale: locale)
            == "此行程沒有有效的行程 ID。")
    }

    @Test("右鍵選單新增的 key 在 xcstrings 皆有 zh-Hant 譯文")
    func terminationKeysHaveTraditionalChinese() throws {
        let catalog = try loadLocalizableStringCatalog()
        let expected = [
            "Force Quit": "強制結束",
            "Force Quit %@?": "強制結束 %@？",
            "Force quitting ends the process immediately. Unsaved changes will be lost.":
                "強制結束會立即終止此行程，未儲存的變更將會遺失。",
            "Unable to quit %@": "無法結束 %@",
            "StatsMonitor does not have permission to quit this process.":
                "StatsMonitor 沒有結束此行程的權限。",
            "The process is no longer running.": "此行程已不在執行中。",
            "The process could not be quit.": "無法結束此行程。",
            "This process does not report a valid process ID.": "此行程沒有有效的行程 ID。",
            "OK": "好",
        ]

        for (key, translation) in expected {
            let unit = try #require(
                catalog[key]?["localizations"]
                    .flatMap { $0 as? [String: Any] }?["zh-Hant"]
                    .flatMap { $0 as? [String: Any] }?["stringUnit"]
                    .flatMap { $0 as? [String: Any] },
                "缺少 \(key) 的 zh-Hant 譯文"
            )
            #expect(unit["state"] as? String == "translated")
            #expect(unit["value"] as? String == translation)
        }
    }

    // MARK: 兩張表共用同一實作

    @Test("兩張行程表都套用共用的右鍵選單 modifier，不各自實作 kill / alert")
    func bothProcessTablesShareTerminationContextMenu() throws {
        let tableSources = [
            "StatsMonitor/Sources/Views/Shared/TopProcessesTable.swift",
            "StatsMonitor/Sources/Views/MainWindowView/PowerChartsView.swift",
        ]

        for path in tableSources {
            let source = try loadProjectSource(path)
            #expect(source.contains("processTerminationContextMenu("), "\(path) 沒有套用共用的右鍵選單 modifier")
            #expect(!source.contains("func processTerminationContextMenu"), "\(path) 自己定義 modifier，共用實作應放 Views/Shared")
            #expect(!source.contains("NSAlert"), "\(path) 不該自己組 alert")
            #expect(!source.contains("kill("), "\(path) 不該自己呼叫 kill，要走 ProcessTerminator")
        }
    }
}

/// 記錄「請 app 自己結束」的請求，並照腳本回覆：
/// `nil` ＝這個 pid 不是 GUI app，`true` ＝請求已送出，`false` ＝請求沒送出去。
private final class AppTerminationSpy {
    private(set) var calls: [Int32] = []
    private let result: Bool?

    init(result: Bool?) {
        self.result = result
    }

    func requestTermination(_ pid: Int32) -> Bool? {
        calls.append(pid)
        return result
    }
}

/// Quit 的契約：GUI app 要收到 Apple Event quit（走 applicationShouldTerminate、可存檔），
/// 不能像舊實作那樣直接 SIGTERM——Cocoa app 收 SIGTERM 會直接死，與「Quit 溫和」的文案不符。
@Suite("Process Quit Routing")
@MainActor
struct ProcessQuitRoutingTests {

    private func captureError(_ body: () throws -> Void) -> ProcessTerminationError? {
        do {
            try body()
            return nil
        } catch let error as ProcessTerminationError {
            return error
        } catch {
            Issue.record("預期 ProcessTerminationError，實得 \(error)")
            return nil
        }
    }

    @Test("pid 對得到 app：只送 app terminate 請求，完全不呼叫 kill")
    func quitAsksAppToTerminateWithoutKilling() throws {
        let app = AppTerminationSpy(result: true)
        let kill = KillSpy(result: 0)

        try ProcessTerminator.quit(pid: 4321, requestAppTermination: app.requestTermination, kill: kill.kill)

        #expect(app.calls == [4321])
        #expect(kill.calls.isEmpty, "app 已收到 quit 請求，再補 SIGTERM 會讓它來不及存檔就死")
    }

    @Test("pid 對不到 app（非 GUI 行程）：fallback 送 SIGTERM")
    func quitFallsBackToSignalForNonAppProcess() throws {
        let app = AppTerminationSpy(result: nil)
        let kill = KillSpy(result: 0)

        try ProcessTerminator.quit(pid: 777, requestAppTermination: app.requestTermination, kill: kill.kill)

        #expect(app.calls == [777])
        #expect(kill.calls.count == 1)
        #expect(kill.calls.first?.pid == 777)
        #expect(kill.calls.first?.signal == SIGTERM)
    }

    @Test("terminate 請求送不出去（回 false，例如行程已不在）：fallback 送 SIGTERM")
    func quitFallsBackToSignalWhenRequestNotSent() throws {
        let app = AppTerminationSpy(result: false)
        let kill = KillSpy(result: 0)

        try ProcessTerminator.quit(pid: 555, requestAppTermination: app.requestTermination, kill: kill.kill)

        #expect(app.calls == [555])
        #expect(kill.calls.count == 1)
        #expect(kill.calls.first?.pid == 555)
        #expect(kill.calls.first?.signal == SIGTERM)
    }

    @Test("kill 失敗時 quit 不吞錯：errno 照樣分類拋出")
    func quitPropagatesKillFailure() {
        let app = AppTerminationSpy(result: nil)
        let kill = KillSpy(result: -1, errorNumber: EPERM)

        let error = captureError {
            try ProcessTerminator.quit(pid: 555, requestAppTermination: app.requestTermination, kill: kill.kill)
        }

        #expect(error == .permissionDenied)
    }

    @Test("quit 也擋無效 pid：兩個注入點都不該被呼叫")
    func quitRejectsInvalidPIDWithoutTouchingAnything() {
        for invalid in [0, -1, Int(Int32.max) + 1] {
            let app = AppTerminationSpy(result: true)
            let kill = KillSpy(result: 0)

            let error = captureError {
                try ProcessTerminator.quit(pid: invalid, requestAppTermination: app.requestTermination, kill: kill.kill)
            }

            #expect(error == .invalidPID(invalid))
            #expect(app.calls.isEmpty)
            #expect(kill.calls.isEmpty)
        }
    }

    @Test("Force Quit 不走 app 請求：一律直送 SIGKILL")
    func forceQuitBypassesAppTermination() throws {
        let kill = KillSpy(result: 0)

        try ProcessTerminator.terminate(pid: 4321, signal: .forceKill, kill: kill.kill)

        #expect(kill.calls.count == 1)
        #expect(kill.calls.first?.signal == SIGKILL)
    }
}

@Suite("Process Termination Alerts")
@MainActor
struct ProcessTerminationAlertTests {

    @Test("強制結束確認 alert 用共用文案與按鈕順序")
    func forceQuitConfirmationMatchesCopy() {
        let alert = ProcessTerminationAlertFactory.makeForceQuitConfirmation(processName: "Xcode")

        #expect(alert.messageText == ProcessTerminationCopy.forceQuitTitle(processName: "Xcode"))
        #expect(alert.messageText.contains("Xcode"))
        #expect(alert.informativeText == ProcessTerminationCopy.forceQuitMessage())
        #expect(alert.alertStyle == .warning)
        #expect(alert.buttons.map(\.title)
            == [ProcessTerminationCopy.forceQuitConfirm(), ProcessTerminationCopy.cancel()])
    }

    @Test("失敗 alert 顯示行程名、人話說明與 errno 描述，只有一顆關閉鍵")
    func failureAlertMatchesCopy() {
        let alert = ProcessTerminationAlertFactory.makeFailureAlert(
            processName: "Xcode",
            error: .permissionDenied
        )

        #expect(alert.messageText == ProcessTerminationCopy.failureTitle(processName: "Xcode"))
        #expect(alert.messageText.contains("Xcode"))
        #expect(alert.informativeText == ProcessTerminationCopy.failureMessage(error: .permissionDenied))
        #expect(alert.informativeText.contains(strerrorText(EPERM)))
        #expect(alert.alertStyle == .warning)
        #expect(alert.buttons.map(\.title) == [ProcessTerminationCopy.dismiss()])
    }

    @Test("失敗 alert 的錯誤內容隨 error 改變，不是寫死一句")
    func failureAlertReflectsError() {
        let permission = ProcessTerminationAlertFactory.makeFailureAlert(
            processName: "Xcode",
            error: .permissionDenied
        )
        let missing = ProcessTerminationAlertFactory.makeFailureAlert(
            processName: "Xcode",
            error: .noSuchProcess
        )

        #expect(permission.informativeText != missing.informativeText)
        #expect(missing.informativeText.contains(strerrorText(ESRCH)))
    }

    @Test("共用右鍵選單 modifier 可套在任一列上並算得出版面")
    func terminationContextMenuModifierRenders() {
        let process = ProcInfo(pid: 4321, name: "Xcode", cpuPercent: 12.5)
        let host = NSHostingView(
            rootView: Text(verbatim: process.name).processTerminationContextMenu(for: process)
        )

        #expect(host.fittingSize.width > 0)
    }
}
