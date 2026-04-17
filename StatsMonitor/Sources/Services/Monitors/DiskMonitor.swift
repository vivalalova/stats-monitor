import Foundation
import IOKit

struct DiskMonitor: Sendable {
    struct ProcessSnapshot: Sendable {
        var readBytes: UInt64
        var writeBytes: UInt64
        var date: Date
    }

    private var previousRead:  UInt64 = 0
    private var previousWrite: UInt64 = 0
    private var previousDate:  Date   = .now
    private let processSampler = DiskProcessSampler()

    mutating func sample() -> DiskUsage {
        // Disk space — use volumeAvailableCapacityForImportantUsage to include
        // APFS purgeable space, matching what macOS Storage reports.
        let url = URL(fileURLWithPath: "/")
        let res = try? url.resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ])
        let total = UInt64(res?.volumeTotalCapacity ?? 0)
        let free  = UInt64(res?.volumeAvailableCapacityForImportantUsage ?? 0)

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

    func sampleTopProcesses(from snapshot: ProcessCountersSnapshot, processCount: Int = 10) -> [ProcInfo] {
        processSampler.sampleTopProcesses(from: snapshot, processCount: processCount)
    }

    static func computeTopProcesses(
        snapshot: ProcessCountersSnapshot,
        previousSnapshots: [Int32: ProcessSnapshot],
        processCount: Int
    ) -> [ProcInfo] {
        let processes = snapshot.entries.compactMap { entry -> ProcInfo? in
            guard let previous = previousSnapshots[entry.pid] else { return nil }
            let elapsed = snapshot.date.timeIntervalSince(previous.date)
            guard elapsed > 0 else { return nil }

            let readDelta = entry.diskReadBytes >= previous.readBytes ? entry.diskReadBytes - previous.readBytes : 0
            let writeDelta = entry.diskWriteBytes >= previous.writeBytes ? entry.diskWriteBytes - previous.writeBytes : 0
            guard readDelta > 0 || writeDelta > 0 else { return nil }

            return ProcInfo(
                name: entry.name,
                cpuPercent: 0,
                memoryBytes: entry.memoryBytes,
                diskReadBPS: Double(readDelta) / elapsed,
                diskWriteBPS: Double(writeDelta) / elapsed
            )
        }

        return Array(processes.sorted { $0.diskTotalBPS > $1.diskTotalBPS }.prefix(processCount))
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

private final class DiskProcessSampler: @unchecked Sendable {
    private var previousSnapshots: [Int32: DiskMonitor.ProcessSnapshot] = [:]

    func sampleTopProcesses(from snapshot: ProcessCountersSnapshot, processCount: Int) -> [ProcInfo] {
        let processes = DiskMonitor.computeTopProcesses(
            snapshot: snapshot,
            previousSnapshots: previousSnapshots,
            processCount: processCount
        )
        previousSnapshots = Dictionary(
            uniqueKeysWithValues: snapshot.entries.map { entry in
                (
                    entry.pid,
                    DiskMonitor.ProcessSnapshot(
                        readBytes: entry.diskReadBytes,
                        writeBytes: entry.diskWriteBytes,
                        date: snapshot.date
                    )
                )
            }
        )
        return processes
    }
}
