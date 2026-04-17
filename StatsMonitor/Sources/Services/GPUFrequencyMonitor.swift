import Foundation
import IOKit

/// Reads GPU dynamic frequency on Apple Silicon via IOReport DVFS residency.
/// Falls back gracefully if IOReport or device-tree data is unavailable.
final class GPUFrequencyMonitor: @unchecked Sendable {

    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?

    // GPU DVFS frequency table (Hz), from device tree
    private var freqTable: [UInt64] = []

    private let lib: UnsafeMutableRawPointer?

    private let _copyChannels: CopyChannelsFn?
    private let _createSubscription: CreateSubFn?
    private let _createSamples: CreateSamplesFn?
    private let _createDelta: CreateDeltaFn?
    private let _stateGetCount: StateCountFn?
    private let _stateGetResidency: StateResidencyFn?
    private let _channelGetName: GetStringFn?

    var isAvailable: Bool { subscription != nil && !freqTable.isEmpty }

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

        readFrequencyTable()
        setupSubscription()
    }

    deinit {
        if let lib { dlclose(lib) }
    }

    /// Returns GPU frequency (averaged across DVFS residency since last sample).
    /// First call returns nil (needs two samples for delta). nil on failure.
    func sample() -> CPUCoreFrequency? {
        guard let sub = subscription,
              let createSamples = _createSamples,
              let createDelta = _createDelta,
              let stateGetCount = _stateGetCount,
              let stateGetResidency = _stateGetResidency,
              !freqTable.isEmpty else { return nil }

        guard let newSampleRef = createSamples(sub, optionsDict, nil) else { return nil }
        let newSample = newSampleRef.takeRetainedValue()
        defer { previousSample = newSample }

        guard let prev = previousSample,
              let deltaRef = createDelta(prev, newSample, nil) else { return nil }
        let delta = deltaRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArr = CFDictionaryGetValue(delta, Unmanaged.passUnretained(channelsKey).toOpaque()) else { return nil }
        let arr = Unmanaged<CFArray>.fromOpaque(rawArr).takeUnretainedValue()
        let n = CFArrayGetCount(arr)

        var activeResidency: Int64 = 0
        var weightedHz: Double = 0

        for i in 0..<n {
            let item = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(arr, i)!).takeUnretainedValue()
            let stateCount = stateGetCount(item)
            guard stateCount > 1 else { continue }
            let upper = min(Int(stateCount), freqTable.count)
            for s in 1..<upper {
                let residency = stateGetResidency(item, Int32(s))
                guard residency > 0 else { continue }
                activeResidency += residency
                weightedHz += Double(freqTable[s]) * Double(residency)
            }
        }

        let currentHz: UInt64 = activeResidency > 0
            ? UInt64(weightedHz / Double(activeResidency))
            : 0
        let maxHz = freqTable.last ?? 0
        return CPUCoreFrequency(currentHz: currentHz, maxHz: maxHz)
    }

    // MARK: - Setup

    private func setupSubscription() {
        guard let copyChannels = _copyChannels,
              let createSub = _createSubscription else { return }

        guard let chRef = copyChannels(
            "GPU Stats" as CFString,
            "GPU Performance States" as CFString,
            0, nil, nil
        ) else { return }
        let channels = chRef.takeRetainedValue() as! CFMutableDictionary

        var optRef: Unmanaged<CFMutableDictionary>?
        subscription = createSub(nil, channels, &optRef, 0, nil)
        optionsDict = optRef?.takeUnretainedValue()
    }

    /// Read GPU DVFS frequency table from device-tree pmgr.
    /// GPU tables start with 0 Hz (idle state); CPU tables do not.
    private func readFrequencyTable() {
        let pmgr = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/arm-io/pmgr")
        guard pmgr != 0 else { return }
        defer { IOObjectRelease(pmgr) }

        // Prefer longer tables (more DVFS states) among those starting with 0 Hz.
        var best: [UInt64] = []
        for n in 0..<16 {
            let key = "voltage-states\(n)-sram"
            guard let data = IORegistryEntryCreateCFProperty(pmgr, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data else { continue }

            let entryCount = data.count / 8
            guard entryCount > 1 else { continue }

            let freqs: [UInt64] = (0..<entryCount).map { i in
                UInt64(data.withUnsafeBytes { $0.load(fromByteOffset: i * 8, as: UInt32.self) })
            }
            guard freqs.first == 0 else { continue }
            if freqs.count > best.count { best = freqs }
        }
        freqTable = best
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
