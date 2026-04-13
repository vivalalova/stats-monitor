import Foundation
import IOKit

/// Reads per-core dynamic CPU frequency on Apple Silicon via IOReport DVFS residency.
/// Falls back gracefully if IOReport or device-tree data is unavailable.
final class CPUFrequencyMonitor: @unchecked Sendable {

    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?

    // Per-cluster DVFS frequency tables (Hz), read from device tree
    private var ecpuFreqTable: [UInt64] = []
    private var pcpuFreqTable: [UInt64] = []

    // Core counts per cluster (perflevel0=P, perflevel1=E)
    private var pCoreCount: Int = 0
    private var eCoreCount: Int = 0

    private let lib: UnsafeMutableRawPointer?

    // IOReport function pointers
    private let _copyChannels: CopyChannelsFn?
    private let _createSubscription: CreateSubFn?
    private let _createSamples: CreateSamplesFn?
    private let _createDelta: CreateDeltaFn?
    private let _stateGetCount: StateCountFn?
    private let _stateGetResidency: StateResidencyFn?
    private let _channelGetName: GetStringFn?

    var isAvailable: Bool { subscription != nil }

    init() {
        lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY)

        guard let lib else {
            _copyChannels = nil; _createSubscription = nil; _createSamples = nil
            _createDelta = nil; _stateGetCount = nil; _stateGetResidency = nil
            _channelGetName = nil
            return
        }

        _copyChannels = Self.loadFn(lib, "IOReportCopyChannelsInGroup")
        _createSubscription = Self.loadFn(lib, "IOReportCreateSubscription")
        _createSamples = Self.loadFn(lib, "IOReportCreateSamples")
        _createDelta = Self.loadFn(lib, "IOReportCreateSamplesDelta")
        _stateGetCount = Self.loadFn(lib, "IOReportStateGetCount")
        _stateGetResidency = Self.loadFn(lib, "IOReportStateGetResidency")
        _channelGetName = Self.loadFn(lib, "IOReportChannelGetChannelName")

        guard _copyChannels != nil, _createSubscription != nil, _createSamples != nil,
              _createDelta != nil, _stateGetCount != nil, _stateGetResidency != nil,
              _channelGetName != nil else { return }

        readClusterCounts()
        setupSubscription()
    }

    deinit {
        if let lib { dlclose(lib) }
    }

    // MARK: - Public

    /// Returns per-core frequencies in perflevel order (P-cores first, then E-cores).
    /// First call returns empty (needs two samples for delta). Returns empty on failure.
    func sample() -> [CPUCoreFrequency] {
        guard let sub = subscription,
              let createSamples = _createSamples,
              let createDelta = _createDelta,
              let stateGetCount = _stateGetCount,
              let stateGetResidency = _stateGetResidency,
              let channelGetName = _channelGetName else { return [] }

        guard let newSampleRef = createSamples(sub, optionsDict, nil) else { return [] }
        let newSample = newSampleRef.takeRetainedValue()

        defer { previousSample = newSample }

        guard let prev = previousSample,
              let deltaRef = createDelta(prev, newSample, nil) else { return [] }
        let delta = deltaRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArr = CFDictionaryGetValue(delta, Unmanaged.passUnretained(channelsKey).toOpaque()) else { return [] }
        let arr = Unmanaged<CFArray>.fromOpaque(rawArr).takeUnretainedValue()
        let n = CFArrayGetCount(arr)

        // Parse per-channel: build dict of channelName -> (avgHz, maxHz)
        var ecpuResults: [(index: Int, current: UInt64, max: UInt64)] = []
        var pcpuResults: [(index: Int, current: UInt64, max: UInt64)] = []

        for i in 0..<n {
            let item = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(arr, i)!).takeUnretainedValue()
            let name = channelGetName(item)?.takeUnretainedValue() as String? ?? ""
            let stateCount = stateGetCount(item)
            guard stateCount > 1 else { continue }

            let isECPU = name.hasPrefix("ECPU") || name.contains("_ECPU")
            let isPCPU = name.hasPrefix("PCPU") || name.contains("_PCPU")
            guard isECPU || isPCPU else { continue }

            let freqTable = isECPU ? ecpuFreqTable : pcpuFreqTable

            // Extract core index from name (e.g., "ECPU2" → 2, "DIE_0_ECPU1" → 1)
            let coreIndex: Int
            if let match = name.range(of: #"[EP]CPU(\d+)"#, options: .regularExpression) {
                let numPart = name[match].filter(\.isNumber)
                coreIndex = Int(numPart) ?? 0
            } else {
                coreIndex = 0
            }

            var activeResidency: Int64 = 0
            var weightedHz: Double = 0

            for s in 1..<stateCount {  // skip index 0 = IDLE
                let residency = stateGetResidency(item, s)
                guard residency > 0 else { continue }
                activeResidency += residency
                let freqIdx = Int(s) - 1
                if freqIdx < freqTable.count {
                    weightedHz += Double(freqTable[freqIdx]) * Double(residency)
                }
            }

            let currentHz: UInt64 = activeResidency > 0
                ? UInt64(weightedHz / Double(activeResidency))
                : 0
            let maxHz = freqTable.last ?? 0

            let entry = (index: coreIndex, current: currentHz, max: maxHz)
            if isECPU { ecpuResults.append(entry) }
            else { pcpuResults.append(entry) }
        }

        // Build result in perflevel order: P-cores first (perflevel0), E-cores second (perflevel1)
        pcpuResults.sort { $0.index < $1.index }
        ecpuResults.sort { $0.index < $1.index }

        var result: [CPUCoreFrequency] = []
        for r in pcpuResults {
            result.append(CPUCoreFrequency(currentHz: r.current, maxHz: r.max))
        }
        for r in ecpuResults {
            result.append(CPUCoreFrequency(currentHz: r.current, maxHz: r.max))
        }
        return result
    }

    // MARK: - Setup

    private func readClusterCounts() {
        // perflevel0 = Performance, perflevel1 = Efficiency
        for level in 0..<8 {
            var n: Int32 = 0; var nSize = MemoryLayout<Int32>.size
            guard sysctlbyname("hw.perflevel\(level).physicalcpu", &n, &nSize, nil, 0) == 0, n > 0 else { break }
            var nameBytes = [CChar](repeating: 0, count: 64)
            var nameSize = nameBytes.count
            let isPerf = sysctlbyname("hw.perflevel\(level).name", &nameBytes, &nameSize, nil, 0) == 0
                && String(cString: nameBytes) == "Performance"
            if level == 0 || isPerf {
                pCoreCount = Int(n)
            } else {
                eCoreCount = Int(n)
            }
        }
    }

    private func setupSubscription() {
        guard let copyChannels = _copyChannels,
              let createSub = _createSubscription else { return }

        guard let chRef = copyChannels(
            "CPU Stats" as CFString,
            "CPU Core Performance States" as CFString,
            0, nil, nil
        ) else { return }
        let channels = chRef.takeRetainedValue() as! CFMutableDictionary

        // Determine active state counts from the channel data
        let ecpuActiveStates = activeStateCount(from: channels, prefix: "ECPU")
        let pcpuActiveStates = activeStateCount(from: channels, prefix: "PCPU")

        // Read DVFS frequency tables from device tree, matching by state count
        readFrequencyTables(ecpuStates: ecpuActiveStates, pcpuStates: pcpuActiveStates)

        var optRef: Unmanaged<CFMutableDictionary>?
        subscription = createSub(nil, channels, &optRef, 0, nil)
        optionsDict = optRef?.takeUnretainedValue()
    }

    /// Get active state count for a cluster type by sampling once
    private func activeStateCount(from channels: CFMutableDictionary, prefix: String) -> Int {
        guard let createSub = _createSubscription,
              let createSamples = _createSamples,
              let stateGetCount = _stateGetCount,
              let channelGetName = _channelGetName else { return 0 }

        // Temporarily create subscription just to read state structure
        var tempOptRef: Unmanaged<CFMutableDictionary>?
        guard let tempSub = createSub(nil, channels, &tempOptRef, 0, nil),
              let sampleRef = createSamples(tempSub, tempOptRef?.takeUnretainedValue(), nil)
        else { return 0 }
        let sample = sampleRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArr = CFDictionaryGetValue(sample, Unmanaged.passUnretained(channelsKey).toOpaque()) else { return 0 }
        let arr = Unmanaged<CFArray>.fromOpaque(rawArr).takeUnretainedValue()

        for i in 0..<CFArrayGetCount(arr) {
            let item = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(arr, i)!).takeUnretainedValue()
            let name = channelGetName(item)?.takeUnretainedValue() as String? ?? ""
            if name.hasPrefix(prefix) || name.contains("_\(prefix)") {
                let count = Int(stateGetCount(item))
                return max(count - 1, 0) // subtract IDLE state
            }
        }
        return 0
    }

    /// Read DVFS frequency tables from IODeviceTree pmgr, matching by entry count
    private func readFrequencyTables(ecpuStates: Int, pcpuStates: Int) {
        let pmgr = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/arm-io/pmgr")
        guard pmgr != 0 else { return }
        defer { IOObjectRelease(pmgr) }

        // Scan all voltage-statesN-sram keys (N = 0..15)
        var candidates: [(key: String, freqs: [UInt64])] = []
        for n in 0..<16 {
            let key = "voltage-states\(n)-sram"
            guard let data = IORegistryEntryCreateCFProperty(pmgr, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data else { continue }

            let entryCount = data.count / 8
            guard entryCount > 0 else { continue }

            let freqs: [UInt64] = (0..<entryCount).map { i in
                UInt64(data.withUnsafeBytes { $0.load(fromByteOffset: i * 8, as: UInt32.self) })
            }

            // Skip tables starting with 0 Hz (GPU or other)
            guard let first = freqs.first, first > 0 else { continue }
            candidates.append((key: key, freqs: freqs))
        }

        // Match by state count
        for c in candidates {
            if c.freqs.count == ecpuStates && ecpuFreqTable.isEmpty {
                ecpuFreqTable = c.freqs
            } else if c.freqs.count == pcpuStates && pcpuFreqTable.isEmpty {
                pcpuFreqTable = c.freqs
            }
        }

        // If counts overlap, disambiguate by max frequency (higher = PCPU)
        if ecpuFreqTable.isEmpty || pcpuFreqTable.isEmpty {
            let matching = candidates.filter { $0.freqs.count == ecpuStates || $0.freqs.count == pcpuStates }
            let sorted = matching.sorted { ($0.freqs.last ?? 0) < ($1.freqs.last ?? 0) }
            if sorted.count >= 2 {
                ecpuFreqTable = sorted[0].freqs
                pcpuFreqTable = sorted[1].freqs
            } else if sorted.count == 1 {
                pcpuFreqTable = sorted[0].freqs
            }
        }
    }

    // MARK: - dlsym helpers

    private static func loadFn<T>(_ lib: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(lib, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    // MARK: - C function types

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
