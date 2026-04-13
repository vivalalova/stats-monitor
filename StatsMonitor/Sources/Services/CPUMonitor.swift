import Foundation
import Darwin

struct CPUMonitor {
    private var previousTicks: [processor_cpu_load_info] = []

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
        }

        previousTicks = ticks

        let total = totalUser + totalSystem + totalIdle + totalNice
        guard total > 0 else { return .zero }

        return CPUUsage(
            user:   Double(totalUser + totalNice) / Double(total) * 100,
            system: Double(totalSystem) / Double(total) * 100,
            idle:   Double(totalIdle) / Double(total) * 100
        )
    }
}
