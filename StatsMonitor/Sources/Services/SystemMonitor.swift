import Foundation
import Observation
import Util

@Observable
@MainActor
final class SystemMonitor {
    private typealias HistoryBuffers = (
        cpu: RingBuffer<Double>,
        gpu: RingBuffer<Double>,
        memory: RingBuffer<Double>,
        disk: RingBuffer<Double>,
        diskRead: RingBuffer<Double>,
        diskWrite: RingBuffer<Double>,
        networkIn: RingBuffer<Double>,
        networkOut: RingBuffer<Double>,
        battery: RingBuffer<Double>,
        cpuTemp: RingBuffer<Double>,
        power: RingBuffer<Double>
    )

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
    private(set) var cpuTempHistory:    RingBuffer<Double>
    private(set) var powerHistory:      RingBuffer<Double>

    private var cpuMonitor      = CPUMonitor()
    private var gpuMonitor      = GPUMonitor()
    private var aneMonitor      = ANEMonitor()
    private var memoryMonitor   = MemoryMonitor()
    private var diskMonitor     = DiskMonitor()
    private var networkMonitor  = NetworkMonitor()
    private var processMonitor  = ProcessMonitor()
    private var powerMonitor    = PowerMonitor()

    private let smcClient                         = SMCClient()
    private var batteryMonitor                    = BatteryMonitor()
    private var thermalMonitor: ThermalMonitor
    private var fanMonitor: FanMonitor

    private var networkProcPrev: [String: NetworkProcessMonitor.Snapshot] = [:]
    private var isProcessPollInFlight = false

    private var timer: Timer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let historyBuffers = Self.makeHistoryBuffers(capacity: settings.historyCapacity)
        cpuHistory        = historyBuffers.cpu
        gpuHistory        = historyBuffers.gpu
        memoryHistory     = historyBuffers.memory
        diskHistory       = historyBuffers.disk
        diskReadHistory   = historyBuffers.diskRead
        diskWriteHistory  = historyBuffers.diskWrite
        networkInHistory  = historyBuffers.networkIn
        networkOutHistory = historyBuffers.networkOut
        batteryHistory    = historyBuffers.battery
        cpuTempHistory    = historyBuffers.cpuTemp
        powerHistory      = historyBuffers.power
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
        let power   = powerMonitor.sample(intervalSeconds: settings.pollInterval)
        let count   = settings.processCount

        stats = SystemStats(
            cpu:                 cpu,
            gpu:                 gpu,
            memory:              memory,
            disk:                disk,
            network:             network,
            battery:             battery,
            thermal:             thermal,
            power:               power,
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
        if let pwr = power {
            powerHistory.append(pwr.totalMilliWatts / 1000)   // store as Watts
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
        applyHistoryBuffers(Self.makeHistoryBuffers(capacity: cap))
    }

    private func applyHistoryBuffers(_ historyBuffers: HistoryBuffers) {
        cpuHistory        = historyBuffers.cpu
        gpuHistory        = historyBuffers.gpu
        memoryHistory     = historyBuffers.memory
        diskHistory       = historyBuffers.disk
        diskReadHistory   = historyBuffers.diskRead
        diskWriteHistory  = historyBuffers.diskWrite
        networkInHistory  = historyBuffers.networkIn
        networkOutHistory = historyBuffers.networkOut
        batteryHistory    = historyBuffers.battery
        cpuTempHistory    = historyBuffers.cpuTemp
        powerHistory      = historyBuffers.power
    }

    private static func makeHistoryBuffers(capacity: Int) -> HistoryBuffers {
        (
            cpu: RingBuffer<Double>(capacity: capacity),
            gpu: RingBuffer<Double>(capacity: capacity),
            memory: RingBuffer<Double>(capacity: capacity),
            disk: RingBuffer<Double>(capacity: capacity),
            diskRead: RingBuffer<Double>(capacity: capacity),
            diskWrite: RingBuffer<Double>(capacity: capacity),
            networkIn: RingBuffer<Double>(capacity: capacity),
            networkOut: RingBuffer<Double>(capacity: capacity),
            battery: RingBuffer<Double>(capacity: capacity),
            cpuTemp: RingBuffer<Double>(capacity: capacity),
            power: RingBuffer<Double>(capacity: capacity)
        )
    }
}
