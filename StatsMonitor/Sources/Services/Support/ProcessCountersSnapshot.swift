import Foundation
import Darwin

struct ProcessCountersSnapshot: Sendable {
    struct Entry: Sendable {
        var pid: Int32
        var name: String
        /// Cumulative mach ticks; nil for processes owned by other users (EPERM), whose CPU comes from `topCPUPercent`.
        var cpuTicks: UInt64?
        var memoryBytes: UInt64
        /// Cumulative disk I/O; nil when unprivileged — no non-root source exists for other users' processes.
        var diskReadBytes: UInt64?
        var diskWriteBytes: UInt64?
        var powerImpact: Double
        var topCPUPercent: Double? = nil
    }

    var entries: [Entry]
    var date: Date
}

struct TopProcessStats: Equatable, Sendable {
    var cpuPercent: Double?
    var memoryBytes: UInt64?
    var powerImpact: Double?
}

enum ProcessCountersReader {
    static func sample() -> ProcessCountersSnapshot? {
        guard let procs = readAllProcesses() else { return nil }
        let topStats = sampleTopStats()
        let entries = procs.compactMap { makeEntry(from: $0, topStats: topStats) }
        return ProcessCountersSnapshot(entries: entries, date: .now)
    }

    /// Size is padded because processes spawned between the size probe and the read make the kernel return ENOMEM.
    private static func readAllProcesses() -> [kinfo_proc]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        let stride = MemoryLayout<kinfo_proc>.stride
        for _ in 0..<3 {
            var size = 0
            guard sysctl(&mib, 4, nil, &size, nil, 0) == 0, size > 0 else { return nil }
            size += 64 * stride
            var procs = [kinfo_proc](repeating: kinfo_proc(), count: size / stride)
            let result = sysctl(&mib, 4, &procs, &size, nil, 0)
            if result == 0 { return Array(procs.prefix(size / stride)) }
            guard errno == ENOMEM else { return nil }
        }
        return nil
    }

    /// `/usr/bin/top` is setuid root, so it covers system processes that `proc_pidinfo` rejects with EPERM.
    static func sampleTopStats() -> [Int32: TopProcessStats] {
        guard let output = PowerMonitor.runProcessCapturingOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/top"),
            arguments: ["-l", "2", "-s", "0", "-o", "power", "-stats", "pid,command,cpu,mem,power"]
        ),
              output.terminationStatus == 0
        else {
            return [:]
        }
        return parseTopOutput(output.stdout)
    }

    /// Parses the last sample block of `top -l N -stats pid,command,...`; columns are located by header name.
    static func parseTopOutput(_ output: String) -> [Int32: TopProcessStats] {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: false)
        guard let headerIndex = lines.lastIndex(where: { $0.trimmingCharacters(in: .whitespaces).hasPrefix("PID") }) else {
            return [:]
        }
        let header = lines[headerIndex].split(whereSeparator: \.isWhitespace).map(String.init)
        guard header.count > 2 else { return [:] }
        let statColumns = Array(header.dropFirst(2))

        var statsByPID: [Int32: TopProcessStats] = [:]
        for line in lines[(headerIndex + 1)...] {
            let fields = line.split(whereSeparator: \.isWhitespace).map(String.init)
            // Command names may contain spaces, so stat fields are taken from the right.
            guard fields.count >= statColumns.count + 2, let pid = Int32(fields[0]) else { continue }
            let values = Dictionary(uniqueKeysWithValues: zip(statColumns, fields.suffix(statColumns.count)))
            statsByPID[pid] = TopProcessStats(
                cpuPercent: values["%CPU"].flatMap(Double.init),
                memoryBytes: values["MEM"].flatMap(parseTopMemory),
                powerImpact: values["POWER"].flatMap(Double.init)
            )
        }
        return statsByPID
    }

    /// Parses top's MEM column, e.g. `6384K+`, `25M`, `1.2G-`.
    static func parseTopMemory(_ text: String) -> UInt64? {
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "+-*"))
        guard let unit = trimmed.last else { return nil }
        let multiplier: Double
        switch unit {
        case "B": multiplier = 1
        case "K": multiplier = 1_024
        case "M": multiplier = 1_048_576
        case "G": multiplier = 1_073_741_824
        case "T": multiplier = 1_099_511_627_776
        default: return nil
        }
        guard let value = Double(trimmed.dropLast()), value >= 0 else { return nil }
        return UInt64(value * multiplier)
    }

    private static func makeEntry(from proc: kinfo_proc, topStats: [Int32: TopProcessStats]) -> ProcessCountersSnapshot.Entry? {
        let pid = proc.kp_proc.p_pid
        guard pid > 0 else { return nil }
        let top = topStats[pid]

        var taskInfo = proc_taskinfo()
        let taskInfoSize = Int32(MemoryLayout<proc_taskinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, taskInfoSize) > 0 else {
            guard let top else { return nil }
            return ProcessCountersSnapshot.Entry(
                pid: pid,
                name: processName(from: proc),
                cpuTicks: nil,
                memoryBytes: top.memoryBytes ?? 0,
                diskReadBytes: nil,
                diskWriteBytes: nil,
                powerImpact: top.powerImpact ?? 0,
                topCPUPercent: top.cpuPercent
            )
        }

        var rusageInfo = rusage_info_current()
        let rusageResult = withUnsafeMutablePointer(to: &rusageInfo) {
            $0.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) {
                proc_pid_rusage(pid, RUSAGE_INFO_CURRENT, $0)
            }
        }
        let hasRusage = rusageResult == 0

        return ProcessCountersSnapshot.Entry(
            pid: pid,
            name: processName(from: proc),
            cpuTicks: taskInfo.pti_total_user + taskInfo.pti_total_system,
            // Physical footprint matches top's MEM used for other users' processes.
            memoryBytes: hasRusage ? rusageInfo.ri_phys_footprint : taskInfo.pti_resident_size,
            diskReadBytes: hasRusage ? rusageInfo.ri_diskio_bytesread : nil,
            diskWriteBytes: hasRusage ? rusageInfo.ri_diskio_byteswritten : nil,
            powerImpact: top?.powerImpact ?? 0
        )
    }

    private static func processName(from proc: kinfo_proc) -> String {
        withUnsafeBytes(of: proc.kp_proc.p_comm) { ptr in
            let buffer = ptr.bindMemory(to: CChar.self)
            return buffer.baseAddress.map { String(cString: $0) } ?? "?"
        }
    }
}
