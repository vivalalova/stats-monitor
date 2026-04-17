import Foundation
import AppKit
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
    var cpuMenuText: String { formatMenuPercent(currentCPU.used) }
    var cpuUserPercent: String { formatPercent(currentCPU.user) }
    var cpuSystemPercent: String { formatPercent(currentCPU.system) }
    var cpuIdlePercent: String { formatPercent(currentCPU.idle) }
    var cpuPerCore: [Double] { currentCPU.perCore }
    var cpuCoreFrequencies: [CPUCoreFrequency] { currentCPU.coreFrequencies }
    var cpuAverageFrequencyText: String { formatAverageFrequency(cpuCoreFrequencies) }
    var cpuPeakFrequencyText: String { formatPeakFrequency(cpuCoreFrequencies) }
    var paddedCPUHistory: [Double] { padded(cpuSamples.values.map(\.used), capacity: cpuSamples.capacity) }
    var paddedCPUPerCoreHistories: [[Double]] {
        let coreCount = cpuSamples.values.map(\.perCore.count).max() ?? 0
        guard coreCount > 0 else { return [] }

        return (0..<coreCount).map { index in
            padded(
                cpuSamples.values.map { sample in
                    guard sample.perCore.indices.contains(index) else { return 0 }
                    return sample.perCore[index]
                },
                capacity: cpuSamples.capacity
            )
        }
    }

    var gpuPercent: String { formatPercent(currentGPU.used) }
    var gpuMenuText: String { formatMenuPercent(currentGPU.used) }
    var gpuRenderPercent: String { formatPercent(currentGPU.renderUtilization) }
    var gpuTilerPercent: String {
        currentGPU.tilerUtilization > 0 ? formatPercent(currentGPU.tilerUtilization) : ""
    }
    var gpuEngines: [String: Double] { currentGPU.engines }
    var paddedGPUHistory: [Double] { padded(gpuSamples.values.map(\.used), capacity: gpuSamples.capacity) }
    var paddedGPUEngineHistories: [(name: String, history: [Double])] {
        let names = gpuEngines.keys.sorted()
        return names.map { name in
            let history = padded(
                gpuSamples.values.map { $0.engines[name] ?? 0 },
                capacity: gpuSamples.capacity
            )
            return (name: name, history: history)
        }
    }
    var gpuVramUsed: UInt64 { currentGPU.vramUsed }
    var gpuVramUsedText: String {
        currentGPU.vramUsed > 0 ? formatBytes(currentGPU.vramUsed) : ""
    }
    var gpuDriverMemoryText: String {
        currentGPU.driverMemoryBytes > 0 ? formatBytes(currentGPU.driverMemoryBytes) : ""
    }
    var gpuAllocatedMemoryText: String {
        currentGPU.allocatedMemoryBytes > 0 ? formatBytes(currentGPU.allocatedMemoryBytes) : ""
    }
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
    var memoryMenuText: String { formatMenuPercent(currentMemory.usedFraction * 100) }
    var memoryActiveText: String { formatBytes(currentMemory.active) }
    var memoryWiredText: String { formatBytes(currentMemory.wired) }
    var memoryCompressedText: String { formatBytes(currentMemory.compressed) }
    var memorySwapUsedText: String {
        currentMemory.swapUsed > 0 ? formatBytes(currentMemory.swapUsed) : ""
    }
    var memorySwapTotalText: String {
        currentMemory.swapTotal > 0 ? formatBytes(currentMemory.swapTotal) : ""
    }
    var memorySwapSummaryText: String {
        guard currentMemory.swapTotal > 0 else { return "" }
        return "\(formatBytes(currentMemory.swapUsed)) / \(formatBytes(currentMemory.swapTotal))"
    }
    var memoryAvailablePercentText: String {
        guard let availablePercent = currentMemory.availablePercent else { return "" }
        return String(format: "%.0f%%", availablePercent)
    }
    var memoryPressureLevel: MemoryPressureLevel {
        MemoryMonitor.pressureLevel(forAvailablePercent: currentMemory.availablePercent)
    }
    var memoryPressureText: String {
        switch memoryPressureLevel {
        case .normal:
            return "Normal"
        case .warning:
            return "Warning"
        case .urgent:
            return "Urgent"
        case .critical:
            return "Critical"
        case .unknown:
            return ""
        }
    }
    var paddedMemoryHistory: [Double] { padded(memorySamples.values.map { $0.usedFraction * 100 }, capacity: memorySamples.capacity) }

    var diskUsedText: String { formatBytes(currentDisk.used) }
    var diskFreeText: String { formatBytes(currentDisk.total - currentDisk.used) }
    var diskTotalText: String { formatBytes(currentDisk.total) }
    var diskPercent: String { formatPercent(currentDisk.usedFraction * 100) }
    var diskReadText: String { formatThroughput(currentDisk.readBPS) }
    var diskWriteText: String { formatThroughput(currentDisk.writeBPS) }
    var diskActivityText: String { formatThroughput(currentDisk.readBPS + currentDisk.writeBPS) }
    var diskMenuText: String { formatMenuThroughput(currentDisk.readBPS + currentDisk.writeBPS) }
    var paddedDiskHistory: [Double] { padded(diskSamples.values.map { $0.usedFraction * 100 }, capacity: diskSamples.capacity) }
    var paddedDiskReadHistory: [Double] { padded(diskSamples.values.map(\.readBPS), capacity: diskSamples.capacity) }
    var paddedDiskWriteHistory: [Double] { padded(diskSamples.values.map(\.writeBPS), capacity: diskSamples.capacity) }

    var networkInText: String { formatThroughput(currentNetwork.bytesInPerSec) }
    var networkOutText: String { formatThroughput(currentNetwork.bytesOutPerSec) }
    var networkTotalText: String { formatThroughput(currentNetwork.bytesInPerSec + currentNetwork.bytesOutPerSec) }
    var networkMenuText: String { formatMenuThroughput(currentNetwork.bytesInPerSec) }
    var activeNetworkInterfaces: [NetworkInterfaceUsage] { currentNetwork.interfaces }
    var paddedNetworkInHistory: [Double] { padded(networkSamples.values.map(\.bytesInPerSec), capacity: networkSamples.capacity) }
    var paddedNetworkOutHistory: [Double] { padded(networkSamples.values.map(\.bytesOutPerSec), capacity: networkSamples.capacity) }

    var power: PowerUsage? { powerSamples.current }
    var hasPower: Bool { power != nil }
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
        if let mins = battery.timeRemaining { return formatMinutes(mins) }
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
        return formatMinutes(mins)
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
        return formatMenuPower(power?.totalWatts ?? 0)
    }
    var powerMenuSymbol: String { "bolt.fill" }

    var thermal: ThermalUsage? { thermalSamples.current }
    var thermalPressureText: String {
        guard let thermalPressureState else { return "" }
        return Self.thermalPressureText(for: thermalPressureState)
    }
    var hasThermal: Bool { thermal != nil || !thermalPressureText.isEmpty }
    var hasTemperatureReadings: Bool { thermal != nil }
    var thermalTemperatureStatusText: String {
        if thermal != nil {
            return cpuTempText
        }
        return thermalPressureText.isEmpty ? "N/A" : "Unavailable on this Mac"
    }
    var thermalMenuText: String {
        if thermal != nil {
            return formatMenuTemperature(thermal?.cpuTemperature ?? 0)
        }
        guard let thermalPressureState else { return "N/A" }
        return formatMenuThermalPressure(thermalPressureState)
    }
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
        guard thermal != nil else { return "" }
        guard let gpuTemp = thermal?.gpuTemperature else { return "CPU \(cpuTempText)" }
        return "CPU \(cpuTempText) GPU \(String(format: "%.1f°C", gpuTemp))"
    }
    var thermalDashboardText: String {
        if thermal != nil {
            return thermalPressureText.isEmpty ? "CPU \(cpuTempText)" : "CPU \(cpuTempText) \(thermalPressureText)"
        }
        return thermalPressureText
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
    var fansMenuText: String {
        guard !fans.isEmpty else { return "N/A" }
        let averageRPM = fans.map(\.currentRPM).reduce(0, +) / Double(fans.count)
        return formatMenuFanSpeed(averageRPM)
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
    func formatProcessGPU(_ process: GPUProcessInfo) -> String { formatPercent(process.utilizationPercent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }
    func formatProcessDisk(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func formatNetworkInterface(_ interface: NetworkInterfaceUsage) -> String {
        "↓\(formatThroughput(interface.bytesInPerSec)) ↑\(formatThroughput(interface.bytesOutPerSec))"
    }
    func formatProcessNetwork(_ bytesPerSecond: Double) -> String { formatThroughput(bytesPerSecond) }
    func formatProcessPower(_ process: ProcInfo) -> String { String(format: "%.1f impact", process.powerImpact) }
    func fanRPMText(_ fan: FanUsage) -> String { String(format: "%.0f RPM", fan.currentRPM) }
    func fanRangeText(_ fan: FanUsage) -> String { String(format: "%.0f–%.0f RPM", fan.minRPM, fan.maxRPM) }

    private func formatMinutes(_ mins: Int) -> String {
        let hours = mins / 60
        let minutes = mins % 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private func formatMenuPercent(_ value: Double) -> String {
        String(format: "%.0f%%", value)
    }

    private func formatMenuThroughput(_ bytesPerSec: Double) -> String {
        formatCompactMenuValue(
            bytesPerSec / 1_024,
            units: ["K", "M", "G", "T"],
            maxLength: MenuBarTextLayout.slotLength(for: .disk)
        )
    }

    private func formatMenuPower(_ watts: Double) -> String {
        formatCompactMenuValue(
            watts,
            units: ["W", "K"],
            maxLength: MenuBarTextLayout.slotLength(for: .power)
        )
    }

    private func formatMenuTemperature(_ celsius: Double) -> String {
        "\(Int(celsius.rounded()))C"
    }

    private func formatMenuThermalPressure(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "OK"
        case .fair:
            return "FA"
        case .serious:
            return "SR"
        case .critical:
            return "CR"
        @unknown default:
            return "?"
        }
    }

    private func formatMenuFanSpeed(_ rpm: Double) -> String {
        formatCompactMenuValue(
            rpm,
            units: ["R", "K"],
            maxLength: MenuBarTextLayout.slotLength(for: .fans)
        )
    }

    private func formatPercent(_ value: Double) -> String {
        String(format: "%.1f%%", value)
    }

    private func formatCompactMenuValue(_ value: Double, units: [String], maxLength: Int) -> String {
        guard value > 0 else { return "0\(units[0])" }

        var scaledValue = value
        var unitIndex = 0
        while scaledValue >= 1_000, unitIndex < units.count - 1 {
            scaledValue /= 1_000
            unitIndex += 1
        }

        let number: String
        if scaledValue < 10, scaledValue.rounded() != scaledValue {
            number = String(format: "%.1f", scaledValue)
        } else {
            number = String(format: "%.0f", scaledValue)
        }

        let compactNumber = number.hasSuffix(".0") ? String(number.dropLast(2)) : number
        let compactValue = "\(compactNumber)\(units[unitIndex])"
        guard compactValue.count <= maxLength else {
            return "\(Int(scaledValue.rounded()))\(units[unitIndex])"
        }
        return compactValue
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

    nonisolated static func thermalPressureText(for state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal:
            return "Nominal"
        case .fair:
            return "Fair"
        case .serious:
            return "Serious"
        case .critical:
            return "Critical"
        @unknown default:
            return ""
        }
    }
}
