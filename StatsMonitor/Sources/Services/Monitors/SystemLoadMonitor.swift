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

    static func readProcessCount() -> Int {
        let count = proc_listallpids(nil, 0)
        return count > 0 ? Int(count) : 0
    }
}
