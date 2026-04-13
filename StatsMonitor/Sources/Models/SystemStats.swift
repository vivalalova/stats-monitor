import Foundation

struct SystemStats: Sendable {
    var cpu: CPUUsage = .zero
    var memory: MemoryUsage = .zero
    var disk: DiskUsage = .zero
    var network: NetworkUsage = .zero
}

struct CPUUsage: Sendable {
    var user: Double
    var system: Double
    var idle: Double

    var used: Double { user + system }

    static let zero = CPUUsage(user: 0, system: 0, idle: 100)
}

struct MemoryUsage: Sendable {
    var used: UInt64
    var total: UInt64

    var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }

    static let zero = MemoryUsage(used: 0, total: 0)
}

struct DiskUsage: Sendable {
    var used: UInt64
    var total: UInt64

    var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }

    static let zero = DiskUsage(used: 0, total: 0)
}

struct NetworkUsage: Sendable {
    var bytesInPerSec: Double
    var bytesOutPerSec: Double

    static let zero = NetworkUsage(bytesInPerSec: 0, bytesOutPerSec: 0)
}
