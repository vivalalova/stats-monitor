import Foundation
import Util

@MainActor
extension SystemMonitor {
    var cpuFraction: Double { cpuLatest / 100 }
    var gpuFraction: Double { gpuLatest / 100 }
    var memoryFraction: Double { memoryLatest / 100 }
    var diskFraction: Double { diskLatest / 100 }

    var cpuPercent: String { formatPercent(cpuLatest) }
    var cpuUserPercent: String { formatPercent(stats.cpu.user) }
    var cpuSystemPercent: String { formatPercent(stats.cpu.system) }
    var cpuPerCore: [Double] { stats.cpu.perCore }
    var cpuCoreFrequencies: [CPUCoreFrequency] { stats.cpu.coreFrequencies }
    var paddedCPUHistory: [Double] { padded(cpuHistory) }

    var gpuPercent: String { formatPercent(gpuLatest) }
    var gpuRenderPercent: String { formatPercent(stats.gpu.renderUtilization) }
    var gpuEngines: [String: Double] { stats.gpu.engines }
    var paddedGPUHistory: [Double] { padded(gpuHistory) }
    var gpuVramUsed: UInt64 { stats.gpu.vramUsed }
    var gpuVramUsedText: String { formatBytes(stats.gpu.vramUsed) }
    var anePowerMilliWatts: Double { stats.gpu.anePowerMilliWatts }
    var anePowerText: String {
        let milliWatts = stats.gpu.anePowerMilliWatts
        return milliWatts >= 1000
            ? String(format: "%.1f W", milliWatts / 1000)
            : String(format: "%.0f mW", milliWatts)
    }

    var memoryUsedText: String { formatBytes(stats.memory.used) }
    var memoryTotalText: String { formatBytes(stats.memory.total) }
    var memoryPercent: String { formatPercent(memoryLatest) }
    var memoryActiveText: String { formatBytes(stats.memory.active) }
    var memoryWiredText: String { formatBytes(stats.memory.wired) }
    var memoryCompressedText: String { formatBytes(stats.memory.compressed) }
    var paddedMemoryHistory: [Double] { padded(memoryHistory) }

    var diskUsedText: String { formatBytes(stats.disk.used) }
    var diskFreeText: String { formatBytes(stats.disk.total - stats.disk.used) }
    var diskTotalText: String { formatBytes(stats.disk.total) }
    var diskPercent: String { formatPercent(diskLatest) }
    var diskReadText: String { formatThroughput(diskReadLatest) }
    var diskWriteText: String { formatThroughput(diskWriteLatest) }
    var paddedDiskHistory: [Double] { padded(diskHistory) }
    var paddedDiskReadHistory: [Double] { padded(diskReadHistory) }
    var paddedDiskWriteHistory: [Double] { padded(diskWriteHistory) }

    var networkInText: String { formatThroughput(networkInLatest) }
    var networkOutText: String { formatThroughput(networkOutLatest) }
    var paddedNetworkInHistory: [Double] { padded(networkInHistory) }
    var paddedNetworkOutHistory: [Double] { padded(networkOutHistory) }

    var topCPUProcesses: [ProcInfo] { stats.topCPUProcesses }
    var topMemoryProcesses: [ProcInfo] { stats.topMemoryProcesses }
    var topDiskProcesses: [ProcInfo] { stats.topDiskProcesses }
    var topNetworkProcesses: [ProcInfo] { stats.topNetworkProcesses }

    var power: PowerUsage? { stats.power }
    var hasPower: Bool { stats.power != nil }
    var paddedPowerHistory: [Double] { padded(powerHistory) }
    var powerText: String {
        guard let watts = powerLatest else { return "N/A" }
        return String(format: "%.1f W", watts)
    }
    var cpuPowerText: String {
        guard let power else { return "N/A" }
        return String(format: "%.1f W", power.cpuWatts)
    }
    var gpuPowerText: String {
        guard let power else { return "N/A" }
        return String(format: "%.1f W", power.gpuWatts)
    }

    var battery: BatteryUsage? { stats.battery }
    var hasBattery: Bool { stats.battery != nil }
    var paddedBatteryHistory: [Double] { padded(batteryHistory) }
    var batteryPercent: String {
        guard let batteryLatest else { return "N/A" }
        return String(format: "%.0f%%", batteryLatest)
    }
    var batteryFraction: Double { (batteryLatest ?? 0) / 100.0 }
    var batteryStatusText: String {
        guard let battery else { return "" }
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged In" }
        if let mins = battery.timeRemaining {
            let hours = mins / 60
            let minutes = mins % 60
            return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
        }
        return "On Battery"
    }
    var batteryHealthText: String {
        guard let battery else { return "" }
        return String(format: "%.0f%%", battery.health)
    }
    var batteryCyclesText: String {
        guard let battery else { return "" }
        return "\(battery.cycleCount) cycles"
    }
    var batteryTimeRemainingText: String {
        guard let battery else { return "" }
        guard !battery.isCharging, !battery.isPluggedIn else { return batteryStatusText }
        guard let mins = battery.timeRemaining else { return "Estimating" }
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }
    var batteryMaxCapacityText: String {
        guard let battery else { return "" }
        return "\(battery.maxCapacity) mAh"
    }
    var batteryDesignCapacityText: String {
        guard let battery else { return "" }
        return "\(battery.designCapacity) mAh"
    }

    var thermal: ThermalUsage? { stats.thermal }
    var hasThermal: Bool { stats.thermal != nil }
    var cpuTempText: String {
        guard let cpuTempLatest else { return "N/A" }
        return String(format: "%.1f°C", cpuTempLatest)
    }
    var gpuTempText: String {
        guard let gpuTempLatest else { return "—" }
        return String(format: "%.1f°C", gpuTempLatest)
    }
    var paddedCPUTempHistory: [Double] { padded(cpuTempHistory) }
    var paddedGPUTempHistory: [Double] { padded(gpuTempHistory) }
    var thermalSummaryText: String {
        guard thermal != nil else { return "N/A" }
        guard let gpuTempLatest else { return "CPU \(cpuTempText)" }
        return "CPU \(cpuTempText) GPU \(String(format: "%.1f°C", gpuTempLatest))"
    }

    var fans: [FanUsage] { stats.fans }
    var hasFans: Bool { !stats.fans.isEmpty }
    var fansSummaryText: String {
        guard !fans.isEmpty else { return "No fans" }
        if fans.count == 1 { return String(format: "%.0f RPM", fans[0].currentRPM) }
        let averageRPM = fans.map(\.currentRPM).reduce(0, +) / Double(fans.count)
        return String(format: "%.0f RPM avg", averageRPM)
    }
    var paddedFanAverageHistory: [Double] { padded(fanAverageHistory) }
    var fanChartMaxRPM: Double {
        max(fans.map(\.maxRPM).max() ?? 0, paddedFanAverageHistory.max() ?? 0, 1)
    }

    func formatProcessCPU(_ percent: Double) -> String { formatPercent(percent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }
    func formatProcessDisk(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func formatProcessNetwork(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func fanRPMText(_ fan: FanUsage) -> String { String(format: "%.0f RPM", fan.currentRPM) }
    func fanRangeText(_ fan: FanUsage) -> String { String(format: "%.0f–%.0f RPM", fan.minRPM, fan.maxRPM) }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func padded(_ buffer: RingBuffer<Double>) -> [Double] {
        let data = Array(buffer)
        guard !data.isEmpty, data.count < buffer.capacity else { return data }
        return Array(repeating: data[0], count: buffer.capacity - data.count) + data
    }
}
