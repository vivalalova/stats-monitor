import Foundation
import Observation
import Util

@Observable
@MainActor
final class StatsViewModel {
    let settings: AppSettings
    let monitor: SystemMonitor

    init() {
        let s = AppSettings()
        self.settings = s
        self.monitor = SystemMonitor(settings: s)
        monitor.start()
        observePollInterval()
        observeHistoryCapacity()
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
    var cpuHistory: [Double] { Array(monitor.cpuHistory) }

    // MARK: - GPU

    var gpuPercent: String { String(format: "%.1f%%", monitor.stats.gpu.used) }
    var gpuRenderPercent: String { String(format: "%.1f%%", monitor.stats.gpu.renderUtilization) }
    var gpuEngines: [String: Double] { monitor.stats.gpu.engines }
    var gpuHistory: [Double] { Array(monitor.gpuHistory) }
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
    var memoryHistory: [Double] { Array(monitor.memoryHistory) }
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
    var diskHistory: [Double]      { Array(monitor.diskHistory) }
    var diskReadHistory: [Double]  { Array(monitor.diskReadHistory) }
    var diskWriteHistory: [Double] { Array(monitor.diskWriteHistory) }

    // MARK: - Network

    var networkIn: String { formatThroughput(monitor.stats.network.bytesInPerSec) }
    var networkOut: String { formatThroughput(monitor.stats.network.bytesOutPerSec) }
    var networkInHistory: [Double]  { Array(monitor.networkInHistory) }
    var networkOutHistory: [Double] { Array(monitor.networkOutHistory) }

    // MARK: - Processes

    var topCPUProcesses: [ProcInfo] { monitor.stats.topCPUProcesses }
    var topMemoryProcesses: [ProcInfo] { monitor.stats.topMemoryProcesses }
    var topDiskProcesses: [ProcInfo] { monitor.stats.topDiskProcesses }
    var topNetworkProcesses: [ProcInfo] { monitor.stats.topNetworkProcesses }

    func formatProcessCPU(_ percent: Double) -> String { String(format: "%.1f%%", percent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }
    func formatProcessDisk(_ bps: Double) -> String { formatThroughput(bps) }
    func formatProcessNetwork(_ bps: Double) -> String { formatThroughput(bps) }

    // MARK: - Lifecycle

    func start() { monitor.start() }
    func stop()  { monitor.stop() }

}
