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

// MARK: - SystemMonitor Presentation Tests

@Suite("SystemMonitor Presentation")
@MainActor
struct SystemMonitorPresentationTests {

    private func makeMonitor() -> SystemMonitor {
        SystemMonitor(settings: AppSettings())
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

    // MARK: - Formatted properties with known SystemStats input

    @Test("cpuPercent shows sum of user and system with one decimal")
    func cpuPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.cpu = CPUUsage(user: 30, system: 20, idle: 50, perCore: [], coreFrequencies: [])
        #expect(monitor.cpuPercent == "50.0%")
        #expect(monitor.cpuUserPercent == "30.0%")
        #expect(monitor.cpuSystemPercent == "20.0%")
    }

    @Test("memoryPercent reflects usedFraction with one decimal")
    func memoryPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        // active(2GB) + wired(1GB) + compressed(1GB) = 4GB used; total = 8GB → 50%
        monitor.stats.memory = MemoryUsage(
            active: 2_147_483_648, wired: 1_073_741_824,
            compressed: 1_073_741_824, total: 8_589_934_592
        )
        #expect(monitor.memoryPercent == "50.0%")
    }

    @Test("diskPercent reflects usedFraction with one decimal")
    func diskPercentKnownInput() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.disk = DiskUsage(used: 250_000_000_000, total: 500_000_000_000)
        #expect(monitor.diskPercent == "50.0%")
    }

    @Test("batteryPercent returns N/A when battery is nil")
    func batteryPercentNoBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = nil
        #expect(monitor.batteryPercent == "N/A")
    }

    @Test("batteryPercent returns formatted value when battery present")
    func batteryPercentWithBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 80, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 100,
            designCapacity: 5000, maxCapacity: 4800, health: 96
        )
        #expect(monitor.batteryPercent == "80%")
    }

    // MARK: - batteryStatus branching

    @Test("batteryStatus is Charging when isCharging")
    func batteryStatusCharging() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: true, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(monitor.batteryStatusText == "Charging")
    }

    @Test("batteryStatus is Plugged In when plugged in but not charging")
    func batteryStatusPluggedIn() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 100, isCharging: false, isPluggedIn: true,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(monitor.batteryStatusText == "Plugged In")
    }

    @Test("batteryStatus shows hours and minutes when on battery with estimate ≥ 60m")
    func batteryStatusTimeRemainingHoursAndMinutes() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: 90, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(monitor.batteryStatusText == "1h 30m")
    }

    @Test("batteryStatus shows minutes only when less than 1 hour remaining")
    func batteryStatusTimeRemainingMinutesOnly() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 10, isCharging: false, isPluggedIn: false,
            timeRemaining: 45, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(monitor.batteryStatusText == "45m")
    }

    @Test("batteryStatus is On Battery when no charging and no time estimate")
    func batteryStatusOnBattery() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.battery = BatteryUsage(
            percentage: 60, isCharging: false, isPluggedIn: false,
            timeRemaining: nil, cycleCount: 50,
            designCapacity: 5000, maxCapacity: 5000, health: 100
        )
        #expect(monitor.batteryStatusText == "On Battery")
    }

    // MARK: - anePowerStr branching

    @Test("anePowerStr shows mW when below 1000 mW")
    func anePowerMW() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.gpu = GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 500
        )
        #expect(monitor.anePowerText == "500 mW")
    }

    @Test("anePowerStr shows W when 1000 mW or more")
    func anePowerW() {
        let monitor = makeMonitor()
        defer { monitor.stop() }
        monitor.stats.gpu = GPUUsage(
            deviceUtilization: 0, renderUtilization: 0,
            engines: [:], vramUsed: 0, anePowerMilliWatts: 2500
        )
        #expect(monitor.anePowerText == "2.5 W")
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
}

@Suite("SystemMonitor")
@MainActor
struct SystemMonitorTests {

    @Test("latest metric writes append matching history")
    func latestMetricWritesAppendHistory() {
        let monitor = SystemMonitor(settings: AppSettings())

        monitor.cpuLatest = 12.5
        monitor.cpuLatest = 18.0
        monitor.batteryLatest = nil
        monitor.batteryLatest = 77.0
        monitor.cpuTempLatest = 64.2

        #expect(Array(monitor.cpuHistory) == [12.5, 18.0])
        #expect(Array(monitor.batteryHistory) == [77.0])
        #expect(Array(monitor.cpuTempHistory) == [64.2])
    }

    @Test("stats mutations sync latest values without appending history")
    func statsMutationsSyncLatestValues() {
        let monitor = SystemMonitor(settings: AppSettings())

        monitor.stats.cpu = CPUUsage(user: 22, system: 8, idle: 70, perCore: [], coreFrequencies: [])
        monitor.stats.network = NetworkUsage(bytesInPerSec: 1_024, bytesOutPerSec: 2_048)

        #expect(monitor.cpuLatest == 30)
        #expect(monitor.networkInLatest == 1_024)
        #expect(monitor.networkOutLatest == 2_048)
        #expect(Array(monitor.cpuHistory).isEmpty)
        #expect(Array(monitor.networkInHistory).isEmpty)
    }

    @Test("historyCapacity changes recreate buffers without a view-model adapter")
    func historyCapacityChangeRecreatesBuffersViaSettingsObservation() async throws {
        let settings = AppSettings()
        settings.historyCapacity = 60
        let monitor = SystemMonitor(settings: settings)

        monitor.cpuLatest = 42
        #expect(Array(monitor.cpuHistory) == [42])

        settings.historyCapacity = 300
        try await Task.sleep(for: .milliseconds(50))

        #expect(monitor.cpuHistory.capacity == 300)
        #expect(Array(monitor.cpuHistory).isEmpty)
    }

    @Test("resetHistories keeps current buffers until historyCapacity changes, then recreates them")
    func resetHistoriesRecreatesBuffersOnCapacityChange() {
        let defaults = UserDefaults.standard
        let key = "historyCapacity"
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(60, forKey: key)
        let settings = AppSettings()
        let monitor = SystemMonitor(settings: settings)
        monitor.start()
        defer { monitor.stop() }

        #expect(!Array(monitor.cpuHistory).isEmpty)
        #expect(!Array(monitor.gpuHistory).isEmpty)
        #expect(!Array(monitor.networkOutHistory).isEmpty)

        monitor.resetHistories()
        #expect(monitor.cpuHistory.capacity == 60)
        #expect(!Array(monitor.cpuHistory).isEmpty)
        #expect(!Array(monitor.gpuHistory).isEmpty)
        #expect(!Array(monitor.networkOutHistory).isEmpty)
        #expect(monitor.gpuTempHistory.capacity == 60)
        #expect(monitor.fanAverageHistory.capacity == 60)

        settings.historyCapacity = 300
        monitor.resetHistories()

        #expect(monitor.cpuHistory.capacity == 300)
        #expect(monitor.gpuHistory.capacity == 300)
        #expect(monitor.networkOutHistory.capacity == 300)
        #expect(monitor.gpuTempHistory.capacity == 300)
        #expect(monitor.fanAverageHistory.capacity == 300)
        #expect(Array(monitor.cpuHistory).isEmpty)
        #expect(Array(monitor.gpuHistory).isEmpty)
        #expect(Array(monitor.networkOutHistory).isEmpty)
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
        let defaults = UserDefaults.standard
        let key = "dashboardColumns"
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.removeObject(forKey: key)

        let settings = AppSettings()

        #expect(settings.dashboardColumns == AppSettings.defaultDashboardColumns)
    }

    @Test("dashboard column restores persisted values within supported range")
    func dashboardColumnRestoreClampsOutOfRangeValues() {
        let defaults = UserDefaults.standard
        let key = "dashboardColumns"
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        defaults.set(2, forKey: key)
        #expect(AppSettings().dashboardColumns == AppSettings.dashboardColumnRange.lowerBound)

        defaults.set(7, forKey: key)
        #expect(AppSettings().dashboardColumns == AppSettings.dashboardColumnRange.upperBound)
    }

    @Test("all supported menu bar monitor items default to visible")
    func monitorItemVisibilityDefaults() {
        let defaults = UserDefaults.standard
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
        let originalValues = keys.reduce(into: [String: Any?]()) { values, key in
            values[key] = defaults.object(forKey: key)
        }
        defer {
            for key in keys {
                if let value = originalValues[key] ?? nil {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }

        for key in keys {
            defaults.removeObject(forKey: key)
        }

        let settings = AppSettings()

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
        let defaults = UserDefaults.standard
        let key = "dashboardColumns"
        let originalValue = defaults.object(forKey: key)
        defer {
            if let originalValue {
                defaults.set(originalValue, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }

        let settings = AppSettings()
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
            BatteryDetailView.panelTitle,
            ThermalDetailView.panelTitle,
            PowerDetailView.panelTitle,
            FansDetailView.panelTitle,
        ]

        #expect(titles == ["CPU", "GPU", "Memory", "Disk", "Network", "Battery", "Thermal", "Power", "Fans"])
        #expect(Set(titles).count == PanelID.allCases.count)
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
