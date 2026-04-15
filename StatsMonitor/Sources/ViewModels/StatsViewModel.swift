import Foundation
import Observation
import Util

@Observable
@MainActor
final class StatsViewModel {
    let settings: AppSettings
    let monitor: SystemMonitor

    init() {
        let settings = AppSettings()
        self.settings = settings
        self.monitor = SystemMonitor(settings: settings)
        startMonitoringIfNeeded()
    }

    init(settings: AppSettings, monitor: SystemMonitor, startMonitoring: Bool) {
        self.settings = settings
        self.monitor = monitor
        guard startMonitoring else { return }
        startMonitoringIfNeeded()
    }

    // MARK: - Settings observation

    /// 當 pollInterval 變更時，重建 timer。
    private func observePollInterval() {
        withObservationTracking {
            _ = settings.pollInterval
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.monitor.restartTimer()
                self.observePollInterval()
            }
        }
    }

    /// 當 historyCapacity 變更時，重建所有 history ring buffers。
    private func observeHistoryCapacity() {
        withObservationTracking {
            _ = settings.historyCapacity
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.monitor.resetHistories()
                self.observeHistoryCapacity()
            }
        }
    }

    // MARK: - CPU

    var cpuFraction:    Double { monitor.stats.cpu.used / 100 }
    var gpuFraction:    Double { monitor.stats.gpu.used / 100 }
    var memoryFraction: Double { monitor.stats.memory.usedFraction }
    var diskFraction:   Double { monitor.stats.disk.usedFraction }

    var cpuPercent: String { String(format: "%.1f%%", monitor.stats.cpu.used) }
    var cpuUserPercent: String { String(format: "%.1f%%", monitor.stats.cpu.user) }
    var cpuSystemPercent: String { String(format: "%.1f%%", monitor.stats.cpu.system) }
    var cpuPerCore: [Double] { monitor.stats.cpu.perCore }
    var cpuCoreFrequencies: [CPUCoreFrequency] { monitor.stats.cpu.coreFrequencies }
    var cpuHistory: [Double] { padded(monitor.cpuHistory) }

    // MARK: - GPU

    var gpuPercent: String { String(format: "%.1f%%", monitor.stats.gpu.used) }
    var gpuRenderPercent: String { String(format: "%.1f%%", monitor.stats.gpu.renderUtilization) }
    var gpuEngines: [String: Double] { monitor.stats.gpu.engines }
    var gpuHistory: [Double] { padded(monitor.gpuHistory) }
    var gpuVramUsed: UInt64 { monitor.stats.gpu.vramUsed }
    var gpuVramUsedStr: String { formatBytes(monitor.stats.gpu.vramUsed) }
    var anePowerMilliWatts: Double { monitor.stats.gpu.anePowerMilliWatts }
    var anePowerStr: String {
        let mw = monitor.stats.gpu.anePowerMilliWatts
        return mw >= 1000 ? String(format: "%.1f W", mw / 1000) : String(format: "%.0f mW", mw)
    }

    // MARK: - Memory

    var memoryUsed: String { formatBytes(monitor.stats.memory.used) }
    var memoryTotal: String { formatBytes(monitor.stats.memory.total) }
    var memoryPercent: String { String(format: "%.1f%%", monitor.stats.memory.usedFraction * 100) }
    var memoryActive: String { formatBytes(monitor.stats.memory.active) }
    var memoryWired: String { formatBytes(monitor.stats.memory.wired) }
    var memoryCompressed: String { formatBytes(monitor.stats.memory.compressed) }
    var memoryHistory: [Double] { padded(monitor.memoryHistory) }
    var memoryLabelText: String {
        "\(formatBytesCompact(monitor.stats.memory.used))/\(formatBytesCompact(monitor.stats.memory.total))"
    }

    // MARK: - Disk

    var diskUsed: String { formatBytes(monitor.stats.disk.used) }
    var diskFree: String { formatBytes(monitor.stats.disk.total - monitor.stats.disk.used) }
    var diskTotal: String { formatBytes(monitor.stats.disk.total) }
    var diskPercent: String { String(format: "%.1f%%", monitor.stats.disk.usedFraction * 100) }
    var diskRead: String  { formatThroughput(monitor.stats.disk.readBPS) }
    var diskWrite: String { formatThroughput(monitor.stats.disk.writeBPS) }
    var diskHistory: [Double]      { padded(monitor.diskHistory) }
    var diskReadHistory: [Double]  { padded(monitor.diskReadHistory) }
    var diskWriteHistory: [Double] { padded(monitor.diskWriteHistory) }

    // MARK: - Network

    var networkIn: String { formatThroughput(monitor.stats.network.bytesInPerSec) }
    var networkOut: String { formatThroughput(monitor.stats.network.bytesOutPerSec) }
    var networkInHistory: [Double]  { padded(monitor.networkInHistory) }
    var networkOutHistory: [Double] { padded(monitor.networkOutHistory) }

    // MARK: - Processes

    var topCPUProcesses: [ProcInfo] { monitor.stats.topCPUProcesses }
    var topMemoryProcesses: [ProcInfo] { monitor.stats.topMemoryProcesses }
    var topDiskProcesses: [ProcInfo] { monitor.stats.topDiskProcesses }
    var topNetworkProcesses: [ProcInfo] { monitor.stats.topNetworkProcesses }

    func formatProcessCPU(_ percent: Double) -> String { String(format: "%.1f%%", percent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }
    func formatProcessDisk(_ bps: Double) -> String { formatThroughput(bps) }
    func formatProcessNetwork(_ bps: Double) -> String { formatThroughput(bps) }

    // MARK: - Power

    var power: PowerUsage?   { monitor.stats.power }
    var hasPower: Bool       { monitor.stats.power != nil }
    var powerHistory: [Double] { padded(monitor.powerHistory) }
    var powerStr: String {
        guard let p = monitor.stats.power else { return "N/A" }
        return String(format: "%.1f W", p.totalWatts)
    }

    // MARK: - Battery

    var battery: BatteryUsage?  { monitor.stats.battery }
    var hasBattery: Bool        { monitor.stats.battery != nil }
    var batteryHistory: [Double] { padded(monitor.batteryHistory) }

    var batteryPercent: String {
        guard let b = monitor.stats.battery else { return "N/A" }
        return String(format: "%.0f%%", b.percentage)
    }
    var batteryFraction: Double {
        (monitor.stats.battery?.percentage ?? 0) / 100.0
    }
    var batteryStatus: String {
        guard let b = monitor.stats.battery else { return "" }
        if b.isCharging { return "Charging" }
        if b.isPluggedIn { return "Plugged In" }
        if let mins = b.timeRemaining {
            let h = mins / 60, m = mins % 60
            return h > 0 ? "\(h)h \(m)m" : "\(m)m"
        }
        return "On Battery"
    }
    var batteryHealth: String {
        guard let b = monitor.stats.battery else { return "" }
        return String(format: "%.0f%%", b.health)
    }
    var batteryCycles: String {
        guard let b = monitor.stats.battery else { return "" }
        return "\(b.cycleCount) cycles"
    }

    // MARK: - Thermal

    var thermal: ThermalUsage?  { monitor.stats.thermal }
    var hasThermal: Bool        { monitor.stats.thermal != nil }

    var cpuTempStr: String {
        guard let t = monitor.stats.thermal else { return "N/A" }
        return String(format: "%.1f°C", t.cpuTemperature)
    }
    var gpuTempStr: String {
        guard let temp = monitor.stats.thermal?.gpuTemperature else { return "—" }
        return String(format: "%.1f°C", temp)
    }
    var cpuTempHistory: [Double] { padded(monitor.cpuTempHistory) }

    // MARK: - Fan

    var fans: [FanUsage]    { monitor.stats.fans }
    var hasFans: Bool       { !monitor.stats.fans.isEmpty }

    func fanRPMStr(_ fan: FanUsage) -> String {
        String(format: "%.0f RPM", fan.currentRPM)
    }
    var fansSummary: String {
        let f = monitor.stats.fans
        guard !f.isEmpty else { return "No fans" }
        if f.count == 1 { return String(format: "%.0f RPM", f[0].currentRPM) }
        let avg = f.map(\.currentRPM).reduce(0, +) / Double(f.count)
        return String(format: "%.0f RPM avg", avg)
    }

    // MARK: - Lifecycle

    func start() { monitor.start() }
    func stop()  { monitor.stop() }

    // MARK: - Private Helpers

    private func startMonitoringIfNeeded() {
        monitor.start()
        observePollInterval()
        observeHistoryCapacity()
    }

    /// Pads the history to full capacity by prepending the first known value.
    /// Ensures charts always render at full width from the first data point.
    private func padded(_ buf: RingBuffer<Double>) -> [Double] {
        let data = Array(buf)
        guard !data.isEmpty, data.count < buf.capacity else { return data }
        return Array(repeating: data[0], count: buf.capacity - data.count) + data
    }

}
