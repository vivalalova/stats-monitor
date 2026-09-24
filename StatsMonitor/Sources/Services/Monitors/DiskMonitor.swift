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
    private var cachedCapacity: (used: UInt64, total: UInt64, date: Date)?

    /// Querying important-usage capacity triggers cache_delete accounting (heavy system logging), so refresh it slowly.
    private static let capacityRefreshInterval: TimeInterval = 60

    mutating func sample() -> DiskUsage {
        let now = Date.now
        if cachedCapacity.map({ now.timeIntervalSince($0.date) >= Self.capacityRefreshInterval }) ?? true,
           let capacity = Self.readCapacity() {
            cachedCapacity = (capacity.used, capacity.total, now)
        }

        // Disk I/O via IOKit IOBlockStorageDriver
        let (curRead, curWrite) = ioBytes()
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

        return DiskUsage(used: cachedCapacity?.used ?? 0,
                         total: cachedCapacity?.total ?? 0,
                         readBPS: readBPS,
                         writeBPS: writeBPS)
    }

    /// Uses volumeAvailableCapacityForImportantUsage to include APFS purgeable space, matching macOS Storage.
    private static func readCapacity() -> (used: UInt64, total: UInt64)? {
        guard let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityForImportantUsageKey
        ]),
              let total = values.volumeTotalCapacity,
              let free = values.volumeAvailableCapacityForImportantUsage
        else { return nil }
        let totalBytes = UInt64(max(total, 0))
        let freeBytes = UInt64(max(free, 0))
        return (totalBytes > freeBytes ? totalBytes - freeBytes : 0, totalBytes)
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
            guard let previous = previousSnapshots[entry.pid],
                  let readBytes = entry.diskReadBytes,
                  let writeBytes = entry.diskWriteBytes else { return nil }
            let elapsed = snapshot.date.timeIntervalSince(previous.date)
            guard elapsed > 0 else { return nil }

            let readDelta = readBytes >= previous.readBytes ? readBytes - previous.readBytes : 0
            let writeDelta = writeBytes >= previous.writeBytes ? writeBytes - previous.writeBytes : 0
            guard readDelta > 0 || writeDelta > 0 else { return nil }

            return ProcInfo(
                pid: Int(entry.pid),
                name: entry.name,
                memoryBytes: entry.memoryBytes,
                diskReadBPS: Double(readDelta) / elapsed,
                diskWriteBPS: Double(writeDelta) / elapsed
            )
        }

        return Array(processes.sorted { ($0.diskTotalBPS ?? 0) > ($1.diskTotalBPS ?? 0) }.prefix(processCount))
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
        // Other users' processes carry no disk counters (no unprivileged source), so they never enter this table.
        previousSnapshots = Dictionary(
            uniqueKeysWithValues: snapshot.entries.compactMap { entry in
                guard let readBytes = entry.diskReadBytes, let writeBytes = entry.diskWriteBytes else { return nil }
                return (
                    entry.pid,
                    DiskMonitor.ProcessSnapshot(readBytes: readBytes, writeBytes: writeBytes, date: snapshot.date)
                )
            }
        )
        return processes
    }
}
