import Foundation
import Observation

@Observable
@MainActor
final class StatsViewModel {
    let monitor = SystemMonitor()

    init() {
        monitor.start()
    }

    // MARK: - CPU

    var cpuPercent: String { String(format: "%.1f%%", monitor.stats.cpu.used) }
    var cpuUserPercent: String { String(format: "%.1f%%", monitor.stats.cpu.user) }
    var cpuSystemPercent: String { String(format: "%.1f%%", monitor.stats.cpu.system) }
    var cpuPerCore: [Double] { monitor.stats.cpu.perCore }
    var cpuCoreFrequencies: [CPUCoreFrequency] { monitor.stats.cpu.coreFrequencies }
    var cpuHistory: [Double] { monitor.cpuHistory }

    // MARK: - GPU

    var gpuPercent: String { String(format: "%.1f%%", monitor.stats.gpu.used) }
    var gpuRenderPercent: String { String(format: "%.1f%%", monitor.stats.gpu.renderUtilization) }
    var gpuEngines: [String: Double] { monitor.stats.gpu.engines }
    var gpuHistory: [Double] { monitor.gpuHistory }

    // MARK: - Memory

    var memoryUsed: String { formatBytes(monitor.stats.memory.used) }
    var memoryTotal: String { formatBytes(monitor.stats.memory.total) }
    var memoryPercent: String { String(format: "%.1f%%", monitor.stats.memory.usedFraction * 100) }
    var memoryActive: String { formatBytes(monitor.stats.memory.active) }
    var memoryWired: String { formatBytes(monitor.stats.memory.wired) }
    var memoryCompressed: String { formatBytes(monitor.stats.memory.compressed) }
    var memoryHistory: [Double] { monitor.memoryHistory }
    var memoryLabelText: String {
        "\(formatBytesCompact(monitor.stats.memory.used))/\(formatBytesCompact(monitor.stats.memory.total))"
    }

    // MARK: - Disk

    var diskUsed: String { formatBytes(monitor.stats.disk.used) }
    var diskFree: String { formatBytes(monitor.stats.disk.total - monitor.stats.disk.used) }
    var diskTotal: String { formatBytes(monitor.stats.disk.total) }
    var diskPercent: String { String(format: "%.1f%%", monitor.stats.disk.usedFraction * 100) }
    var diskHistory: [Double] { monitor.diskHistory }

    // MARK: - Network

    var networkIn: String { formatThroughput(monitor.stats.network.bytesInPerSec) }
    var networkOut: String { formatThroughput(monitor.stats.network.bytesOutPerSec) }
    var networkInHistory: [Double] { monitor.networkInHistory }
    var networkOutHistory: [Double] { monitor.networkOutHistory }

    // MARK: - Processes

    var topCPUProcesses: [ProcInfo] { monitor.stats.topCPUProcesses }
    var topMemoryProcesses: [ProcInfo] { monitor.stats.topMemoryProcesses }

    func formatProcessCPU(_ percent: Double) -> String { String(format: "%.1f%%", percent) }
    func formatProcessMemory(_ bytes: UInt64) -> String { formatBytes(bytes) }

    // MARK: - Lifecycle

    func start() { monitor.start() }
    func stop()  { monitor.stop() }

    // MARK: - Formatters

    private func formatBytesCompact(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1fG", gb) }
        let mb = Double(bytes) / 1_048_576
        return String(format: "%.0fM", mb)
    }

    private func formatBytes(_ bytes: UInt64) -> String {
        let gb = Double(bytes) / 1_073_741_824
        if gb >= 1 { return String(format: "%.1f GB", gb) }
        let mb = Double(bytes) / 1_048_576
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        return String(format: "%.0f KB", Double(bytes) / 1_024)
    }

    private func formatThroughput(_ bytesPerSec: Double) -> String {
        let mb = bytesPerSec / 1_048_576
        if mb >= 1 { return String(format: "%.1f MB/s", mb) }
        let kb = bytesPerSec / 1_024
        return String(format: "%.0f KB/s", kb)
    }
}
