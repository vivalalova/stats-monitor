import Foundation
import Darwin

struct CPUMonitor {
    private var previousTicks: [processor_cpu_load_info] = []
    private let frequencyMonitor = CPUFrequencyMonitor()

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
            // Prime the frequency monitor with first sample
            if frequencyMonitor.isAvailable { _ = frequencyMonitor.sample() }
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

    // MARK: - Frequency

    private mutating func buildCoreFrequencies(coreCount: Int) -> [CPUCoreFrequency] {
        // Apple Silicon: dynamic per-core frequency via IOReport DVFS residency
        if frequencyMonitor.isAvailable {
            let dynamic = frequencyMonitor.sample()
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
