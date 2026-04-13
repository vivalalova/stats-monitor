import Foundation

/// Reads Apple Neural Engine power consumption from IOReport Energy Model.
/// Returns milliwatts. Utilization % is not available via any public API.
/// Falls back to 0 when IOReport is unavailable.
final class ANEMonitor: @unchecked Sendable {

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

    /// Returns ANE power in milliwatts for the last poll interval.
    /// First call returns 0 (needs two samples for delta).
    func sample(intervalSeconds: Double) -> Double {
        guard let sub = subscription,
              let createSamples = _createSamples,
              let createDelta   = _createDelta,
              let channelName   = _channelName,
              let getInt        = _getInt,
              intervalSeconds > 0 else { return 0 }

        guard let newRef = createSamples(sub, optionsDict, nil) else { return 0 }
        let newSample = newRef.takeRetainedValue()
        defer { previousSample = newSample }

        guard let prev = previousSample,
              let deltaRef = createDelta(prev, newSample, nil) else { return 0 }
        let delta = deltaRef.takeRetainedValue()

        let key = "IOReportChannels" as CFString
        guard let rawArr = CFDictionaryGetValue(delta,
                               Unmanaged.passUnretained(key).toOpaque()) else { return 0 }
        let arr = Unmanaged<CFArray>.fromOpaque(rawArr).takeUnretainedValue()

        var totalMJ: Int64 = 0
        for i in 0..<CFArrayGetCount(arr) {
            let ch = Unmanaged<CFDictionary>
                .fromOpaque(CFArrayGetValueAtIndex(arr, i)!)
                .takeUnretainedValue()
            let name = channelName(ch)?.takeUnretainedValue() as String? ?? ""
            guard name == "ANE" || name.hasPrefix("ANE0") else { continue }
            totalMJ += getInt(ch, 0)
        }

        return Double(max(0, totalMJ)) / intervalSeconds   // mJ / s = mW
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
