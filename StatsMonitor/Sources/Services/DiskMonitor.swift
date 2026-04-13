import Foundation
import IOKit

struct DiskMonitor {
    private var previousRead:  UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousDate:  Date   = .now

    mutating func sample() -> DiskUsage {
        // Disk space
        let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/")
        let total = attrs?[.systemSize]     as? UInt64 ?? 0
        let free  = attrs?[.systemFreeSize] as? UInt64 ?? 0

        // Disk I/O via IOKit IOBlockStorageDriver
        let (curRead, curWrite) = ioBytes()
        let now = Date.now
        let elapsed = now.timeIntervalSince(previousDate)

        var readBPS  = 0.0
        var writeBPS = 0.0

        if elapsed > 0, previousRead > 0 || previousWrite > 0 {
            readBPS  = curRead  >= previousRead  ? Double(curRead  - previousRead)  / elapsed : 0
            writeBPS = curWrite >= previousWrite ? Double(curWrite - previousWrite) / elapsed : 0
        }

        previousRead  = curRead
        previousWrite = curWrite
        previousDate  = now

        return DiskUsage(used: total > free ? total - free : 0,
                         total: total,
                         readBPS: readBPS,
                         writeBPS: writeBPS)
    }

    private func ioBytes() -> (read: UInt64, write: UInt64) {
        var totalRead:  UInt64 = 0
        var totalWrite: UInt64 = 0

        let matching = IOServiceMatching("IOBlockStorageDriver")
        var iter: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter) == kIOReturnSuccess else {
            return (0, 0)
        }
        defer { IOObjectRelease(iter) }

        while case let service = IOIteratorNext(iter), service != 0 {
            defer { IOObjectRelease(service) }
            var cfProps: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(service, &cfProps,
                                                    kCFAllocatorDefault, 0) == kIOReturnSuccess,
                  let props = cfProps?.takeRetainedValue() as? [String: Any],
                  let stats = props["Statistics"] as? [String: Any]
            else { continue }

            totalRead  += stats["Bytes (Read)"]  as? UInt64 ?? 0
            totalWrite += stats["Bytes (Write)"] as? UInt64 ?? 0
        }

        return (totalRead, totalWrite)
    }
}
