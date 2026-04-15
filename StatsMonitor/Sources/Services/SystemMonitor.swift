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
        gpuTemp: RingBuffer<Double>,
        fanAverage: RingBuffer<Double>,
        power: RingBuffer<Double>
    )

    var stats = SystemStats() {
        didSet {
            guard !isSkippingStatsSync else { return }
            syncLatestValues(from: stats)
        }
    }

    var cpuLatest = 0.0 {
        didSet { appendLatest(cpuLatest, to: &cpuHistory) }
    }
    var gpuLatest = 0.0 {
        didSet { appendLatest(gpuLatest, to: &gpuHistory) }
    }
    var memoryLatest = 0.0 {
        didSet { appendLatest(memoryLatest, to: &memoryHistory) }
    }
    var diskLatest = 0.0 {
        didSet { appendLatest(diskLatest, to: &diskHistory) }
    }
    var diskReadLatest = 0.0 {
        didSet { appendLatest(diskReadLatest, to: &diskReadHistory) }
    }
    var diskWriteLatest = 0.0 {
        didSet { appendLatest(diskWriteLatest, to: &diskWriteHistory) }
    }
    var networkInLatest = 0.0 {
        didSet { appendLatest(networkInLatest, to: &networkInHistory) }
    }
    var networkOutLatest = 0.0 {
        didSet { appendLatest(networkOutLatest, to: &networkOutHistory) }
    }
    var batteryLatest: Double? = nil {
        didSet { appendLatest(batteryLatest, to: &batteryHistory) }
    }
    var cpuTempLatest: Double? = nil {
        didSet { appendLatest(cpuTempLatest, to: &cpuTempHistory) }
    }
    var gpuTempLatest: Double? = nil {
        didSet { appendLatest(gpuTempLatest, to: &gpuTempHistory) }
    }
    var fanAverageLatest: Double? = nil {
        didSet { appendLatest(fanAverageLatest, to: &fanAverageHistory) }
    }
    var powerLatest: Double? = nil {
        didSet { appendLatest(powerLatest, to: &powerHistory) }
    }

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
    private(set) var gpuTempHistory:    RingBuffer<Double>
    private(set) var fanAverageHistory: RingBuffer<Double>
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
    private var isSyncingLatestValues = false
    private var isSkippingStatsSync = false
    private var isRunning = false

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
        gpuTempHistory    = historyBuffers.gpuTemp
        fanAverageHistory = historyBuffers.fanAverage
        powerHistory      = historyBuffers.power
        // SMC-dependent monitors share the same connection
        thermalMonitor = ThermalMonitor(smc: smcClient)
        fanMonitor     = FanMonitor(smc: smcClient)
        syncLatestValues(from: stats)
        observePollInterval()
        observeHistoryCapacity()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        poll()
        scheduleTimer()
    }

    func stop() {
        isRunning = false
        timer?.invalidate()
        timer = nil
    }

    /// pollInterval 變更時呼叫：invalidate 現有 timer 並以新 interval 重建。
    func restartTimer() {
        guard isRunning else { return }
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

        let newStats = SystemStats(
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
        isSkippingStatsSync = true
        stats = newStats
        isSkippingStatsSync = false
        recordLatestValues(from: newStats)

        pollNetworkProcesses(processCount: count)
        pollProcesses(processCount: count)
    }

    private func observePollInterval() {
        withObservationTracking {
            _ = settings.pollInterval
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.restartTimer()
                self.observePollInterval()
            }
        }
    }

    private func observeHistoryCapacity() {
        withObservationTracking {
            _ = settings.historyCapacity
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.resetHistories()
                self.observeHistoryCapacity()
            }
        }
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
        gpuTempHistory    = historyBuffers.gpuTemp
        fanAverageHistory = historyBuffers.fanAverage
        powerHistory      = historyBuffers.power
    }

    private func syncLatestValues(from stats: SystemStats) {
        isSyncingLatestValues = true
        defer { isSyncingLatestValues = false }
        assignLatestValues(from: stats)
    }

    private func recordLatestValues(from stats: SystemStats) {
        assignLatestValues(from: stats)
    }

    private func assignLatestValues(from stats: SystemStats) {
        cpuLatest = stats.cpu.used
        gpuLatest = stats.gpu.used
        memoryLatest = stats.memory.usedFraction * 100
        diskLatest = stats.disk.usedFraction * 100
        diskReadLatest = stats.disk.readBPS
        diskWriteLatest = stats.disk.writeBPS
        networkInLatest = stats.network.bytesInPerSec
        networkOutLatest = stats.network.bytesOutPerSec
        batteryLatest = stats.battery?.percentage
        cpuTempLatest = stats.thermal?.cpuTemperature
        gpuTempLatest = stats.thermal?.gpuTemperature
        fanAverageLatest = stats.fans.isEmpty
            ? nil
            : stats.fans.map(\.currentRPM).reduce(0, +) / Double(stats.fans.count)
        powerLatest = stats.power.map { $0.totalMilliWatts / 1000 }
    }

    private func appendLatest(_ value: Double, to history: inout RingBuffer<Double>) {
        guard !isSyncingLatestValues else { return }
        history.append(value)
    }

    private func appendLatest(_ value: Double?, to history: inout RingBuffer<Double>) {
        guard !isSyncingLatestValues, let value else { return }
        history.append(value)
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
            gpuTemp: RingBuffer<Double>(capacity: capacity),
            fanAverage: RingBuffer<Double>(capacity: capacity),
            power: RingBuffer<Double>(capacity: capacity)
        )
    }
}
