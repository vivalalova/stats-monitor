import Foundation
import Darwin

struct ProcessMonitor {
    // pid -> (cumulative CPU ns, timestamp)
    private var previousSamples: [Int32: (ticks: UInt64, date: Date)] = [:]

    mutating func sample() -> (cpuTop: [ProcInfo], memoryTop: [ProcInfo]) {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return ([], []) }

        let count = size / MemoryLayout<kinfo_proc>.size
        var procs = [kinfo_proc](repeating: kinfo_proc(), count: count)
        guard sysctl(&mib, 4, &procs, &size, nil, 0) == 0 else { return ([], []) }

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
            if let prev = previousSamples[pid] {
                let elapsed = now.timeIntervalSince(prev.date)
                if elapsed > 0 {
                    // pti_total_user/system are in nanoseconds
                    let deltaNS = Double(currentTicks &- prev.ticks)
                    cpuPercent = (deltaNS / 1_000_000_000.0) / elapsed * 100.0
                }
            }
            previousSamples[pid] = (currentTicks, now)

            infos.append(ProcInfo(name: name, cpuPercent: cpuPercent, memoryBytes: memBytes))
        }

        // Prune stale PIDs
        let activePIDs = Set(procs.map { $0.kp_proc.p_pid })
        previousSamples = previousSamples.filter { activePIDs.contains($0.key) }

        let cpuTop = Array(infos.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(5))
        let memTop = Array(infos.sorted { $0.memoryBytes > $1.memoryBytes }.prefix(5))
        return (cpuTop, memTop)
    }
}
