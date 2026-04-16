import Foundation
import Util

@MainActor
extension SystemMonitor {
    private var currentCPU: CPUUsage { cpuSamples.current ?? .zero }
    private var currentGPU: GPUUsage { gpuSamples.current ?? .zero }
    private var currentMemory: MemoryUsage { memorySamples.current ?? .zero }
    private var currentDisk: DiskUsage { diskSamples.current ?? .zero }
    private var currentNetwork: NetworkUsage { networkSamples.current ?? .zero }

    var cpuFraction: Double { currentCPU.used / 100 }
    var gpuFraction: Double { currentGPU.used / 100 }
    var memoryFraction: Double { currentMemory.usedFraction }
    var diskFraction: Double { currentDisk.usedFraction }

    var cpuPercent: String { formatPercent(currentCPU.used) }
    var cpuUserPercent: String { formatPercent(currentCPU.user) }
    var cpuSystemPercent: String { formatPercent(currentCPU.system) }
    var cpuIdlePercent: String { formatPercent(currentCPU.idle) }
    var cpuPerCore: [Double] { currentCPU.perCore }
    var cpuCoreFrequencies: [CPUCoreFrequency] { currentCPU.coreFrequencies }
    var cpuAverageFrequencyText: String { formatAverageFrequency(cpuCoreFrequencies) }
    var cpuPeakFrequencyText: String { formatPeakFrequency(cpuCoreFrequencies) }
    var paddedCPUHistory: [Double] { padded(cpuSamples.values.map(\.used), capacity: cpuSamples.capacity) }

    var gpuPercent: String { formatPercent(currentGPU.used) }
    var gpuRenderPercent: String { formatPercent(currentGPU.renderUtilization) }
    var gpuEngines: [String: Double] { currentGPU.engines }
    var paddedGPUHistory: [Double] { padded(gpuSamples.values.map(\.used), capacity: gpuSamples.capacity) }
    var gpuVramUsed: UInt64 { currentGPU.vramUsed }
    var gpuVramUsedText: String { formatBytes(currentGPU.vramUsed) }
    var anePowerMilliWatts: Double { currentGPU.anePowerMilliWatts }
    var anePowerText: String {
        let milliWatts = currentGPU.anePowerMilliWatts
        return milliWatts >= 1000
            ? String(format: "%.1f W", milliWatts / 1000)
            : String(format: "%.0f mW", milliWatts)
    }

    var memoryUsedText: String { formatBytes(currentMemory.used) }
    var memoryTotalText: String { formatBytes(currentMemory.total) }
    var memoryFreeText: String {
        formatBytes(currentMemory.total > currentMemory.used ? currentMemory.total - currentMemory.used : 0)
    }
    var memoryPercent: String { formatPercent(currentMemory.usedFraction * 100) }
    var memoryActiveText: String { formatBytes(currentMemory.active) }
    var memoryWiredText: String { formatBytes(currentMemory.wired) }
    var memoryCompressedText: String { formatBytes(currentMemory.compressed) }
    var paddedMemoryHistory: [Double] { padded(memorySamples.values.map { $0.usedFraction * 100 }, capacity: memorySamples.capacity) }

    var diskUsedText: String { formatBytes(currentDisk.used) }
    var diskFreeText: String { formatBytes(currentDisk.total - currentDisk.used) }
    var diskTotalText: String { formatBytes(currentDisk.total) }
    var diskPercent: String { formatPercent(currentDisk.usedFraction * 100) }
    var diskReadText: String { formatThroughput(currentDisk.readBPS) }
    var diskWriteText: String { formatThroughput(currentDisk.writeBPS) }
    var diskActivityText: String { formatThroughput(currentDisk.readBPS + currentDisk.writeBPS) }
    var diskMenuText: String { diskActivityText }
    var paddedDiskHistory: [Double] { padded(diskSamples.values.map { $0.usedFraction * 100 }, capacity: diskSamples.capacity) }
    var paddedDiskReadHistory: [Double] { padded(diskSamples.values.map(\.readBPS), capacity: diskSamples.capacity) }
    var paddedDiskWriteHistory: [Double] { padded(diskSamples.values.map(\.writeBPS), capacity: diskSamples.capacity) }

    var networkInText: String { formatThroughput(currentNetwork.bytesInPerSec) }
    var networkOutText: String { formatThroughput(currentNetwork.bytesOutPerSec) }
    var networkTotalText: String { formatThroughput(currentNetwork.bytesInPerSec + currentNetwork.bytesOutPerSec) }
    var paddedNetworkInHistory: [Double] { padded(networkSamples.values.map(\.bytesInPerSec), capacity: networkSamples.capacity) }
    var paddedNetworkOutHistory: [Double] { padded(networkSamples.values.map(\.bytesOutPerSec), capacity: networkSamples.capacity) }

    var power: PowerUsage? { powerSamples.current }
    var hasPower: Bool { power != nil }
    var hasPowerPanel: Bool { hasPower }
    var paddedPowerHistory: [Double] { padded(powerSamples.values.map(\.totalWatts), capacity: powerSamples.capacity) }
    var powerText: String {
        guard let power else { return "N/A" }
        return String(format: "%.1f W", power.totalWatts)
    }
    var powerCompactText: String {
        guard let power else { return "" }
        return String(format: "%.1fW", power.totalWatts)
    }
    var cpuPowerText: String {
        guard let power else { return "N/A" }
        return String(format: "%.1f W", power.cpuWatts)
    }
    var gpuPowerText: String {
        guard let power else { return "N/A" }
        return String(format: "%.1f W", power.gpuWatts)
    }
    var externalInputPowerText: String {
        guard let inputWatts = power?.externalInputWatts else { return "" }
        return String(format: "%.1f W", inputWatts)
    }
    var batteryChargePowerText: String {
        guard let chargeWatts = power?.batteryChargeWatts else { return "" }
        return String(format: "%.1f W", chargeWatts)
    }
    var batteryDischargePowerText: String {
        guard let dischargeWatts = power?.batteryDischargeWatts else { return "" }
        return String(format: "%.1f W", dischargeWatts)
    }
    var powerBalanceText: String {
        guard let balanceWatts = power?.balanceWatts else { return "" }
        return String(format: "%+.1f W", balanceWatts)
    }

    var battery: BatteryUsage? { batterySamples.current }
    var hasBattery: Bool { battery != nil }
    var paddedBatteryHistory: [Double] { padded(batterySamples.values.map(\.percentage), capacity: batterySamples.capacity) }
    var batteryPercent: String {
        guard let battery else { return "N/A" }
        return String(format: "%.0f%%", battery.percentage)
    }
    var batteryFraction: Double { (battery?.percentage ?? 0) / 100.0 }
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
    var powerMenuText: String {
        guard hasPower else { return "N/A" }
        return powerCompactText
    }
    var powerMenuSymbol: String { "bolt.fill" }

    var thermal: ThermalUsage? { thermalSamples.current }
    var hasThermal: Bool { thermal != nil }
    var cpuTempText: String {
        guard let thermal else { return "N/A" }
        return String(format: "%.1f°C", thermal.cpuTemperature)
    }
    var gpuTempText: String {
        guard let gpuTemp = thermal?.gpuTemperature else { return "—" }
        return String(format: "%.1f°C", gpuTemp)
    }
    var paddedCPUTempHistory: [Double] { padded(thermalSamples.values.map(\.cpuTemperature), capacity: thermalSamples.capacity) }
    var paddedGPUTempHistory: [Double] { padded(thermalSamples.values.compactMap(\.gpuTemperature), capacity: thermalSamples.capacity) }
    var thermalSummaryText: String {
        guard thermal != nil else { return "N/A" }
        guard let gpuTemp = thermal?.gpuTemperature else { return "CPU \(cpuTempText)" }
        return "CPU \(cpuTempText) GPU \(String(format: "%.1f°C", gpuTemp))"
    }

    var fans: [FanUsage] { fansSamples.current ?? [] }
    var hasFans: Bool { !fans.isEmpty }
    var fanCountText: String {
        switch fans.count {
        case 0: "No fans"
        case 1: "1 fan"
        default: "\(fans.count) fans"
        }
    }
    var fansSummaryText: String {
        guard !fans.isEmpty else { return "No fans" }
        if fans.count == 1 { return String(format: "%.0f RPM", fans[0].currentRPM) }
        let averageRPM = fans.map(\.currentRPM).reduce(0, +) / Double(fans.count)
        return String(format: "%.0f RPM avg", averageRPM)
    }
    var paddedFanAverageHistory: [Double] {
        padded(
            fansSamples.values.map { sample in
                guard !sample.isEmpty else { return 0 }
                return sample.map(\.currentRPM).reduce(0, +) / Double(sample.count)
            },
            capacity: fansSamples.capacity
        )
    }
    var fanChartMaxRPM: Double {
        max(fans.map(\.maxRPM).max() ?? 0, paddedFanAverageHistory.max() ?? 0, 1)
    }

    func formatProcessCPU(_ percent: Double) -> String { formatPercent(percent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }
    func formatProcessDisk(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func formatProcessNetwork(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func formatProcessPower(_ process: ProcInfo) -> String { String(format: "%.1f impact", process.powerImpact) }
    func fanRPMText(_ fan: FanUsage) -> String { String(format: "%.0f RPM", fan.currentRPM) }
    func fanRangeText(_ fan: FanUsage) -> String { String(format: "%.0f–%.0f RPM", fan.minRPM, fan.maxRPM) }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatAverageFrequency(_ frequencies: [CPUCoreFrequency]) -> String {
        let currentValues = frequencies.map(\.currentHz).filter { $0 > 0 }
        guard !currentValues.isEmpty else { return "N/A" }
        let averageHz = currentValues.reduce(0, +) / UInt64(currentValues.count)
        return ghzString(averageHz)
    }

    private func formatPeakFrequency(_ frequencies: [CPUCoreFrequency]) -> String {
        guard let peakHz = frequencies.map(\.currentHz).filter({ $0 > 0 }).max() else { return "N/A" }
        return ghzString(peakHz)
    }

    private func padded(_ data: [Double], capacity: Int) -> [Double] {
        guard !data.isEmpty, data.count < capacity else { return data }
        return Array(repeating: 0, count: capacity - data.count) + data
    }
}
