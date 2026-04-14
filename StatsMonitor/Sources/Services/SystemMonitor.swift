import Foundation
import Observation

@Observable
@MainActor
final class SystemMonitor {
    private(set) var stats = SystemStats()

    private(set) var cpuHistory:        [Double] = []
    private(set) var gpuHistory:        [Double] = []
    private(set) var memoryHistory:     [Double] = []
    private(set) var diskHistory:       [Double] = []
    private(set) var diskReadHistory:   [Double] = []
    private(set) var diskWriteHistory:  [Double] = []
    private(set) var networkInHistory:  [Double] = []
    private(set) var networkOutHistory: [Double] = []

    private var cpuMonitor      = CPUMonitor()
    private var gpuMonitor      = GPUMonitor()
    private var aneMonitor      = ANEMonitor()
    private var memoryMonitor   = MemoryMonitor()
    private var diskMonitor     = DiskMonitor()
    private var networkMonitor  = NetworkMonitor()
    private var processMonitor  = ProcessMonitor()

    private var networkProcPrev: [String: NetworkProcessMonitor.Snapshot] = [:]

    private var timer: Timer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
    }

    func start() {
        poll()
        scheduleTimer()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// pollInterval 變更時呼叫：invalidate 現有 timer 並以新 interval 重建。
    func restartTimer() {
        timer?.invalidate()
        timer = nil
        scheduleTimer()
    }

    private func scheduleTimer() {
        let interval = settings.pollInterval
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    private func poll() {
        let cpu     = cpuMonitor.sample()
        var gpu     = gpuMonitor.sample()
        gpu.anePowerMilliWatts = aneMonitor.sample(intervalSeconds: settings.pollInterval)
        let memory  = memoryMonitor.sample()
        let disk    = diskMonitor.sample()
        let network = networkMonitor.sample()
        let count   = settings.processCount
        let (cpuProcs, memProcs, diskProcs) = processMonitor.sample(processCount: count)

        stats = SystemStats(
            cpu:                 cpu,
            gpu:                 gpu,
            memory:              memory,
            disk:                disk,
            network:             network,
            topCPUProcesses:     cpuProcs,
            topMemoryProcesses:  memProcs,
            topDiskProcesses:    diskProcs,
            topNetworkProcesses: stats.topNetworkProcesses
        )

        let capacity = settings.historyCapacity
        append(cpu.used,                  to: &cpuHistory,        capacity: capacity)
        append(gpu.used,                  to: &gpuHistory,        capacity: capacity)
        append(memory.usedFraction * 100, to: &memoryHistory,     capacity: capacity)
        append(disk.usedFraction * 100,   to: &diskHistory,       capacity: capacity)
        append(disk.readBPS,              to: &diskReadHistory,   capacity: capacity)
        append(disk.writeBPS,             to: &diskWriteHistory,  capacity: capacity)
        append(network.bytesInPerSec,     to: &networkInHistory,  capacity: capacity)
        append(network.bytesOutPerSec,    to: &networkOutHistory, capacity: capacity)

        pollNetworkProcesses(processCount: count)
    }

    private func pollNetworkProcesses(processCount: Int) {
        let prev = networkProcPrev
        Task { [weak self] in
            guard let self else { return }
            let (procs, updated) = await Task.detached(priority: .utility) {
                NetworkProcessMonitor.run(previous: prev, processCount: processCount)
            }.value
            self.networkProcPrev = updated
            self.stats.topNetworkProcesses = procs
        }
    }

    private func append(_ value: Double, to buffer: inout [Double], capacity: Int) {
        buffer.append(value)
        if buffer.count > capacity { buffer.removeFirst() }
    }
}
