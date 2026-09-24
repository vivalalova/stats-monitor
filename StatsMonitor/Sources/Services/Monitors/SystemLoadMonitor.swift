import Foundation
import Darwin

enum SystemLoadMonitor {
    static func readLoadAverage() -> (one: Double, five: Double, fifteen: Double) {
        var loads = [Double](repeating: 0, count: 3)
        let count = loads.withUnsafeMutableBufferPointer { buffer in
            getloadavg(buffer.baseAddress, Int32(buffer.count))
        }
        guard count >= 3 else { return (0, 0, 0) }
        return (loads[0], loads[1], loads[2])
    }

    /// `proc_listallpids(nil, 0)` only returns a padded capacity hint, so fill a buffer and count what the kernel wrote.
    static func readProcessCount() -> Int {
        let hint = proc_listallpids(nil, 0)
        guard hint > 0 else { return 0 }
        let capacity = Int(hint) + 64
        var pids = [pid_t](repeating: 0, count: capacity)
        let count = pids.withUnsafeMutableBytes { buffer in
            proc_listallpids(buffer.baseAddress, Int32(buffer.count))
        }
        return count > 0 ? Int(count) : 0
    }
}
