import Foundation
import Darwin

struct CPUMonitor {
    private var previousTicks: [processor_cpu_load_info] = []
    private var cachedMaxHz: [UInt64] = []   // per-core max, built once

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
        if cachedMaxHz.isEmpty {
            cachedMaxHz = queryMaxFrequencies(coreCount: coreCount)
        }
        let currentHz = queryCurrentHz()
        return cachedMaxHz.map { CPUCoreFrequency(currentHz: currentHz, maxHz: $0) }
    }

    /// Per-core max frequency: reads chip brand string and maps to known clock speeds.
    /// Falls back to hw.cpufrequency_max (Intel) if brand string not recognized.
    private func queryMaxFrequencies(coreCount: Int) -> [UInt64] {
        // Try to build from perflevel cluster data (works on some macOS + chip combos)
        var result = queryPerfLevelFrequencies()
        if !result.isEmpty { return result }

        // Apple Silicon lookup by chip brand string
        result = brandStringFrequencies()
        if !result.isEmpty { return result }

        // Intel fallback
        var hz: UInt64 = 0
        var hzSize = MemoryLayout<UInt64>.size
        sysctlbyname("hw.cpufrequency_max", &hz, &hzSize, nil, 0)
        return Array(repeating: hz, count: coreCount)
    }

    private func queryPerfLevelFrequencies() -> [UInt64] {
        var result: [UInt64] = []
        var level = 0
        while level < 8 {
            var n: Int32 = 0; var nSize = MemoryLayout<Int32>.size
            guard sysctlbyname("hw.perflevel\(level).physicalcpu", &n, &nSize, nil, 0) == 0, n > 0 else { break }
            var hz: UInt64 = 0; var hzSize = MemoryLayout<UInt64>.size
            // key does not exist on most Apple Silicon—will stay 0
            sysctlbyname("hw.perflevel\(level).maxfreq", &hz, &hzSize, nil, 0)
            guard hz > 0 else { return [] }  // incomplete data, bail out
            for _ in 0..<Int(n) { result.append(hz) }
            level += 1
        }
        return result
    }

    /// Lookup table: (P-core max Hz, E-core max Hz) keyed by chip generation.
    /// Per-level core counts come from hw.perflevelN.physicalcpu.
    private func brandStringFrequencies() -> [UInt64] {
        var brand = [CChar](repeating: 0, count: 256)
        var brandSize = brand.count
        guard sysctlbyname("machdep.cpu.brand_string", &brand, &brandSize, nil, 0) == 0 else { return [] }
        let name = String(cString: brand).uppercased()

        // (P-core Hz, E-core Hz)
        let freqs: (UInt64, UInt64)?
        switch true {
        case name.contains("M4"): freqs = (4_400_000_000, 2_900_000_000)
        case name.contains("M3"): freqs = (4_050_000_000, 2_750_000_000)
        case name.contains("M2"): freqs = (3_490_000_000, 2_420_000_000)
        case name.contains("M1"): freqs = (3_228_000_000, 2_064_000_000)
        default:                  freqs = nil
        }
        guard let (pHz, eHz) = freqs else { return [] }

        var result: [UInt64] = []
        var level = 0
        while level < 8 {
            var n: Int32 = 0; var nSize = MemoryLayout<Int32>.size
            guard sysctlbyname("hw.perflevel\(level).physicalcpu", &n, &nSize, nil, 0) == 0, n > 0 else { break }
            // perflevel0 = Performance, perflevel1 = Efficiency
            let hz: UInt64 = level == 0 ? pHz : eHz
            for _ in 0..<Int(n) { result.append(hz) }
            level += 1
        }
        return result
    }

    /// Current CPU frequency — unavailable on Apple Silicon without private APIs.
    private func queryCurrentHz() -> UInt64 {
        var hz: UInt64 = 0; var hzSize = MemoryLayout<UInt64>.size
        if sysctlbyname("hw.cpufrequency", &hz, &hzSize, nil, 0) == 0, hz > 0 { return hz }
        return 0
    }
}
