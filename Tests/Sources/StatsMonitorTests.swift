import Testing
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
        let p = ProcInfo(name: "Xcode", cpuPercent: 12.5, memoryBytes: 500_000_000)
        #expect(p.name == "Xcode")
        #expect(p.cpuPercent == 12.5)
        #expect(p.memoryBytes == 500_000_000)
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

// MARK: - StatsViewModel Tests

@Suite("StatsViewModel")
@MainActor
struct StatsViewModelTests {

    // MARK: - Lifecycle

    @Test("init and stop do not crash")
    func lifecycle() {
        let vm = StatsViewModel()
        vm.stop()
    }

    @Test("start and stop do not crash")
    func startStop() {
        let vm = StatsViewModel()
        vm.stop()
        vm.start()
        vm.stop()
    }

    // MARK: - Formatted properties with known SystemStats input

    @Test("cpuPercent shows sum of user and system with one decimal")
    func cpuPercentKnownInput() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.cpu = CPUUsage(user: 30, system: 20, idle: 50, perCore: [], coreFrequencies: [])
        #expect(vm.cpuPercent == "50.0%")
        #expect(vm.cpuUserPercent == "30.0%")
        #expect(vm.cpuSystemPercent == "20.0%")
    }

    @Test("memoryPercent reflects usedFraction with one decimal")
    func memoryPercentKnownInput() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        // active(2GB) + wired(1GB) + compressed(1GB) = 4GB used; total = 8GB → 50%
        vm.monitor.stats.memory = MemoryUsage(
            active: 2_147_483_648, wired: 1_073_741_824,
            compressed: 1_073_741_824, total: 8_589_934_592
        )
        #expect(vm.memoryPercent == "50.0%")
    }

    @Test("diskPercent reflects usedFraction with one decimal")
    func diskPercentKnownInput() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.disk = DiskUsage(used: 250_000_000_000, total: 500_000_000_000)
        #expect(vm.diskPercent == "50.0%")
    }

    @Test("batteryPercent returns N/A when battery is nil")
    func batteryPercentNoBattery() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = nil
        #expect(vm.batteryPercent == "N/A")
    }

    @Test("batteryPercent returns formatted value when battery present")
    func batteryPercentWithBattery() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 80, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        )
        #expect(vm.batteryPercent == "80%")
    }

    // MARK: - batteryStatus branching

    @Test("batteryStatus is Charging when isCharging")
    func batteryStatusCharging() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: true, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(vm.batteryStatus == "Charging")
    }

    @Test("batteryStatus is Plugged In when plugged in but not charging")
    func batteryStatusPluggedIn() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 100, isCharging: false, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(vm.batteryStatus == "Plugged In")
    }

    @Test("batteryStatus shows hours and minutes when on battery with estimate ≥ 60m")
    func batteryStatusTimeRemainingHoursAndMinutes() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: 90, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(vm.batteryStatus == "1h 30m")
    }

    @Test("batteryStatus shows minutes only when less than 1 hour remaining")
    func batteryStatusTimeRemainingMinutesOnly() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 10, isCharging: false, isPluggedIn: false,
            timeRemaining: 45, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(vm.batteryStatus == "45m")
    }

    @Test("batteryStatus is On Battery when no charging and no time estimate")
    func batteryStatusOnBattery() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(vm.batteryStatus == "On Battery")
    }

    // MARK: - anePowerStr branching

    @Test("anePowerStr shows mW when below 1000 mW")
    func anePowerMW() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.gpu = GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 500
        )
        #expect(vm.anePowerStr == "500 mW")
    }

    @Test("anePowerStr shows W when 1000 mW or more")
    func anePowerW() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        vm.monitor.stats.gpu = GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 2500
        )
        #expect(vm.anePowerStr == "2.5 W")
    }

    // MARK: - formatProcess helpers (known input → known output)

    @Test("formatProcessCPU formats one decimal percent")
    func formatProcessCPU() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        #expect(vm.formatProcessCPU(50.0)  == "50.0%")
        #expect(vm.formatProcessCPU(0.0)   == "0.0%")
        #expect(vm.formatProcessCPU(100.0) == "100.0%")
    }

    @Test("formatProcessMemory formats bytes to human-readable")
    func formatProcessMemory() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        #expect(vm.formatProcessMemory(1_073_741_824) == "1.0 GB")
        #expect(vm.formatProcessMemory(1_048_576)     == "1 MB")
        #expect(vm.formatProcessMemory(0)             == "0 B")
    }

    @Test("formatProcessDisk formats throughput")
    func formatProcessDisk() {
        let vm = StatsViewModel()
        defer { vm.stop() }
        #expect(vm.formatProcessDisk(1_048_576) == "1.0 MB/s")
        #expect(vm.formatProcessDisk(0)         == "0 KB/s")
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
