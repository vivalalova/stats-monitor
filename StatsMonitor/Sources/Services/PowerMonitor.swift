import Foundation
import IOKit

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
        let ioReportUsage = sampleIOReport(intervalSeconds: intervalSeconds)
        let batteryProperties = Self.readBatteryProperties()
        if let telemetryTotal = Self.telemetryTotalMilliWatts(fromBatteryProperties: batteryProperties) {
            let telemetry = batteryProperties?["PowerTelemetryData"] as? [String: Any]
            return PowerUsage(
                cpuMilliWatts: ioReportUsage?.cpuMilliWatts ?? 0,
                gpuMilliWatts: ioReportUsage?.gpuMilliWatts ?? 0,
                mediaEngineMilliWatts: ioReportUsage?.mediaEngineMilliWatts ?? 0,
                totalMilliWatts: telemetryTotal,
                externalInputMilliWatts: Self.telemetryExternalInputMilliWatts(from: telemetry),
                batteryMilliWatts: Self.telemetryBatteryMilliWatts(from: telemetry) ?? 0
            )
        }

        return ioReportUsage
    }

    static func telemetryTotalMilliWatts(fromBatteryProperties properties: [String: Any]?) -> Double? {
        guard let telemetry = properties?["PowerTelemetryData"] as? [String: Any] else { return nil }
        return telemetryTotalMilliWatts(from: telemetry)
    }

    static func telemetryExternalInputMilliWatts(from telemetry: [String: Any]?) -> Double? {
        guard let telemetry else { return nil }
        return nonNegativeDouble(from: telemetry["SystemPowerIn"])
    }

    static func telemetryBatteryMilliWatts(from telemetry: [String: Any]?) -> Double? {
        guard let telemetry else { return nil }
        return signedDouble(from: telemetry["BatteryPower"])
    }

    static func telemetryTotalMilliWatts(from telemetry: [String: Any]) -> Double? {
        if let errorCount = nonNegativeDouble(from: telemetry["PowerTelemetryErrorCount"]), errorCount > 0 {
            return nil
        }

        if let systemLoad = nonNegativeDouble(from: telemetry["SystemLoad"]), systemLoad > 0 {
            return systemLoad
        }

        let systemPowerIn = nonNegativeDouble(from: telemetry["SystemPowerIn"]) ?? 0
        let batteryContribution = signedDouble(from: telemetry["BatteryPower"]).map { min($0, 0).magnitude } ?? 0
        let derivedTotal = systemPowerIn + batteryContribution
        return derivedTotal > 0 ? derivedTotal : nil
    }

    private func sampleIOReport(intervalSeconds: Double) -> PowerUsage? {
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
        let mediaNames: Set<String> = ["AVE", "AVD", "VENC", "VDEC"]
        let otherNames: Set<String> = [
            "AMCC", "DCS", "DISP", "DISPEXT", "DRAM", "GPU SRAM",
            "ISP", "MSR", "NAND", "Pbridge0", "Pbridge1", "SEP", "SOC_AON", "SOC_REST"
        ]

        var cpuMJ:   Int64 = 0
        var gpuMJ:   Int64 = 0
        var mediaMJ: Int64 = 0
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
            } else if mediaNames.contains(name) {
                mediaMJ += val
                totalMJ += val
            } else if otherNames.contains(name) {
                totalMJ += val
            }
        }

        let inv = 1.0 / intervalSeconds   // mJ / s = mW
        return PowerUsage(
            cpuMilliWatts:      Double(cpuMJ)   * inv,
            gpuMilliWatts:      Double(gpuMJ)   * inv,
            mediaEngineMilliWatts: Double(mediaMJ) * inv,
            totalMilliWatts:    Double(totalMJ) * inv
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

    private static func readBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service, &props, kCFAllocatorDefault, 0
        ) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return nil }

        return dict
    }

    private static func nonNegativeDouble(from value: Any?) -> Double? {
        guard let value = numericDouble(from: value), value >= 0 else { return nil }
        return value
    }

    private static func signedDouble(from value: Any?) -> Double? {
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? UInt64 { return Double(Int64(bitPattern: value)) }
        if let number = value as? NSNumber {
            let text = number.stringValue
            if let unsigned = UInt64(text) {
                return Double(Int64(bitPattern: unsigned))
            }
            if let signed = Int64(text) {
                return Double(signed)
            }
        }
        return nil
    }

    private static func numericDouble(from value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? Int64 { return Double(value) }
        if let value = value as? UInt64 { return Double(value) }
        if let number = value as? NSNumber { return Double(number.stringValue) }
        return nil
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
