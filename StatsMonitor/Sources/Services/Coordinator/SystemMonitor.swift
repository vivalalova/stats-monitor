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
    var topGPUProcesses: [ProcInfo] = []
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
    private var isGPUProcessResolveInFlight = false
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
        resolveGPUProcesses(gpuMonitor.sampleTopApps(intervalSeconds: intervalSeconds, processCount: count))

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

    /// GPU 取樣本身要留在 main actor（monitor 需保留上一輪 counter 算 delta），
    /// 名稱／icon 解析則與其他 top list 一樣丟背景，避免 main actor 付 `proc_pidpath` 與讀 Info.plist 的成本。
    private func resolveGPUProcesses(_ samples: [GPUProcessInfo]) {
        guard !isGPUProcessResolveInFlight else { return }
        isGPUProcessResolveInFlight = true
        let pending = samples.map { ProcInfo(gpu: $0) }
        Task { [weak self] in
            guard let self else { return }
            let processes = await Task.detached(priority: .utility) {
                ProcessIdentityCache.shared.resolved(pending)
            }.value
            self.isGPUProcessResolveInFlight = false
            self.topGPUProcesses = processes
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
                // 名稱／icon 路徑解析留在背景，main actor 只拿解析好的結果。
                return ProcessIdentityCache.shared.resolved(processes)
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
                // 名稱／icon 路徑解析留在背景，main actor 只拿解析好的結果。
                let identities = ProcessIdentityCache.shared
                // CPU 取樣一輪只能做一次（sampler 要留 ticks 算下一輪 delta），所以先拿全表：
                // 顯示用的 CPU top N 是它的 prefix，高耗能行程表借 CPU% 用的是全表。
                // 全表刻意不過 `identities.resolved` —— 快取只有 512 格而常駐行程 400–600，
                // 整表解析會逼快取每輪清空重建；合併只借 pid → cpuPercent，不需要名稱與 icon。
                let cpuAll = cpuMonitor.sampleAllProcesses(from: snapshot)
                let power = identities.resolved(
                    powerMonitor.sampleTopProcesses(from: snapshot, processCount: processCount)
                )
                return (
                    cpu: identities.resolved(Array(cpuAll.prefix(processCount))),
                    memory: identities.resolved(memoryMonitor.sampleTopProcesses(from: snapshot, processCount: processCount)),
                    disk: identities.resolved(diskMonitor.sampleTopProcesses(from: snapshot, processCount: processCount)),
                    power: SystemMonitor.mergePowerProcesses(power: power, cpu: cpuAll)
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

// MARK: - Top Processes 合併

/// 熱門行程表的資料推導：五份 top list 併成一列一行程。放在 store 側，View 只負責排序與呈現。
extension SystemMonitor {
    /// 以 pid 為合併鍵（同名不同 pid 不併），各數值欄取各 list 的最大值。
    /// pid 取不到的列（pid 0，只來自 nettop key 解析失敗）一律以名稱自成一列：
    /// 有 pid 的列名稱已被 `ProcessIdentityCache` 換成 bundle display name，
    /// 與 pid 0 列身上的原始 nettop 名不同源，拿名稱互併只會誤併到不相干的行程。
    static func mergeTopProcesses(
        cpu: [ProcInfo],
        memory: [ProcInfo],
        disk: [ProcInfo],
        network: [ProcInfo],
        gpu: [ProcInfo]
    ) -> [ProcInfo] {
        let all = cpu + memory + disk + network + gpu
        var merged: [String: ProcInfo] = [:]
        var order: [String] = []
        func absorb(_ proc: ProcInfo, key: String) {
            if let existing = merged[key] {
                merged[key] = existing.merged(with: proc)
            } else {
                merged[key] = proc
                order.append(key)
            }
        }

        // 第一輪：有 pid 的列先定錨。
        for proc in all where proc.pid > 0 {
            absorb(proc, key: proc.mergeKey)
        }

        // 第二輪：沒有 pid 的列以名稱自成一列。
        for proc in all where proc.pid == 0 {
            absorb(proc, key: proc.mergeKey)
        }

        return order.compactMap { merged[$0] }
    }

    /// 高耗能行程表的 CPU% 欄：`PowerMonitor` 產出的列本來就沒有 CPU%，靠 pid 對上 CPU list 才有值。
    /// 與 `mergeTopProcesses` 規則不同 —— 這裡 power list 是主，CPU list 只借出 `cpuPercent` 一欄：
    /// 不取兩邊最大值、不補進只在 CPU list 的行程、不改名，所以另立契約而非重用 `ProcInfo.merged(with:)`。
    /// `cpu` 要餵該輪的**全表**（`CPUMonitor.sampleAllProcesses`）而非顯示用的 top N：
    /// 只餵 top N 會讓進 power 榜但沒進 CPU 前 N 名的行程顯示成量不到，而它的 CPU% 明明算得出來。
    /// pid 不在全表（前一輪沒見過或這輪無 tick 增量）＝這一輪真的量不到，一律回 nil（顯示破折號），
    /// 不留 power 列身上的舊值。
    /// 取樣在背景（`Task.detached`）做完就併，全表不進 main actor，所以 `nonisolated`。
    nonisolated static func mergePowerProcesses(power: [ProcInfo], cpu: [ProcInfo]) -> [ProcInfo] {
        // pid 同源於一份 `ProcessCountersSnapshot`，本來就唯一；真出現重複代表上游壞了，讓它炸。
        let cpuByPID = Dictionary(uniqueKeysWithValues: cpu.map { ($0.pid, $0) })
        return power.map { row in
            var merged = row
            merged.cpuPercent = cpuByPID[row.pid]?.cpuPercent
            return merged
        }
    }

    /// 比例條分母：該欄有資料列的最大值；全欄無資料時回 0。
    static func processColumnMaximum(_ values: [Double?]) -> Double {
        values.compactMap { $0 }.max() ?? 0
    }

    /// 比例條長度（0…1）。無資料、非正值或分母為 0 時回 0 ＝不畫 bar。
    static func processBarFraction(_ value: Double?, columnMaximum: Double) -> Double {
        guard let value, value > 0, columnMaximum > 0 else { return 0 }
        return min(value / columnMaximum, 1)
    }
}

private extension ProcInfo {
    /// GPU top list 只帶 GPU 使用率，其餘欄位在合併時由別的 list 補上。
    init(gpu: GPUProcessInfo) {
        self.init(pid: gpu.pid, name: gpu.name, gpuPercent: gpu.utilizationPercent)
    }
}
