import Foundation

/// Per-process network I/O via /usr/bin/nettop subprocess.
/// The `run` function is nonisolated and safe to call from a detached Task.
struct NetworkProcessMonitor {

    struct Snapshot: Sendable {
        var bytesIn:  UInt64
        var bytesOut: UInt64
        var date:     Date
    }

    /// Spawns nettop, parses CSV output, computes bytes/sec deltas.
    /// - Parameters:
    ///   - previous: previous cumulative samples keyed by "procname.pid"
    /// - Returns: top processes sorted by total bandwidth, plus updated snapshots
    static func run(
        previous: [String: Snapshot]
    ) -> (procs: [ProcInfo], updated: [String: Snapshot]) {

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        // -P: per-process  -L 1: one sample then exit  -n: no DNS
        // -k: exclude listed columns → leaves procname.pid, bytes_in, bytes_out
        task.arguments = [
            "-P", "-L", "1", "-n",
            "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg," +
                  "rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError  = Pipe()   // discard stderr

        do { try task.run() } catch { return ([], previous) }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard let output = String(data: data, encoding: .utf8) else {
            return ([], previous)
        }

        let now   = Date.now
        var current:  [String: (in: UInt64, out: UInt64)] = [:]
        var updated:  [String: Snapshot] = [:]
        var results:  [ProcInfo] = []

        let lines = output.components(separatedBy: "\n")
        for line in lines.dropFirst() {          // first line is header
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 3 else { continue }
            let key      = parts[0].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            let bytesIn  = UInt64(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0
            let bytesOut = UInt64(parts[2].trimmingCharacters(in: .whitespaces)) ?? 0
            current[key] = (bytesIn, bytesOut)
        }

        for (key, cur) in current {
            // Extract process name (strip trailing ".PID")
            let name: String
            if let lastDot = key.lastIndex(of: ".") {
                name = String(key[..<lastDot])
            } else {
                name = key
            }

            var netInBPS  = 0.0
            var netOutBPS = 0.0

            if let prev = previous[key] {
                let elapsed = now.timeIntervalSince(prev.date)
                if elapsed > 0 {
                    // Safe subtraction: treat counter reset (process restart) as 0 delta
                    netInBPS  = cur.in  >= prev.bytesIn  ? Double(cur.in  - prev.bytesIn)  / elapsed : 0
                    netOutBPS = cur.out >= prev.bytesOut ? Double(cur.out - prev.bytesOut) / elapsed : 0
                }
            }

            updated[key] = Snapshot(bytesIn: cur.in, bytesOut: cur.out, date: now)

            if netInBPS > 0 || netOutBPS > 0 {
                results.append(ProcInfo(
                    name:         name,
                    cpuPercent:   0,
                    memoryBytes:  0,
                    networkInBPS:  max(0, netInBPS),
                    networkOutBPS: max(0, netOutBPS)
                ))
            }
        }

        let topProcs = Array(
            results
                .sorted { $0.networkTotalBPS > $1.networkTotalBPS }
                .prefix(10)
        )
        return (topProcs, updated)
    }
}
