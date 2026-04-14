import Foundation
import Darwin

struct ProcessMonitor: Sendable {
    // pid -> (cumulative CPU ns, timestamp)
    private var previousCPUSamples: [Int32: (ticks: UInt64, date: Date)] = [:]
    // pid -> (cumulative disk read bytes, cumulative disk write bytes, timestamp)
    private var previousDiskSamples: [Int32: (read: UInt64, write: UInt64, date: Date)] = [:]

    mutating func sample(processCount: Int = 10) -> (cpuTop: [ProcInfo], memoryTop: [ProcInfo], diskTop: [ProcInfo]) {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return ([], [], []) }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return ([], [], []) }

        var infos: [ProcInfo] = []
        let now = Date.now

        for proc in procs {
            let pid = proc.kp_proc.p_pid
            guard pid > 0 else { continue }

            var taskInfo = proc_taskinfo()
            let ret = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
            guard ret > 0 else { continue }

            let currentTicks = taskInfo.pti_total_user + taskInfo.pti_total_system
            let memBytes = taskInfo.pti_resident_size

            // Process name from p_comm (MAXCOMLEN+1 = 17 chars, null-terminated tuple)
            let name: String = withUnsafeBytes(of: proc.kp_proc.p_comm) { ptr in
                let buf = ptr.bindMemory(to: CChar.self)
                return buf.baseAddress.map { String(cString: $0) } ?? "?"
            }

            // CPU % based on tick delta since last poll
            var cpuPercent = 0.0
            if let prev = previousCPUSamples[pid] {
                let elapsed = now.timeIntervalSince(prev.date)
                if elapsed > 0 {
                    // pti_total_user/system are in nanoseconds
                    let deltaNS = currentTicks >= prev.ticks ? Double(currentTicks - prev.ticks) : 0
                    cpuPercent = (deltaNS / 1_000_000_000.0) / elapsed * 100.0
                }
            }
            previousCPUSamples[pid] = (currentTicks, now)

            // Disk I/O via proc_pid_rusage (cumulative since process start)
            var diskReadBPS = 0.0
            var diskWriteBPS = 0.0
            var rusageInfo = rusage_info_current()
            let diskRet = withUnsafeMutablePointer(to: &rusageInfo) {
                $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                    proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
                }
            }
            if diskRet == 0 {
                let curRead  = rusageInfo.ri_diskio_bytesread
                let curWrite = rusageInfo.ri_diskio_byteswritten
                if let prev = previousDiskSamples[pid] {
                    let elapsed = now.timeIntervalSince(prev.date)
                    if elapsed > 0 {
                        // Safe subtraction: treat counter reset as 0 delta
                        diskReadBPS  = curRead  >= prev.read  ? Double(curRead  - prev.read)  / elapsed : 0
                        diskWriteBPS = curWrite >= prev.write ? Double(curWrite - prev.write) / elapsed : 0
                    }
                }
                previousDiskSamples[pid] = (curRead, curWrite, now)
            }

            infos.append(ProcInfo(name: name, cpuPercent: cpuPercent,
                                  memoryBytes: memBytes,
                                  diskReadBPS: max(0, diskReadBPS),
                                  diskWriteBPS: max(0, diskWriteBPS)))
        }

        // Prune stale PIDs
        let activePIDs = Set(procs.map { $0.kp_proc.p_pid })
        previousCPUSamples  = previousCPUSamples.filter  { activePIDs.contains($0.key) }
        previousDiskSamples = previousDiskSamples.filter { activePIDs.contains($0.key) }

        let cpuTop  = Array(infos.sorted { $0.cpuPercent    > $1.cpuPercent    }.prefix(processCount))
        let memTop  = Array(infos.sorted { $0.memoryBytes   > $1.memoryBytes   }.prefix(processCount))
        let diskTop = Array(infos.filter { $0.diskTotalBPS  > 0 }
                                 .sorted { $0.diskTotalBPS  > $1.diskTotalBPS  }.prefix(processCount))
        return (cpuTop, memTop, diskTop)
    }
}
