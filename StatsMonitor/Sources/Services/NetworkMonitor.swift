import Foundation
import Darwin

struct NetworkMonitor: Sendable {
    struct ProcessSnapshot: Sendable {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var date: Date
    }

    private var previousBytesIn: UInt64 = 0
    private var previousBytesOut: UInt64 = 0
    private var previousInterfaceCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private var previousProcessSnapshots: [String: ProcessSnapshot] = [:]
    private var previousDate: Date = .now

    mutating func sample() -> NetworkUsage {
        let interfaces = interfaceCounters()
        let bytesIn = interfaces.values.reduce(0) { $0 + $1.bytesIn }
        let bytesOut = interfaces.values.reduce(0) { $0 + $1.bytesOut }
        let now = Date.now
        let elapsed = now.timeIntervalSince(previousDate)

        guard elapsed > 0, previousBytesIn > 0 || previousBytesOut > 0 else {
            previousBytesIn = bytesIn
            previousBytesOut = bytesOut
            previousInterfaceCounters = interfaces
            previousDate = now
            return .zero
        }

        let inPerSec  = Double(bytesIn  - previousBytesIn)  / elapsed
        let outPerSec = Double(bytesOut - previousBytesOut) / elapsed
        let interfaceUsage = Self.computeInterfaceUsage(
            currentCounters: interfaces,
            previousCounters: previousInterfaceCounters,
            elapsed: elapsed
        )

        previousBytesIn  = bytesIn
        previousBytesOut = bytesOut
        previousInterfaceCounters = interfaces
        previousDate = now

        return NetworkUsage(
            bytesInPerSec:  max(0, inPerSec),
            bytesOutPerSec: max(0, outPerSec),
            interfaces: interfaceUsage
        )
    }

    mutating func sampleTopProcesses(processCount: Int = 10) -> [ProcInfo] {
        guard let currentCounters = Self.readProcessCounters() else { return [] }
        let now = Date.now
        let processes = Self.computeTopProcesses(
            currentCounters: currentCounters,
            previousSnapshots: previousProcessSnapshots,
            now: now,
            processCount: processCount
        )
        previousProcessSnapshots = Dictionary(
            uniqueKeysWithValues: currentCounters.map { key, value in
                (key, ProcessSnapshot(bytesIn: value.bytesIn, bytesOut: value.bytesOut, date: now))
            }
        )
        return processes
    }

    private func interfaceCounters() -> [String: (bytesIn: UInt64, bytesOut: UInt64)] {
        var counters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return [:] }
        defer { freeifaddrs(firstAddr) }

        var ptr = firstAddr
        while true {
            let flags = Int32(ptr.pointee.ifa_flags)
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            let isRunning  = (flags & IFF_RUNNING)  != 0

            if !isLoopback, isRunning, ptr.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK) {
                let name = String(cString: ptr.pointee.ifa_name)
                let data = ptr.pointee.ifa_data?.assumingMemoryBound(to: if_data.self)
                counters[name] = (
                    bytesIn: UInt64(data?.pointee.ifi_ibytes ?? 0),
                    bytesOut: UInt64(data?.pointee.ifi_obytes ?? 0)
                )
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return counters
    }

    static func computeInterfaceUsage(
        currentCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        previousCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        elapsed: Double
    ) -> [NetworkInterfaceUsage] {
        guard elapsed > 0 else { return [] }
        return currentCounters.compactMap { name, current -> NetworkInterfaceUsage? in
            guard let previous = previousCounters[name] else { return nil }
            let inDelta = current.bytesIn >= previous.bytesIn ? current.bytesIn - previous.bytesIn : 0
            let outDelta = current.bytesOut >= previous.bytesOut ? current.bytesOut - previous.bytesOut : 0
            guard inDelta > 0 || outDelta > 0 else { return nil }
            return NetworkInterfaceUsage(
                name: name,
                displayName: displayName(for: name),
                bytesInPerSec: Double(inDelta) / elapsed,
                bytesOutPerSec: Double(outDelta) / elapsed
            )
        }
        .sorted {
            if $0.totalBytesPerSec == $1.totalBytesPerSec {
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            return $0.totalBytesPerSec > $1.totalBytesPerSec
        }
    }

    static func computeTopProcesses(
        currentCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        previousSnapshots: [String: ProcessSnapshot],
        now: Date,
        processCount: Int
    ) -> [ProcInfo] {
        let processes = currentCounters.compactMap { key, current -> ProcInfo? in
            guard let previous = previousSnapshots[key] else { return nil }
            let elapsed = now.timeIntervalSince(previous.date)
            guard elapsed > 0 else { return nil }

            let bytesInDelta = current.bytesIn >= previous.bytesIn ? current.bytesIn - previous.bytesIn : 0
            let bytesOutDelta = current.bytesOut >= previous.bytesOut ? current.bytesOut - previous.bytesOut : 0
            guard bytesInDelta > 0 || bytesOutDelta > 0 else { return nil }

            return ProcInfo(
                name: processName(from: key),
                cpuPercent: 0,
                memoryBytes: 0,
                networkInBPS: Double(bytesInDelta) / elapsed,
                networkOutBPS: Double(bytesOutDelta) / elapsed
            )
        }

        return Array(
            processes
                .sorted { $0.networkTotalBPS > $1.networkTotalBPS }
                .prefix(processCount)
        )
    }

    static func displayName(for interface: String) -> String {
        switch interface {
        case let name where name.hasPrefix("utun"):
            "VPN (\(name))"
        case let name where name.hasPrefix("awdl"):
            "Nearby (\(name))"
        case let name where name.hasPrefix("llw"):
            "Low-Latency Wi-Fi (\(name))"
        case let name where name.hasPrefix("en"):
            "Network (\(name))"
        default:
            interface
        }
    }

    private static func processName(from key: String) -> String {
        guard let lastDot = key.lastIndex(of: ".") else { return key }
        return String(key[..<lastDot])
    }

    private static func readProcessCounters() -> [String: (bytesIn: UInt64, bytesOut: UInt64)]? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/nettop")
        task.arguments = [
            "-P", "-L", "1", "-n",
            "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg," +
                  "rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
        } catch {
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        task.waitUntilExit()

        guard task.terminationStatus == 0,
              let output = String(data: data, encoding: .utf8) else {
            return nil
        }

        var counters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
        for line in output.components(separatedBy: "\n").dropFirst() {
            let parts = line.components(separatedBy: ",")
            guard parts.count >= 3 else { continue }

            let key = parts[0].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }

            counters[key] = (
                bytesIn: UInt64(parts[1].trimmingCharacters(in: .whitespaces)) ?? 0,
                bytesOut: UInt64(parts[2].trimmingCharacters(in: .whitespaces)) ?? 0
            )
        }

        return counters
    }
}
