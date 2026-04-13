import Foundation
import Darwin

struct MemoryMonitor {
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

        return MemoryUsage(
            active:     min(active, total),
            wired:      min(wired, total),
            compressed: min(compressed, total - min(active + wired, total)),
            total:      total
        )
    }
}
