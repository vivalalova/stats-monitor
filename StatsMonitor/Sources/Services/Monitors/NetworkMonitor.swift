import Foundation
import Darwin

struct NetworkMonitor: Sendable {
    struct ProcessSnapshot: Sendable {
        var bytesIn: UInt64
        var bytesOut: UInt64
        var date: Date
    }

    private var previousInterfaceCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)] = [:]
    private let processSampler: NetworkProcessSampler
    private let connectionSampler = NetworkConnectionSampler()
    private var previousDate: Date = .now

    init(processSampler: NetworkProcessSampler = NetworkProcessSampler()) {
        self.processSampler = processSampler
    }

    /// Connection counts are filled in by `SystemMonitor` from the detached `sampleConnectionCounts()` path.
    mutating func sample() -> NetworkUsage {
        let interfaces = interfaceCounters()
        let now = Date.now
        let elapsed = now.timeIntervalSince(previousDate)
        let previousCounters = previousInterfaceCounters
        previousInterfaceCounters = interfaces
        previousDate = now

        guard elapsed > 0, !previousCounters.isEmpty else {
            return NetworkUsage(bytesInPerSec: 0, bytesOutPerSec: 0)
        }

        let interfaceUsage = Self.computeInterfaceUsage(
            currentCounters: interfaces,
            previousCounters: previousCounters,
            elapsed: elapsed
        )
        return NetworkUsage(
            bytesInPerSec: interfaceUsage.reduce(0) { $0 + $1.bytesInPerSec },
            bytesOutPerSec: interfaceUsage.reduce(0) { $0 + $1.bytesOutPerSec },
            interfaces: interfaceUsage
        )
    }

    /// Spawns `netstat`, so call it off the main actor; nil until a read has succeeded.
    func sampleConnectionCounts() -> (tcp: Int, udp: Int)? {
        connectionSampler.sample()
    }

    func sampleTopProcesses(processCount: Int = 10) -> [ProcInfo] {
        guard let currentCounters = Self.readProcessCounters() else { return [] }
        return processSampler.sampleTopProcesses(
            currentCounters: currentCounters,
            now: .now,
            processCount: processCount
        )
    }

    func sampleTopProcesses(
        currentCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        now: Date,
        processCount: Int
    ) -> [ProcInfo] {
        processSampler.sampleTopProcesses(
            currentCounters: currentCounters,
            now: now,
            processCount: processCount
        )
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
                if let interfaceCounters = Self.readInterfaceCounters64(name: name) {
                    counters[name] = interfaceCounters
                }
            }

            guard let next = ptr.pointee.ifa_next else { break }
            ptr = next
        }

        return counters
    }

    /// `ifaddrs.ifa_data` byte counters are 32-bit and wrap at 4 GiB; IFMIB generic data is 64-bit.
    private static func readInterfaceCounters64(name: String) -> (bytesIn: UInt64, bytesOut: UInt64)? {
        let index = if_nametoindex(name)
        guard index > 0 else { return nil }
        var mib: [Int32] = [CTL_NET, PF_LINK, NETLINK_GENERIC, IFMIB_IFDATA, Int32(index), IFDATA_GENERAL]
        var data = ifmibdata()
        var size = MemoryLayout<ifmibdata>.size
        guard sysctl(&mib, UInt32(mib.count), &data, &size, nil, 0) == 0 else { return nil }
        return (data.ifmd_data.ifi_ibytes, data.ifmd_data.ifi_obytes)
    }

    static func computeInterfaceUsage(
        currentCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        previousCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        elapsed: Double
    ) -> [NetworkInterfaceUsage] {
        guard elapsed > 0 else { return [] }
        return currentCounters.compactMap { name, current -> NetworkInterfaceUsage? in
            guard let previous = previousCounters[name] else { return nil }
            let inPerSec = bytesPerSecond(current: current.bytesIn, previous: previous.bytesIn, elapsed: elapsed)
            let outPerSec = bytesPerSecond(current: current.bytesOut, previous: previous.bytesOut, elapsed: elapsed)
            guard inPerSec > 0 || outPerSec > 0 else { return nil }
            return NetworkInterfaceUsage(
                name: name,
                displayName: displayName(for: name),
                bytesInPerSec: inPerSec,
                bytesOutPerSec: outPerSec
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

            let inPerSec = bytesPerSecond(current: current.bytesIn, previous: previous.bytesIn, elapsed: elapsed)
            let outPerSec = bytesPerSecond(current: current.bytesOut, previous: previous.bytesOut, elapsed: elapsed)
            guard inPerSec > 0 || outPerSec > 0,
                  let pid = processID(from: key) else { return nil }

            return ProcInfo(
                name: processName(from: key),
                cpuPercent: 0,
                memoryBytes: 0,
                networkInBPS: inPerSec,
                networkOutBPS: outPerSec,
                pid: pid
            )
        }

        return Array(
            processes
                .sorted { $0.networkTotalBPS > $1.networkTotalBPS }
                .prefix(processCount)
        )
    }

    static func bytesPerSecond(current: UInt64, previous: UInt64, elapsed: Double) -> Double {
        guard elapsed > 0, current >= previous else { return 0 }
        return Double(current - previous) / elapsed
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

    /// nettop keys are `name.pid`.
    private static func processID(from key: String) -> Int32? {
        guard let lastDot = key.lastIndex(of: ".") else { return nil }
        return Int32(key[key.index(after: lastDot)...])
    }

    private static func processName(from key: String) -> String {
        guard let lastDot = key.lastIndex(of: ".") else { return key }
        return String(key[..<lastDot])
    }

    static func readConnectionCounts() -> (tcp: Int, udp: Int)? {
        guard let tcp = runNetstatCount(protocolFlag: "tcp"),
              let udp = runNetstatCount(protocolFlag: "udp")
        else { return nil }
        return (tcp, udp)
    }

    static func parseConnectionCount(output: String) -> Int {
        let lines = output.split(separator: "\n", omittingEmptySubsequences: true)
        // netstat prints two header lines for TCP/UDP: "Active ..." and column header.
        let dataLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { return false }
            if trimmed.hasPrefix("Active ") { return false }
            if trimmed.hasPrefix("Proto ") { return false }
            if trimmed.hasPrefix("Socket ") { return false }
            return true
        }
        return dataLines.count
    }

    private static func runNetstatCount(protocolFlag: String) -> Int? {
        guard let output = PowerMonitor.runProcessCapturingOutput(
            executableURL: URL(fileURLWithPath: "/usr/sbin/netstat"),
            arguments: ["-an", "-p", protocolFlag]
        ),
              output.terminationStatus == 0
        else { return nil }
        return parseConnectionCount(output: output.stdout)
    }

    private static func readProcessCounters() -> [String: (bytesIn: UInt64, bytesOut: UInt64)]? {
        guard let result = PowerMonitor.runProcessCapturingOutput(
            executableURL: URL(fileURLWithPath: "/usr/bin/nettop"),
            arguments: [
                "-P", "-L", "1", "-n",
                "-k", "time,interface,state,rx_dupe,rx_ooo,re-tx,rtt_avg," +
                      "rcvsize,tx_win,tc_class,tc_mgt,cc_algo,P,C,R,W,arch"
            ]
        ),
              result.terminationStatus == 0
        else { return nil }
        let output = result.stdout

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

final class NetworkProcessSampler: @unchecked Sendable {
    private var previousSnapshots: [String: NetworkMonitor.ProcessSnapshot] = [:]

    func sampleTopProcesses(
        currentCounters: [String: (bytesIn: UInt64, bytesOut: UInt64)],
        now: Date,
        processCount: Int
    ) -> [ProcInfo] {
        let processes = NetworkMonitor.computeTopProcesses(
            currentCounters: currentCounters,
            previousSnapshots: previousSnapshots,
            now: now,
            processCount: processCount
        )
        previousSnapshots = Dictionary(
            uniqueKeysWithValues: currentCounters.map { key, value in
                (key, NetworkMonitor.ProcessSnapshot(bytesIn: value.bytesIn, bytesOut: value.bytesOut, date: now))
            }
        )
        return processes
    }
}

final class NetworkConnectionSampler: @unchecked Sendable {
    private var tick: UInt8 = 0
    private var cachedCounts: (tcp: Int, udp: Int)?

    /// Refresh netstat-derived TCP/UDP counts every N samples to bound process-spawning cost.
    private static let refreshEveryNSamples: UInt8 = 3

    func sample() -> (tcp: Int, udp: Int)? {
        defer { tick = (tick &+ 1) % Self.refreshEveryNSamples }
        if tick == 0, let counts = NetworkMonitor.readConnectionCounts() {
            cachedCounts = counts
        }
        return cachedCounts
    }
}
