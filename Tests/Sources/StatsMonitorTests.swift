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
        let gpu = GPUUsage(deviceUtilization: 42, renderUtilization: 30, engines: [:])
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
        let gpu = GPUUsage(deviceUtilization: 55, renderUtilization: 30, engines: engines)
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
}
