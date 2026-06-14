import Foundation
import Observation

struct SampleIntervalTracker {
    let fallbackInterval: TimeInterval
    private var previousDate: Date?

    init(fallbackInterval: TimeInterval) {
        self.fallbackInterval = fallbackInterval
    }

    mutating func interval(at date: Date) -> TimeInterval {
        defer { previousDate = date }
        guard let previousDate else { return fallbackInterval }
        let elapsed = date.timeIntervalSince(previousDate)
        return elapsed > 0 ? elapsed : fallbackInterval
    }
}

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
    private(set) var isLowPowerModeEnabled: Bool = false
    private(set) var displayInfo: DisplayInfo = .zero
    private(set) var currentBatterySample: BatteryUsage?
    private(set) var currentThermalSample: ThermalUsage?
    private(set) var currentPowerSample: PowerUsage?

    var topCPUProcesses: [ProcInfo] = []
    var topGPUProcesses: [GPUProcessInfo] = []
    var topMemoryProcesses: [ProcInfo] = []
    var topDiskProcesses: [ProcInfo] = []
    var topNetworkProcesses: [ProcInfo] = []
    var topPowerProcesses: [ProcInfo] = []

    private var cpuMonitor          = CPUMonitor()
    private var gpuMonitor          = GPUMonitor()
    private var memoryMonitor       = MemoryMonitor()
    private var diskMonitor     = DiskMonitor()
    private var networkMonitor  = NetworkMonitor()
    private var powerMonitor    = PowerMonitor()
    private var wifiMonitor     = WiFiMonitor()
    private let displayInfoMonitor = DisplayInfoMonitor()
    private var pollTick: UInt = 0
    /// Re-read display mode every N polls — resolution rarely changes.
    private static let displayInfoRefreshEveryNSamples: UInt = 30

    private let smcClient                         = SMCClient()
    private var batteryMonitor                    = BatteryMonitor()
    private var thermalMonitor: ThermalMonitor
    private var fanMonitor: FanMonitor

    private var isNetworkProcessPollInFlight = false
    private var isProcessPollInFlight = false
    private var isRunning = false

    private var timer: Timer?
    private let settings: AppSettings
    private var sampleIntervalTracker: SampleIntervalTracker

    init(settings: AppSettings) {
        self.settings = settings
        sampleIntervalTracker = SampleIntervalTracker(fallbackInterval: settings.pollInterval)
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
        let intervalSeconds = sampleIntervalTracker.interval(at: .now)
        let cpu     = cpuMonitor.sample()
        let gpu     = gpuMonitor.sample(intervalSeconds: intervalSeconds)
        let memory  = memoryMonitor.sample()
        let disk    = diskMonitor.sample()
        var network = networkMonitor.sample()
        network.wifi = wifiMonitor.sample()
        let battery = batteryMonitor.sample()
        let thermalSample = thermalMonitor.sample()
        let fans    = fanMonitor.sample()
        let power   = powerMonitor.sample(intervalSeconds: intervalSeconds)
        let lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        let count   = settings.processCount

        record(cpu: cpu)
        record(gpu: gpu)
        record(memory: memory)
        record(disk: disk)
        record(network: network)
        record(battery: battery)
        record(thermal: thermalSample.usage)
        record(thermalPressureState: thermalSample.pressureState)
        record(power: power)
        record(fans: fans)
        isLowPowerModeEnabled = lowPowerMode
        if pollTick % Self.displayInfoRefreshEveryNSamples == 0 {
            displayInfo = displayInfoMonitor.sample()
        }
        pollTick &+= 1
        topGPUProcesses = gpuMonitor.sampleTopApps(intervalSeconds: intervalSeconds, processCount: count)

        pollNetworkProcesses(processCount: count)
        pollProcessDetails(processCount: count)
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
        guard !isNetworkProcessPollInFlight else { return }
        isNetworkProcessPollInFlight = true
        let previousMonitor = networkMonitor
        Task { [weak self] in
            guard let self else { return }
            let processes = await Task.detached(priority: .utility) {
                let monitor = previousMonitor
                let processes = monitor.sampleTopProcesses(processCount: processCount)
                return processes
            }.value
            self.isNetworkProcessPollInFlight = false
            self.topNetworkProcesses = processes
        }
    }

    private func pollProcessDetails(processCount: Int) {
        guard !isProcessPollInFlight else { return }
        isProcessPollInFlight = true
        let cpuMonitor = self.cpuMonitor
        let memoryMonitor = self.memoryMonitor
        let diskMonitor = self.diskMonitor
        let powerMonitor = self.powerMonitor
        Task { [weak self] in
            guard let self else { return }
            let result = await Task.detached(priority: .utility) {
                guard let snapshot = ProcessCountersReader.sample() else {
                    return (cpu: [ProcInfo](), memory: [ProcInfo](), disk: [ProcInfo](), power: [ProcInfo]())
                }
                return (
                    cpu: cpuMonitor.sampleTopProcesses(from: snapshot, processCount: processCount),
                    memory: memoryMonitor.sampleTopProcesses(from: snapshot, processCount: processCount),
                    disk: diskMonitor.sampleTopProcesses(from: snapshot, processCount: processCount),
                    power: powerMonitor.sampleTopProcesses(from: snapshot, processCount: processCount)
                )
            }.value
            self.isProcessPollInFlight = false
            self.topCPUProcesses = result.cpu
            self.topMemoryProcesses = result.memory
            self.topDiskProcesses = result.disk
            self.topPowerProcesses = result.power
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
        currentBatterySample = sample
        if let sample {
            batterySamples.record(sample)
        }
    }

    func record(thermal sample: ThermalUsage?) {
        currentThermalSample = sample
        if let sample {
            thermalSamples.record(sample)
        }
    }

    func record(thermalPressureState state: ProcessInfo.ThermalState?) {
        thermalPressureState = state
    }

    func record(isLowPowerModeEnabled enabled: Bool) {
        isLowPowerModeEnabled = enabled
    }

    func record(displayInfo info: DisplayInfo) {
        displayInfo = info
    }

    func record(power sample: PowerUsage?) {
        currentPowerSample = sample
        if let sample {
            powerSamples.record(sample)
        }
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
        currentBatterySample = nil
        currentThermalSample = nil
        currentPowerSample = nil
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
