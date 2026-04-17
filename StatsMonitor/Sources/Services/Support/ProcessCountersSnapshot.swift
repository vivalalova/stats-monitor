import Foundation
import Darwin

struct ProcessCountersSnapshot: Sendable {
    struct Entry: Sendable {
        var pid: Int32
        var name: String
        var cpuTicks: UInt64
        var memoryBytes: UInt64
        var diskReadBytes: UInt64
        var diskWriteBytes: UInt64
        var powerImpact: Double
    }

    var entries: [Entry]
    var date: Date
}

enum ProcessCountersReader {
    static func sample() -> ProcessCountersSnapshot? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return nil }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return nil }

        let powerByPID = PowerMonitor.samplePowerImpactByPID()
        let entries = procs.compactMap { makeEntry(from: $0, powerByPID: powerByPID) }
        return ProcessCountersSnapshot(entries: entries, date: .now)
    }

    private static func makeEntry(from proc: kinfo_proc, powerByPID: [Int32: Double]) -> ProcessCountersSnapshot.Entry? {
        let pid = proc.kp_proc.p_pid
        guard pid > 0 else { return nil }

        var taskInfo = proc_taskinfo()
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
        let taskResult = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize)
        guard taskResult > 0 else { return nil }

        var diskReadBytes: UInt64 = 0
        var diskWriteBytes: UInt64 = 0
        var rusageInfo = rusage_info_current()
        let rusageResult = withUnsafeMutablePointer(to: &rusageInfo) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
            }
        }
        if rusageResult == 0 {
            diskReadBytes = rusageInfo.ri_diskio_bytesread
            diskWriteBytes = rusageInfo.ri_diskio_byteswritten
        }

        return ProcessCountersSnapshot.Entry(
            pid: pid,
            name: processName(from: proc),
            cpuTicks: taskInfo.pti_total_user + taskInfo.pti_total_system,
            memoryBytes: taskInfo.pti_resident_size,
            diskReadBytes: diskReadBytes,
            diskWriteBytes: diskWriteBytes,
            powerImpact: powerByPID[pid] ?? 0
        )
    }

    private static func processName(from proc: kinfo_proc) -> String {
        withUnsafeBytes(of: proc.kp_proc.p_comm) { ptr in
            let buffer = ptr.bindMemory(to: CChar.self)
            return buffer.baseAddress.map { String(cString: $0) } ?? "?"
        }
    }
}
