import Foundation

/// Reads CPU / GPU / total package power from IOReport Energy Model.
/// Same IOReport subscription pattern as ANEMonitor.
/// Returns milliwatts. First call returns zero (needs two samples for delta).
final class PowerMonitor: @unchecked Sendable {

    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?
    private let lib: UnsafeMutableRawPointer?

    private let _createSamples: CreateSamplesFn?
    private let _createDelta:   CreateDeltaFn?
    private let _channelName:   GetStringFn?
    private let _getInt:        SimpleGetIntFn?

    var isAvailable: Bool { subscription != nil }

    init() {
        lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY)
        guard let lib else {
            _createSamples = nil; _createDelta = nil
            _channelName = nil; _getInt = nil
            return
        }
        _createSamples = Self.sym(lib, "IOReportCreateSamples")
        _createDelta   = Self.sym(lib, "IOReportCreateSamplesDelta")
        _channelName   = Self.sym(lib, "IOReportChannelGetChannelName")
        _getInt        = Self.sym(lib, "IOReportSimpleGetIntegerValue")
        guard _createSamples != nil, _createDelta != nil,
              _channelName != nil, _getInt != nil else { return }
        setupSubscription()
    }

    deinit { if let lib { dlclose(lib) } }

    /// Returns power usage in milliwatts for the last poll interval.
    func sample(intervalSeconds: Double) -> PowerUsage? {
        guard let sub = subscription,
              let createSamples = _createSamples,
              let createDelta   = _createDelta,
              let channelName   = _channelName,
              let getInt        = _getInt,
              intervalSeconds > 0 else { return nil }

        guard let newRef = createSamples(sub, optionsDict, nil) else { return nil }
        let newSample = newRef.takeRetainedValue()
        defer { previousSample = newSample }

        guard let prev = previousSample,
              let deltaRef = createDelta(prev, newSample, nil) else { return nil }
        let delta = deltaRef.takeRetainedValue()

        let key = "IOReportChannels" as CFString
        guard let rawArr = CFDictionaryGetValue(delta,
                               Unmanaged.passUnretained(key).toOpaque()) else { return nil }
        let arr = Unmanaged<CFArray>.fromOpaque(rawArr).takeUnretainedValue()

        // Known energy channels in the IOReport "Energy Model" group.
        // Using exact names to avoid summing non-energy counters (CPUPM, CPUFREQ, etc.)
        // that share the same group but return data in different units.
        let cpuNames: Set<String> = ["CPU", "ECPU", "PCPU", "ECORE", "PCORE"]
        let gpuNames: Set<String> = ["GPU"]
        let otherNames: Set<String> = ["ANE", "DRAM", "Pbridge0", "Pbridge1",
                                       "DCS0", "DCS1", "ISP", "SEP", "NAND"]

        var cpuMJ:   Int64 = 0
        var gpuMJ:   Int64 = 0
        var totalMJ: Int64 = 0

        for i in 0..<CFArrayGetCount(arr) {
            let ch = Unmanaged<CFDictionary>
                .fromOpaque(CFArrayGetValueAtIndex(arr, i)!)
                .takeUnretainedValue()
            let name = channelName(ch)?.takeUnretainedValue() as String? ?? ""
            let val  = max(0, getInt(ch, 0))
            if cpuNames.contains(name) {
                cpuMJ  += val
                totalMJ += val
            } else if gpuNames.contains(name) {
                gpuMJ  += val
                totalMJ += val
            } else if otherNames.contains(name) {
                totalMJ += val
            }
        }

        let inv = 1.0 / intervalSeconds   // mJ / s = mW
        return PowerUsage(
            cpuMilliWatts:   Double(cpuMJ)   * inv,
            gpuMilliWatts:   Double(gpuMJ)   * inv,
            totalMilliWatts: Double(totalMJ) * inv
        )
    }

    // MARK: - Setup

    private func setupSubscription() {
        guard let lib else { return }
        guard let copyChannels: CopyChannelsFn = Self.sym(lib, "IOReportCopyChannelsInGroup"),
              let createSub: CreateSubFn       = Self.sym(lib, "IOReportCreateSubscription")
        else { return }

        guard let chRef = copyChannels("Energy Model" as CFString, nil, 0, nil, nil) else { return }
        let channels = chRef.takeRetainedValue() as! CFMutableDictionary

        var optRef: Unmanaged<CFMutableDictionary>?
        subscription = createSub(nil, channels, &optRef, 0, nil)
        optionsDict  = optRef?.takeUnretainedValue()
    }

    private static func sym<T>(_ lib: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let ptr = dlsym(lib, name) else { return nil }
        return unsafeBitCast(ptr, to: T.self)
    }

    // MARK: - C function types

    private typealias CopyChannelsFn = @convention(c) (
        CFString, CFString?, UInt64,
        UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias CreateSubFn = @convention(c) (
        UnsafeMutableRawPointer?, CFMutableDictionary,
        UnsafeMutablePointer<Unmanaged<CFMutableDictionary>?>, UInt64,
        UnsafeMutableRawPointer?
    ) -> OpaquePointer?

    private typealias CreateSamplesFn = @convention(c) (
        OpaquePointer, CFMutableDictionary?, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias CreateDeltaFn = @convention(c) (
        CFDictionary, CFDictionary, UnsafeMutableRawPointer?
    ) -> Unmanaged<CFDictionary>?

    private typealias GetStringFn    = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias SimpleGetIntFn = @convention(c) (CFDictionary, Int32) -> Int64
}
