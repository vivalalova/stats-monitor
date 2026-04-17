import Foundation
import IOKit

struct GPUMonitor {
    struct AppUsageSnapshot: Equatable {
        var pid: Int
        var name: String
        var accumulatedGPUTime: UInt64
        var commandQueueCount: Int
    }

    private var previousAppTotalsByPID: [Int: UInt64] = [:]
    private let frequencySampler = FrequencySampler()
    private let neuralEnginePowerSampler = NeuralEnginePowerSampler()

    func sample(intervalSeconds: Double) -> GPUUsage {
        var usage = GPUUsage.zero

        let matchingDict = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return .zero
        }
        defer { IOObjectRelease(iterator) }

        var service: io_object_t = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let perf = dict["PerformanceStatistics"] as? [String: Any] {
                usage = Self.merge(usage, with: Self.parseUsage(from: perf))
            }

            service = IOIteratorNext(iterator)
        }

        usage.anePowerMilliWatts = neuralEnginePowerSampler.sample(intervalSeconds: intervalSeconds)
        usage.frequency = frequencySampler.sample()
        return usage
    }

    mutating func sampleTopApps(intervalSeconds: Double, processCount: Int) -> [GPUProcessInfo] {
        let result = Self.computeTopApps(
            currentSnapshots: readAppUsageSnapshots(),
            previousTotalsByPID: previousAppTotalsByPID,
            intervalSeconds: intervalSeconds,
            processCount: processCount
        )
        previousAppTotalsByPID = result.updatedTotalsByPID
        return result.apps
    }

    static func parseUsage(from performanceStatistics: [String: Any]) -> GPUUsage {
        var deviceUtil: Double = 0
        var renderUtil: Double = 0
        var tilerUtil: Double = 0
        var engines: [String: Double] = [:]

        for (key, value) in performanceStatistics where key.hasSuffix("Utilization %") {
            guard let utilization = numericDouble(from: value) else { continue }
            let label = key.replacingOccurrences(of: " Utilization %", with: "")
            engines[label] = max(engines[label] ?? 0, utilization)

            switch key {
            case "Device Utilization %":
                deviceUtil = max(deviceUtil, utilization)
            case "Renderer Utilization %":
                renderUtil = max(renderUtil, utilization)
            case "Tiler Utilization %":
                tilerUtil = max(tilerUtil, utilization)
            default:
                break
            }
        }

        return GPUUsage(
            deviceUtilization: deviceUtil,
            renderUtilization: renderUtil,
            tilerUtilization: tilerUtil,
            engines: engines,
            vramUsed: numericUInt64(from: performanceStatistics["In use system memory"]) ?? 0,
            driverMemoryBytes: numericUInt64(from: performanceStatistics["In use system memory (driver)"]) ?? 0,
            allocatedMemoryBytes: numericUInt64(from: performanceStatistics["Alloc system memory"]) ?? 0
        )
    }

    static func computeTopApps(
        currentSnapshots: [AppUsageSnapshot],
        previousTotalsByPID: [Int: UInt64],
        intervalSeconds: Double,
        processCount: Int
    ) -> (apps: [GPUProcessInfo], updatedTotalsByPID: [Int: UInt64]) {
        var currentTotalsByPID: [Int: (name: String, total: UInt64, queues: Int)] = [:]
        for snapshot in currentSnapshots {
            var current = currentTotalsByPID[snapshot.pid] ?? (snapshot.name, 0, 0)
            current.name = snapshot.name
            current.total += snapshot.accumulatedGPUTime
            current.queues += snapshot.commandQueueCount
            currentTotalsByPID[snapshot.pid] = current
        }

        let apps = currentTotalsByPID.compactMap { pid, snapshot -> GPUProcessInfo? in
            guard intervalSeconds > 0 else { return nil }
            let previousTotal = previousTotalsByPID[pid] ?? 0
            let delta = snapshot.total > previousTotal ? snapshot.total - previousTotal : 0
            guard delta > 0 else { return nil }
            let utilizationPercent = min(Double(delta) / (intervalSeconds * 1_000_000_000) * 100, 100)
            return GPUProcessInfo(
                pid: pid,
                name: snapshot.name,
                utilizationPercent: utilizationPercent,
                commandQueueCount: snapshot.queues
            )
        }
        .sorted {
            if $0.utilizationPercent == $1.utilizationPercent {
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            return $0.utilizationPercent > $1.utilizationPercent
        }

        let updatedTotals = Dictionary(uniqueKeysWithValues: currentTotalsByPID.map { ($0.key, $0.value.total) })
        return (Array(apps.prefix(processCount)), updatedTotals)
    }

    private mutating func readAppUsageSnapshots() -> [AppUsageSnapshot] {
        let matchingDict = IOServiceMatching("AGXDeviceUserClient")
        var iterator: io_iterator_t = 0

        guard IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator) == KERN_SUCCESS else {
            return []
        }
        defer { IOObjectRelease(iterator) }

        var snapshots: [AppUsageSnapshot] = []
        var service: io_object_t = IOIteratorNext(iterator)
        while service != IO_OBJECT_NULL {
            defer { IOObjectRelease(service) }

            var props: Unmanaged<CFMutableDictionary>?
            if IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
               let dict = props?.takeRetainedValue() as? [String: Any],
               let snapshot = Self.parseAppUsageSnapshot(from: dict) {
                snapshots.append(snapshot)
            }

            service = IOIteratorNext(iterator)
        }

        return snapshots
    }

    private static func parseAppUsageSnapshot(from properties: [String: Any]) -> AppUsageSnapshot? {
        guard
            let creator = properties["IOUserClientCreator"] as? String,
            let (pid, name) = parseCreator(creator),
            let appUsage = properties["AppUsage"] as? [[String: Any]],
            !appUsage.isEmpty
        else { return nil }

        let accumulatedGPUTime = appUsage.reduce(into: UInt64(0)) { total, entry in
            total += numericUInt64(from: entry["accumulatedGPUTime"]) ?? 0
        }
        guard accumulatedGPUTime > 0 else { return nil }

        return AppUsageSnapshot(
            pid: pid,
            name: name,
            accumulatedGPUTime: accumulatedGPUTime,
            commandQueueCount: numericInt(from: properties["CommandQueueCount"]) ?? 0
        )
    }

    private static func parseCreator(_ creator: String) -> (pid: Int, name: String)? {
        let parts = creator.split(separator: ",", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return nil }
        let pidText = parts[0].replacingOccurrences(of: "pid ", with: "").trimmingCharacters(in: .whitespaces)
        let name = parts[1].trimmingCharacters(in: .whitespaces)
        guard let pid = Int(pidText), !name.isEmpty else { return nil }
        return (pid, name)
    }

    private static func merge(_ lhs: GPUUsage, with rhs: GPUUsage) -> GPUUsage {
        var engines = lhs.engines
        for (name, utilization) in rhs.engines {
            engines[name] = max(engines[name] ?? 0, utilization)
        }

        return GPUUsage(
            deviceUtilization: max(lhs.deviceUtilization, rhs.deviceUtilization),
            renderUtilization: max(lhs.renderUtilization, rhs.renderUtilization),
            tilerUtilization: max(lhs.tilerUtilization, rhs.tilerUtilization),
            engines: engines,
            vramUsed: max(lhs.vramUsed, rhs.vramUsed),
            driverMemoryBytes: max(lhs.driverMemoryBytes, rhs.driverMemoryBytes),
            allocatedMemoryBytes: max(lhs.allocatedMemoryBytes, rhs.allocatedMemoryBytes),
            anePowerMilliWatts: max(lhs.anePowerMilliWatts, rhs.anePowerMilliWatts)
        )
    }

    private static func numericDouble(from value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }

    private static func numericUInt64(from value: Any?) -> UInt64? {
        if let value = value as? UInt64 { return value }
        if let value = value as? Int { return value >= 0 ? UInt64(value) : nil }
        if let value = value as? NSNumber { return value.uint64Value }
        return nil
    }

    private static func numericInt(from value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }
}

private final class FrequencySampler: @unchecked Sendable {
    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?

    private var freqTable: [UInt64] = []
    private let lib: UnsafeMutableRawPointer?

    private let copyChannels: CopyChannelsFn?
    private let createSubscription: CreateSubFn?
    private let createSamples: CreateSamplesFn?
    private let createDelta: CreateDeltaFn?
    private let stateGetCount: StateCountFn?
    private let stateGetResidency: StateResidencyFn?

    init() {
        lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY)

        guard let lib else {
            copyChannels = nil
            createSubscription = nil
            createSamples = nil
            createDelta = nil
            stateGetCount = nil
            stateGetResidency = nil
            return
        }

        copyChannels = Self.loadFn(lib, "IOReportCopyChannelsInGroup")
        createSubscription = Self.loadFn(lib, "IOReportCreateSubscription")
        createSamples = Self.loadFn(lib, "IOReportCreateSamples")
        createDelta = Self.loadFn(lib, "IOReportCreateSamplesDelta")
        stateGetCount = Self.loadFn(lib, "IOReportStateGetCount")
        stateGetResidency = Self.loadFn(lib, "IOReportStateGetResidency")

        guard copyChannels != nil,
              createSubscription != nil,
              createSamples != nil,
              createDelta != nil,
              stateGetCount != nil,
              stateGetResidency != nil else {
            return
        }

        readFrequencyTable()
        setupSubscription()
    }

    deinit {
        if let lib { dlclose(lib) }
    }

    func sample() -> CPUCoreFrequency? {
        guard let subscription,
              let createSamples,
              let createDelta,
              let stateGetCount,
              let stateGetResidency,
              !freqTable.isEmpty else {
            return nil
        }

        guard let newSampleRef = createSamples(subscription, optionsDict, nil) else { return nil }
        let newSample = newSampleRef.takeRetainedValue()
        defer { previousSample = newSample }

        guard let previousSample,
              let deltaRef = createDelta(previousSample, newSample, nil) else {
            return nil
        }
        let delta = deltaRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArray = CFDictionaryGetValue(delta, Unmanaged.passUnretained(channelsKey).toOpaque()) else {
            return nil
        }
        let channels = Unmanaged<CFArray>.fromOpaque(rawArray).takeUnretainedValue()

        var activeResidency: Int64 = 0
        var weightedHz: Double = 0

        for index in 0..<CFArrayGetCount(channels) {
            let channel = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(channels, index)!).takeUnretainedValue()
            let stateCount = stateGetCount(channel)
            guard stateCount > 1 else { continue }

            let upperBound = min(Int(stateCount), freqTable.count)
            for stateIndex in 1..<upperBound {
                let residency = stateGetResidency(channel, Int32(stateIndex))
                guard residency > 0 else { continue }
                activeResidency += residency
                weightedHz += Double(freqTable[stateIndex]) * Double(residency)
            }
        }

        let currentHz = activeResidency > 0 ? UInt64(weightedHz / Double(activeResidency)) : 0
        return CPUCoreFrequency(currentHz: currentHz, maxHz: freqTable.last ?? 0)
    }

    private func setupSubscription() {
        guard let copyChannels,
              let createSubscription else {
            return
        }

        guard let channelReference = copyChannels(
            "GPU Stats" as CFString,
            "GPU Performance States" as CFString,
            0,
            nil,
            nil
        ) else {
            return
        }
        let channels = channelReference.takeRetainedValue() as! CFMutableDictionary

        var optionsReference: Unmanaged<CFMutableDictionary>?
        subscription = createSubscription(nil, channels, &optionsReference, 0, nil)
        optionsDict = optionsReference?.takeUnretainedValue()
    }

    private func readFrequencyTable() {
        let powerManager = IORegistryEntryFromPath(kIOMainPortDefault, "IODeviceTree:/arm-io/pmgr")
        guard powerManager != 0 else { return }
        defer { IOObjectRelease(powerManager) }

        var bestTable: [UInt64] = []
        for index in 0..<16 {
            let key = "voltage-states\(index)-sram"
            guard let data = IORegistryEntryCreateCFProperty(powerManager, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Data else {
                continue
            }

            let entryCount = data.count / 8
            guard entryCount > 1 else { continue }

            let frequencies = (0..<entryCount).map { offset in
                UInt64(data.withUnsafeBytes { $0.load(fromByteOffset: offset * 8, as: UInt32.self) })
            }

            guard frequencies.first == 0, frequencies.count > bestTable.count else { continue }
            bestTable = frequencies
        }
        freqTable = bestTable
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
}

private final class NeuralEnginePowerSampler: @unchecked Sendable {
    private var subscription: OpaquePointer?
    private var previousSample: CFDictionary?
    private var optionsDict: CFMutableDictionary?
    private let lib: UnsafeMutableRawPointer?

    private let createSamples: CreateSamplesFn?
    private let createDelta: CreateDeltaFn?
    private let channelName: GetStringFn?
    private let getInt: SimpleGetIntFn?

    init() {
        lib = dlopen("/usr/lib/libIOReport.dylib", RTLD_LAZY)

        guard let lib else {
            createSamples = nil
            createDelta = nil
            channelName = nil
            getInt = nil
            return
        }

        createSamples = Self.loadFn(lib, "IOReportCreateSamples")
        createDelta = Self.loadFn(lib, "IOReportCreateSamplesDelta")
        channelName = Self.loadFn(lib, "IOReportChannelGetChannelName")
        getInt = Self.loadFn(lib, "IOReportSimpleGetIntegerValue")

        guard createSamples != nil,
              createDelta != nil,
              channelName != nil,
              getInt != nil else {
            return
        }

        setupSubscription()
    }

    deinit {
        if let lib { dlclose(lib) }
    }

    func sample(intervalSeconds: Double) -> Double {
        guard let subscription,
              let createSamples,
              let createDelta,
              let channelName,
              let getInt,
              intervalSeconds > 0 else {
            return 0
        }

        guard let newSampleRef = createSamples(subscription, optionsDict, nil) else { return 0 }
        let newSample = newSampleRef.takeRetainedValue()
        defer { previousSample = newSample }

        guard let previousSample,
              let deltaRef = createDelta(previousSample, newSample, nil) else {
            return 0
        }
        let delta = deltaRef.takeRetainedValue()

        let channelsKey = "IOReportChannels" as CFString
        guard let rawArray = CFDictionaryGetValue(delta, Unmanaged.passUnretained(channelsKey).toOpaque()) else {
            return 0
        }
        let channels = Unmanaged<CFArray>.fromOpaque(rawArray).takeUnretainedValue()

        var totalMilliJoules: Int64 = 0
        for index in 0..<CFArrayGetCount(channels) {
            let channel = Unmanaged<CFDictionary>.fromOpaque(CFArrayGetValueAtIndex(channels, index)!).takeUnretainedValue()
            let name = channelName(channel)?.takeUnretainedValue() as String? ?? ""
            guard name == "ANE" || name.hasPrefix("ANE0") else { continue }
            totalMilliJoules += getInt(channel, 0)
        }

        return Double(max(0, totalMilliJoules)) / intervalSeconds
    }

    private func setupSubscription() {
        guard let lib else { return }
        guard let copyChannels: CopyChannelsFn = Self.loadFn(lib, "IOReportCopyChannelsInGroup"),
              let createSubscription: CreateSubFn = Self.loadFn(lib, "IOReportCreateSubscription") else {
            return
        }

        guard let channelReference = copyChannels("Energy Model" as CFString, nil, 0, nil, nil) else { return }
        let channels = channelReference.takeRetainedValue() as! CFMutableDictionary

        var optionsReference: Unmanaged<CFMutableDictionary>?
        subscription = createSubscription(nil, channels, &optionsReference, 0, nil)
        optionsDict = optionsReference?.takeUnretainedValue()
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

    private typealias GetStringFn = @convention(c) (CFDictionary) -> Unmanaged<CFString>?
    private typealias SimpleGetIntFn = @convention(c) (CFDictionary, Int32) -> Int64
}
