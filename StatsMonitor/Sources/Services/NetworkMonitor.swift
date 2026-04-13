import Foundation
import Darwin

struct NetworkMonitor {
    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousDate: Date = .now

    mutating func sample() -> NetworkUsage {
        let (bytesIn, bytesOut) = totalBytes()
        let now = Date.now
        let elapsed = now.timeIntervalSince(previousDate)

        guard elapsed > 0, previousBytesIn > 0 || previousBytesOut > 0 else {
            previousBytesIn = bytesIn
            previousBytesOut = bytesOut
            previousDate = now
            return .zero
        }

        let inPerSec  = Double(bytesIn  - previousBytesIn)  / elapsed
        let outPerSec = Double(bytesOut - previousBytesOut) / elapsed

        previousBytesIn  = bytesIn
        previousBytesOut = bytesOut
        previousDate = now

        return NetworkUsage(
            bytesInPerSec:  max(0, inPerSec),
            bytesOutPerSec: max(0, outPerSec)
        )
    }

    private func totalBytes() -> (UInt64, UInt64) {
        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return (0, 0) }
        defer { freeifaddrs(firstAddr) }

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isRunning  = (flags & IFF_RUNNING)  != 0

            if !isLoopback, isRunning, ptr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
                totalIn  += UInt64(data?.pointee.ifi_ibytes ?? 0)
                totalOut += UInt64(data?.pointee.ifi_obytes ?? 0)
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return (totalIn, totalOut)
    }
}
