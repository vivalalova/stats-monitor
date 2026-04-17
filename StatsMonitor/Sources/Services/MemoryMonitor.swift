import Foundation
import Darwin

struct MemoryMonitor: Sendable {
    func sample() -> MemoryUsage {
        let total = ProcessInfo.processInfo.physicalMemory

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard kr == KERN_SUCCESS else {
            return MemoryUsage(active: 0, wired: 0, compressed: 0, total: total)
        }

        let pageSize = UInt64(sysconf(_SC_PAGESIZE))
        let active     = UInt64(stats.active_count) * pageSize
        let wired      = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let swapUsage = Self.readSwapUsage()
        let availablePercent = Self.readAvailablePercent()

        return MemoryUsage(
            active:     min(active, total),
            wired:      min(wired, total),
            compressed: min(compressed, total - min(active + wired, total)),
            total:      total,
            swapUsed:   swapUsage?.used ?? 0,
            swapTotal:  swapUsage?.total ?? 0,
            availablePercent: availablePercent
        )
    }

    func sampleTopProcesses(from snapshot: ProcessCountersSnapshot, processCount: Int = 10) -> [ProcInfo] {
        Self.computeTopProcesses(snapshot: snapshot, processCount: processCount)
    }

    static func computeTopProcesses(snapshot: ProcessCountersSnapshot, processCount: Int) -> [ProcInfo] {
        Array(
            snapshot.entries
                .map { entry in
                    ProcInfo(
                        name: entry.name,
                        cpuPercent: 0,
                        memoryBytes: entry.memoryBytes
                    )
                }
                .sorted { $0.memoryBytes > $1.memoryBytes }
                .prefix(processCount)
        )
    }

    static func pressureLevel(forAvailablePercent availablePercent: Double?) -> MemoryPressureLevel {
        guard let availablePercent else { return .unknown }
        switch availablePercent {
        case 40...:
            return .normal
        case 25..<40:
            return .warning
        case 10..<25:
            return .urgent
        default:
            return .critical
        }
    }

    static func readAvailablePercent() -> Double? {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = withUnsafeMutablePointer(to: &value) { pointer in
            sysctlbyname("kern.memorystatus_level", pointer, &size, nil, 0)
        }
        guard result == 0, value >= 0 else { return nil }
        return Double(value)
    }

    private static func readSwapUsage() -> (used: UInt64, total: UInt64)? {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = withUnsafeMutablePointer(to: &swapUsage) { pointer in
            sysctlbyname("vm.swapusage", pointer, &size, nil, 0)
        }
        guard result == 0 else { return nil }
        return (used: swapUsage.xsu_used, total: swapUsage.xsu_total)
    }
}
