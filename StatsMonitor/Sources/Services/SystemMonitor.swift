import Foundation
import Observation
import Util

@Observable
@MainActor
final class SystemMonitor {
    var stats = SystemStats()

    private(set) var cpuHistory:        RingBuffer<Double>
    private(set) var gpuHistory:        RingBuffer<Double>
    private(set) var memoryHistory:     RingBuffer<Double>
    private(set) var diskHistory:       RingBuffer<Double>
    private(set) var diskReadHistory:   RingBuffer<Double>
    private(set) var diskWriteHistory:  RingBuffer<Double>
    private(set) var networkInHistory:  RingBuffer<Double>
    private(set) var networkOutHistory: RingBuffer<Double>
    private(set) var batteryHistory:    RingBuffer<Double>

    private var cpuMonitor      = CPUMonitor()
    private var gpuMonitor      = GPUMonitor()
    private var aneMonitor      = ANEMonitor()
    private var memoryMonitor   = MemoryMonitor()
    private var diskMonitor     = DiskMonitor()
    private var networkMonitor  = NetworkMonitor()
    private var processMonitor  = ProcessMonitor()

    private let smcClient                         = SMCClient()
    private var batteryMonitor                    = BatteryMonitor()
    private var thermalMonitor: ThermalMonitor
    private var fanMonitor: FanMonitor

    private(set) var cpuTempHistory: RingBuffer<Double>

    private var networkProcPrev: [String: NetworkProcessMonitor.Snapshot] = [:]
    private var isProcessPollInFlight = false

    private var timer: Timer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let cap = settings.historyCapacity
        cpuHistory        = RingBuffer<Double>(capacity: cap)
        gpuHistory        = RingBuffer<Double>(capacity: cap)
        memoryHistory     = RingBuffer<Double>(capacity: cap)
        diskHistory       = RingBuffer<Double>(capacity: cap)
        diskReadHistory   = RingBuffer<Double>(capacity: cap)
        diskWriteHistory  = RingBuffer<Double>(capacity: cap)
        networkInHistory  = RingBuffer<Double>(capacity: cap)
        networkOutHistory = RingBuffer<Double>(capacity: cap)
        batteryHistory    = RingBuffer<Double>(capacity: cap)
        cpuTempHistory    = RingBuffer<Double>(capacity: cap)
        // SMC-dependent monitors share the same connection
        thermalMonitor = ThermalMonitor(smc: smcClient)
        fanMonitor     = FanMonitor(smc: smcClient)
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
        let battery = batteryMonitor.sample()
        let thermal = thermalMonitor.sample()
        let fans    = fanMonitor.sample()
        let count   = settings.processCount

        stats = SystemStats(
            cpu:                 cpu,
            gpu:                 gpu,
            memory:              memory,
            disk:                disk,
            network:             network,
            battery:             battery,
            thermal:             thermal,
            fans:                fans,
            topCPUProcesses:     stats.topCPUProcesses,
            topMemoryProcesses:  stats.topMemoryProcesses,
            topDiskProcesses:    stats.topDiskProcesses,
            topNetworkProcesses: stats.topNetworkProcesses
        )

        cpuHistory.append(cpu.used)
        gpuHistory.append(gpu.used)
        memoryHistory.append(memory.usedFraction * 100)
        diskHistory.append(disk.usedFraction * 100)
        diskReadHistory.append(disk.readBPS)
        diskWriteHistory.append(disk.writeBPS)
        networkInHistory.append(network.bytesInPerSec)
        networkOutHistory.append(network.bytesOutPerSec)
        if let pct = battery?.percentage {
            batteryHistory.append(pct)
        }
        if let temp = thermal?.cpuTemperature {
            cpuTempHistory.append(temp)
        }

        pollNetworkProcesses(processCount: count)
        pollProcesses(processCount: count)
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

    private func pollProcesses(processCount: Int) {
        guard !isProcessPollInFlight else { return }
        isProcessPollInFlight = true
        let prevMonitor = processMonitor
        Task { [weak self] in
            guard let self else { return }
            let (result, updated) = await Task.detached(priority: .utility) {
                var monitor = prevMonitor
                let result = monitor.sample(processCount: processCount)
                return (result, monitor)
            }.value
            self.isProcessPollInFlight = false
            self.processMonitor = updated
            self.stats.topCPUProcesses    = result.cpuTop
            self.stats.topMemoryProcesses = result.memoryTop
            self.stats.topDiskProcesses   = result.diskTop
        }
    }

    /// Recreates all history ring buffers with the current historyCapacity.
    /// Call when settings.historyCapacity changes.
    func resetHistories() {
        let cap = settings.historyCapacity
        guard cap != cpuHistory.capacity else { return }
        cpuHistory        = RingBuffer<Double>(capacity: cap)
        gpuHistory        = RingBuffer<Double>(capacity: cap)
        memoryHistory     = RingBuffer<Double>(capacity: cap)
        diskHistory       = RingBuffer<Double>(capacity: cap)
        diskReadHistory   = RingBuffer<Double>(capacity: cap)
        diskWriteHistory  = RingBuffer<Double>(capacity: cap)
        networkInHistory  = RingBuffer<Double>(capacity: cap)
        networkOutHistory = RingBuffer<Double>(capacity: cap)
        batteryHistory    = RingBuffer<Double>(capacity: cap)
        cpuTempHistory    = RingBuffer<Double>(capacity: cap)
    }
}
