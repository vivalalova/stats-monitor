import Foundation
import Observation

@Observable
@MainActor
final class SystemMonitor {
    private typealias SampleStores = (
        cpu: MetricHistory<CPUUsage>,
        gpu: MetricHistory<GPUUsage>,
        memory: MetricHistory<MemoryUsage>,
        disk: MetricHistory<DiskUsage>,
        network: MetricHistory<NetworkUsage>,
        battery: MetricHistory<BatteryUsage>,
        thermal: MetricHistory<ThermalUsage>,
        power: MetricHistory<PowerUsage>,
        fans: MetricHistory<[FanUsage]>
    )

    private(set) var cpuSamples: MetricHistory<CPUUsage>
    private(set) var gpuSamples: MetricHistory<GPUUsage>
    private(set) var memorySamples: MetricHistory<MemoryUsage>
    private(set) var diskSamples: MetricHistory<DiskUsage>
    private(set) var networkSamples: MetricHistory<NetworkUsage>
    private(set) var batterySamples: MetricHistory<BatteryUsage>
    private(set) var thermalSamples: MetricHistory<ThermalUsage>
    private(set) var powerSamples: MetricHistory<PowerUsage>
    private(set) var fansSamples: MetricHistory<[FanUsage]>
    private(set) var thermalPressureState: ProcessInfo.ThermalState? = nil

    var topCPUProcesses: [ProcInfo] = []
    var topGPUProcesses: [GPUProcessInfo] = []
    var topMemoryProcesses: [ProcInfo] = []
    var topDiskProcesses: [ProcInfo] = []
    var topNetworkProcesses: [ProcInfo] = []
    var topPowerProcesses: [ProcInfo] = []

    private var cpuMonitor          = CPUMonitor()
    private var gpuMonitor          = GPUMonitor()
    private var gpuFrequencyMonitor = GPUFrequencyMonitor()
    private var aneMonitor          = ANEMonitor()
    private var memoryMonitor       = MemoryMonitor()
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
    private var isRunning = false

    private var timer: Timer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        let sampleStores = Self.makeSampleStores(capacity: settings.historyCapacity)
        cpuSamples = sampleStores.cpu
        gpuSamples = sampleStores.gpu
        memorySamples = sampleStores.memory
        diskSamples = sampleStores.disk
        networkSamples = sampleStores.network
        batterySamples = sampleStores.battery
        thermalSamples = sampleStores.thermal
        powerSamples = sampleStores.power
        fansSamples = sampleStores.fans
        // SMC-dependent monitors share the same connection
        thermalMonitor = ThermalMonitor(smc: smcClient)
        fanMonitor     = FanMonitor(smc: smcClient)
        observePollInterval()
        observeHistoryCapacity()
    }

    @discardableResult
    func start() -> Self {
        guard !isRunning else { return self }
        isRunning = true
        poll()
        scheduleTimer()
        return self
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
        gpu.frequency = gpuFrequencyMonitor.sample()
        let memory  = memoryMonitor.sample()
        let disk    = diskMonitor.sample()
        let network = networkMonitor.sample()
        let battery = batteryMonitor.sample()
        let thermal = thermalMonitor.sample()
        let thermalPressureState = ProcessInfo.processInfo.thermalState
        let fans    = fanMonitor.sample()
        let power   = powerMonitor.sample(intervalSeconds: settings.pollInterval)
        let count   = settings.processCount

        record(cpu: cpu)
        record(gpu: gpu)
        record(memory: memory)
        record(disk: disk)
        record(network: network)
        record(battery: battery)
        record(thermal: thermal)
        record(thermalPressureState: thermalPressureState)
        record(power: power)
        record(fans: fans)
        topGPUProcesses = gpuMonitor.sampleTopApps(intervalSeconds: settings.pollInterval, processCount: count)

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
            self.topNetworkProcesses = procs
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
            self.topCPUProcesses    = result.cpuTop
            self.topMemoryProcesses = result.memoryTop
            self.topDiskProcesses   = result.diskTop
            self.topPowerProcesses  = result.powerTop
        }
    }

    /// Recreates all history ring buffers with the current historyCapacity.
    /// Call when settings.historyCapacity changes.
    func resetHistories() {
        let cap = settings.historyCapacity
        guard cap != cpuSamples.capacity else { return }
        applySampleStores(Self.makeSampleStores(capacity: cap))
    }

    func record(cpu sample: CPUUsage) {
        cpuSamples.record(sample)
    }

    func record(gpu sample: GPUUsage) {
        gpuSamples.record(sample)
    }

    func record(memory sample: MemoryUsage) {
        memorySamples.record(sample)
    }

    func record(disk sample: DiskUsage) {
        diskSamples.record(sample)
    }

    func record(network sample: NetworkUsage) {
        networkSamples.record(sample)
    }

    func record(battery sample: BatteryUsage?) {
        guard let sample else { return }
        batterySamples.record(sample)
    }

    func record(thermal sample: ThermalUsage?) {
        guard let sample else { return }
        thermalSamples.record(sample)
    }

    func record(thermalPressureState state: ProcessInfo.ThermalState?) {
        thermalPressureState = state
    }

    func record(power sample: PowerUsage?) {
        guard let sample else { return }
        powerSamples.record(sample)
    }

    func record(fans sample: [FanUsage]) {
        fansSamples.record(sample)
    }

    private func applySampleStores(_ sampleStores: SampleStores) {
        cpuSamples = sampleStores.cpu
        gpuSamples = sampleStores.gpu
        memorySamples = sampleStores.memory
        diskSamples = sampleStores.disk
        networkSamples = sampleStores.network
        batterySamples = sampleStores.battery
        thermalSamples = sampleStores.thermal
        powerSamples = sampleStores.power
        fansSamples = sampleStores.fans
    }

    private static func makeSampleStores(capacity: Int) -> SampleStores {
        (
            cpu: MetricHistory(capacity: capacity),
            gpu: MetricHistory(capacity: capacity),
            memory: MetricHistory(capacity: capacity),
            disk: MetricHistory(capacity: capacity),
            network: MetricHistory(capacity: capacity),
            battery: MetricHistory(capacity: capacity),
            thermal: MetricHistory(capacity: capacity),
            power: MetricHistory(capacity: capacity),
            fans: MetricHistory(capacity: capacity)
        )
    }
}
