import Foundation
import Darwin
import IOKit

struct CPUMonitor: Sendable {
    struct ProcessSnapshot: Sendable {
        var ticks: UInt64
        var date: Date
    }

    private var previousTicks: [processor_cpu_load_info] = []
    private let frequencySampler = CoreFrequencySampler()
    private let processSampler = CPUProcessSampler()

    // Intel fallback: static max Hz per core, built once
    private var cachedIntelMaxHz: [UInt64] = []

    mutating func sample() -> CPUUsage {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &infoArray, &infoCount)
        guard kr == KERN_SUCCESS, let info = infoArray else {
            return .zero
        }

        defer {
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        let n = Int(cpuCount)
        let ticks: [processor_cpu_load_info] = info.withMemoryRebound(to: processor_cpu_load_info.self, capacity: n) { ptr in
            (0..<n).map { ptr[$0] }
        }

        guard !previousTicks.isEmpty, previousTicks.count == n else {
            previousTicks = ticks
            // Prime the frequency sampler with the first CPU tick snapshot.
            if frequencySampler.isAvailable { _ = frequencySampler.sample() }
            return .zero
        }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0
        var perCore: [Double] = []

        for i in 0..<n {
            let curr = ticks[i]
            let prev = previousTicks[i]

            let user   = UInt64(curr.cpu_ticks.0) &- UInt64(prev.cpu_ticks.0)
            let system = UInt64(curr.cpu_ticks.1) &- UInt64(prev.cpu_ticks.1)
            let idle   = UInt64(curr.cpu_ticks.2) &- UInt64(prev.cpu_ticks.2)
            let nice   = UInt64(curr.cpu_ticks.3) &- UInt64(prev.cpu_ticks.3)

            totalUser   += user
            totalSystem += system
            totalIdle   += idle
            totalNice   += nice

            let coreTotal = user + system + idle + nice
            let coreUsed = coreTotal > 0 ? Double(user + system + nice) / Double(coreTotal) * 100 : 0
            perCore.append(coreUsed)
        }

        previousTicks = ticks

        let total = totalUser + totalSystem + totalIdle + totalNice
        guard total > 0 else { return .zero }

        return CPUUsage(
            user:             Double(totalUser + totalNice) / Double(total) * 100,
            system:           Double(totalSystem) / Double(total) * 100,
            idle:             Double(totalIdle) / Double(total) * 100,
            perCore:          perCore,
            coreFrequencies:  buildCoreFrequencies(coreCount: n)
        )
    }

    func sampleTopProcesses(from snapshot: ProcessCountersSnapshot, processCount: Int = 10) -> [ProcInfo] {
        processSampler.sampleTopProcesses(from: snapshot, processCount: processCount)
    }

    static func computeTopProcesses(
        snapshot: ProcessCountersSnapshot,
        previousSnapshots: [Int32: ProcessSnapshot],
        processCount: Int
    ) -> [ProcInfo] {
        let processes = snapshot.entries.compactMap { entry -> ProcInfo? in
            guard let previous = previousSnapshots[entry.pid] else { return nil }
            let elapsed = snapshot.date.timeIntervalSince(previous.date)
            guard elapsed > 0 else { return nil }

            let deltaTicks = entry.cpuTicks >= previous.ticks ? Double(entry.cpuTicks - previous.ticks) : 0
            guard deltaTicks > 0 else { return nil }

            return ProcInfo(
                name: entry.name,
                cpuPercent: (deltaTicks / 1_000_000_000.0) / elapsed * 100,
                memoryBytes: entry.memoryBytes
            )
        }

        return Array(processes.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(processCount))
    }

    // MARK: - Frequency

    private mutating func buildCoreFrequencies(coreCount: Int) -> [CPUCoreFrequency] {
        // Apple Silicon: dynamic per-core frequency via IOReport DVFS residency
        if frequencySampler.isAvailable {
            let dynamic = frequencySampler.sample()
            if !dynamic.isEmpty { return dynamic }
        }

        // Intel fallback: static max frequency
        if cachedIntelMaxHz.isEmpty {
            cachedIntelMaxHz = queryIntelMaxFrequencies(coreCount: coreCount)
        }
        return cachedIntelMaxHz.map { CPUCoreFrequency(currentHz: 0, maxHz: $0) }
    }

    /// Intel-only: reads hw.cpufrequency_max for static max frequency.
    private func queryIntelMaxFrequencies(coreCount: Int) -> [UInt64] {
        var hz: UInt64 = 0
        var hzSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.cpufrequency_max", &hz, &hzSize, nil, 0)
        return Array(repeating: hz, count: coreCount)
    }
}

private final class CPUProcessSampler: @unchecked Sendable {
    private var previousSnapshots: [Int32: CPUMonitor.ProcessSnapshot] = [:]

    func sampleTopProcesses(from snapshot: ProcessCountersSnapshot, processCount: Int) -> [ProcInfo] {
        let processes = CPUMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: previousSnapshots,
            processCount: processCount
        )
        previousSnapshots = Dictionary(
            uniqueKeysWithValues: snapshot.entries.map { entry in
                (entry.pid, CPUMonitor.ProcessSnapshot(ticks: entry.cpuTicks, date: snapshot.date))
            }
        )
        return processes
    }
}

/// Reads per-core dynamic CPU frequency on Apple Silicon via IOReport DVFS residency.
/// Falls back gracefully if IOReport or device-tree data is unavailable.
private final class CoreFrequencySampler: @unchecked Sendable {

    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?

    // Per-cluster DVFS frequency tables (Hz), read from device tree.
    private var ecpuFreqTable: [UInt64] = []
    private var pcpuFreqTable: [UInt64] = []

    private let lib: UnsafeMutableRawPointer?

    // IOReport function pointers
    private let copyChannels: CopyChannelsFn?
    private let createSubscription: CreateSubFn?
    private let createSamples: CreateSamplesFn?
    private let createDelta: CreateDeltaFn?
    private let stateGetCount: StateCountFn?
    private let stateGetResidency: StateResidencyFn?
    private let channelGetName: GetStringFn?

    var isAvailable: Bool { subscription != nil }

    init() {
        lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY)

        guard let lib else {
            copyChannels = nil
            createSubscription = nil
            createSamples = nil
            createDelta = nil
            stateGetCount = nil
            stateGetResidency = nil
            channelGetName = nil
            return
        }

        copyChannels = Self.loadFn(lib, "IOReportCopyChannelsInGroup")
        createSubscription = Self.loadFn(lib, "IOReportCreateSubscription")
        createSamples = Self.loadFn(lib, "IOReportCreateSamples")
        createDelta = Self.loadFn(lib, "IOReportCreateSamplesDelta")
        stateGetCount = Self.loadFn(lib, "IOReportStateGetCount")
        stateGetResidency = Self.loadFn(lib, "IOReportStateGetResidency")
        channelGetName = Self.loadFn(lib, "IOReportChannelGetChannelName")

        guard copyChannels != nil,
              createSubscription != nil,
              createSamples != nil,
              createDelta != nil,
              stateGetCount != nil,
              stateGetResidency != nil,
              channelGetName != nil else {
            return
        }

        setupSubscription()
    }

    deinit {
        if let lib { dlclose(lib) }
    }

    /// Returns per-core frequencies in perflevel order (P-cores first, then E-cores).
    /// First call returns empty (needs two samples for delta). Returns empty on failure.
    func sample() -> [CPUCoreFrequency] {
        guard let subscription,
              let createSamples,
              let createDelta,
              let stateGetCount,
              let stateGetResidency,
              let channelGetName else {
            return []
        }

        guard let newSampleRef = createSamples(subscription, optionsDict, nil) else { return [] }
        let newSample = newSampleRef.takeRetainedValue()

        defer { previousSample = newSample }

        guard let previousSample,
              let deltaRef = createDelta(previousSample, newSample, nil) else {
            return []
        }
        let delta = deltaRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArray = CFDictionaryGetValue(delta, Unmanaged.passUnretained(channelsKey).toOpaque()) else {
            return []
        }
        let channels = Unmanaged<CFArray>.fromOpaque(rawArray).takeUnretainedValue()

        var efficiencyCoreResults: [(index: Int, current: UInt64, max: UInt64)] = []
        var performanceCoreResults: [(index: Int, current: UInt64, max: UInt64)] = []

        for index in 0..<CFArrayGetCount(channels) {
            let channel = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(channels, index)!).takeUnretainedValue()
            let name = channelGetName(channel)?.takeUnretainedValue() as String? ?? ""
            let stateCount = stateGetCount(channel)
            guard stateCount > 1 else { continue }

            let isEfficiencyCore = name.hasPrefix("ECPU") || name.contains("_ECPU")
            let isPerformanceCore = name.hasPrefix("PCPU") || name.contains("_PCPU")
            guard isEfficiencyCore || isPerformanceCore else { continue }

            let frequencyTable = isEfficiencyCore ? ecpuFreqTable : pcpuFreqTable
            let coreIndex = Self.coreIndex(in: name)

            var activeResidency: Int64 = 0
            var weightedFrequency: Double = 0

            for stateIndex in 1..<stateCount { // Skip index 0 = IDLE.
                let residency = stateGetResidency(channel, stateIndex)
                guard residency > 0 else { continue }
                activeResidency += residency

                let frequencyIndex = Int(stateIndex) - 1
                if frequencyIndex < frequencyTable.count {
                    weightedFrequency += Double(frequencyTable[frequencyIndex]) * Double(residency)
                }
            }

            let currentHz = activeResidency > 0
                ? UInt64(weightedFrequency / Double(activeResidency))
                : 0
            let entry = (index: coreIndex, current: currentHz, max: frequencyTable.last ?? 0)

            if isEfficiencyCore {
                efficiencyCoreResults.append(entry)
            } else {
                performanceCoreResults.append(entry)
            }
        }

        performanceCoreResults.sort { $0.index < $1.index }
        efficiencyCoreResults.sort { $0.index < $1.index }

        return performanceCoreResults.map(Self.makeCoreFrequency)
            + efficiencyCoreResults.map(Self.makeCoreFrequency)
    }

    private func setupSubscription() {
        guard let copyChannels,
              let createSubscription else {
            return
        }

        guard let channelReference = copyChannels(
            "CPU Stats" as CFString,
            "CPU Core Performance States" as CFString,
            0,
            nil,
            nil
        ) else {
            return
        }
        let channels = channelReference.takeRetainedValue() as! CFMutableDictionary

        let efficiencyActiveStates = activeStateCount(from: channels, prefix: "ECPU")
        let performanceActiveStates = activeStateCount(from: channels, prefix: "PCPU")
        readFrequencyTables(ecpuStates: efficiencyActiveStates, pcpuStates: performanceActiveStates)

        var optionsReference: Unmanaged<CFMutableDictionary>?
        subscription = createSubscription(nil, channels, &optionsReference, 0, nil)
        optionsDict = optionsReference?.takeUnretainedValue()
    }

    private func activeStateCount(from channels: CFMutableDictionary, prefix: String) -> Int {
        guard let createSubscription,
              let createSamples,
              let stateGetCount,
              let channelGetName else {
            return 0
        }

        var optionsReference: Unmanaged<CFMutableDictionary>?
        guard let subscription = createSubscription(nil, channels, &optionsReference, 0, nil),
              let sampleReference = createSamples(subscription, optionsReference?.takeUnretainedValue(), nil) else {
            return 0
        }
        let sample = sampleReference.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArray = CFDictionaryGetValue(sample, Unmanaged.passUnretained(channelsKey).toOpaque()) else {
            return 0
        }
        let sampleChannels = Unmanaged<CFArray>.fromOpaque(rawArray).takeUnretainedValue()

        for index in 0..<CFArrayGetCount(sampleChannels) {
            let channel = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(sampleChannels, index)!).takeUnretainedValue()
            let name = channelGetName(channel)?.takeUnretainedValue() as String? ?? ""
            if name.hasPrefix(prefix) || name.contains("_\(prefix)") {
                return max(Int(stateGetCount(channel)) - 1, 0)
            }
        }

        return 0
    }

    private func readFrequencyTables(ecpuStates: Int, pcpuStates: Int) {
        let powerManager = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/arm-io/pmgr")
        guard powerManager != 0 else { return }
        defer { IOObjectRelease(powerManager) }

        var candidates: [[UInt64]] = []

        for index in 0..<16 {
            let key = "voltage-states\(index)-sram"
            guard let data = IORegistryEntryCreateCFProperty(powerManager, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data else {
                continue
            }

            let entryCount = data.count / 8
            guard entryCount > 0 else { continue }

            let frequencies = (0..<entryCount).map { offset in
                UInt64(data.withUnsafeBytes { $0.load(fromByteOffset: offset * 8, as: UInt32.self) })
            }

            guard let first = frequencies.first, first > 0 else { continue }
            candidates.append(frequencies)
        }

        for frequencies in candidates {
            if frequencies.count == ecpuStates && ecpuFreqTable.isEmpty {
                ecpuFreqTable = frequencies
            } else if frequencies.count == pcpuStates && pcpuFreqTable.isEmpty {
                pcpuFreqTable = frequencies
            }
        }

        if ecpuFreqTable.isEmpty || pcpuFreqTable.isEmpty {
            let matching = candidates.filter { $0.count == ecpuStates || $0.count == pcpuStates }
                .sorted { ($0.last ?? 0) < ($1.last ?? 0) }

            if matching.count >= 2 {
                ecpuFreqTable = matching[0]
                pcpuFreqTable = matching[1]
            } else if let onlyMatch = matching.first {
                pcpuFreqTable = onlyMatch
            }
        }
    }

    private static func coreIndex(in channelName: String) -> Int {
        guard let match = channelName.range(of: #"[EP]CPU(\d+)"#, options: .regularExpression) else {
            return 0
        }
        let numericPortion = channelName[match].filter(\.isNumber)
        return Int(numericPortion) ?? 0
    }

    private static func makeCoreFrequency(from result: (index: Int, current: UInt64, max: UInt64)) -> CPUCoreFrequency {
        CPUCoreFrequency(currentHz: result.current, maxHz: result.max)
    }

    private static func loadFn<T>(_ library: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let symbol = dlsym(library, name) else { return nil }
        return unsafeBitCast(symbol, to: T.self)
    }

    private typealias CopyChannelsFn = @convention(c) (
        CFString, CFString?, UInt64, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias CreateSubFn = @convention(c) (
        UnsafeMutableRawPointer?, CFMutableDictionary,
        UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64, UnsafeMutableRawPointer?
    ) -> OpaquePointer?

    private typealias CreateSamplesFn = @convention(c) (
        OpaquePointer, CFMutableDictionary?, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias CreateDeltaFn = @convention(c) (
        CFDictionary, CFDictionary, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias StateCountFn = @convention(c) (CFDictionary) -> Int32

    private typealias StateResidencyFn = @convention(c) (CFDictionary, Int32) -> Int64

    private typealias GetStringFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
}
