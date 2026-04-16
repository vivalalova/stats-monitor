import Foundation
import Util

struct SystemStats: Sendable {
    var cpu: CPUUsage = .zero
    var gpu: GPUUsage = .zero
    var memory: MemoryUsage = .zero
    var disk: DiskUsage = .zero
    var network: NetworkUsage = .zero
    var battery: BatteryUsage? = nil    // nil on desktop Macs (no battery hardware)
    var thermal: ThermalUsage? = nil    // nil when SMC is unavailable or all keys fail
    var power:   PowerUsage?   = nil    // nil when IOReport unavailable (non-Apple Silicon)
    var fans: [FanUsage] = []           // empty on fanless Macs (e.g. MacBook Air M-series)
    var topCPUProcesses: [ProcInfo] = []
    var topMemoryProcesses: [ProcInfo] = []
    var topDiskProcesses: [ProcInfo] = []
    var topNetworkProcesses: [ProcInfo] = []
}

struct CPUCoreFrequency: Sendable {
    var currentHz: UInt64   // 0 = unavailable
    var maxHz: UInt64       // 0 = unavailable

    static let zero = CPUCoreFrequency(currentHz: 0, maxHz: 0)

    var displayText: String {
        guard maxHz > 0 else { return "" }
        if currentHz > 0 {
            return "\(ghzString(currentHz))\n\(ghzString(maxHz))"
        }
        return ghzString(maxHz)
    }

}

struct CPUUsage: Sendable {
    var user: Double
    var system: Double
    var idle: Double
    var perCore: [Double]
    var coreFrequencies: [CPUCoreFrequency]

    var used: Double { user + system }

    static let zero = CPUUsage(user: 0, system: 0, idle: 100, perCore: [], coreFrequencies: [])
}

struct MemoryUsage: Sendable {
    var active: UInt64
    var wired: UInt64
    var compressed: UInt64
    var total: UInt64

    var used: UInt64 { active + wired + compressed }

    var usedFraction: Double {
        total > 0 ? Double(used) / Double(total) : 0
    }

    static let zero = MemoryUsage(active: 0, wired: 0, compressed: 0, total: 0)
}

struct DiskUsage: Sendable {
    var used: UInt64
    var total: UInt64
    var readBPS: Double = 0
    var writeBPS: Double = 0

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

struct GPUUsage: Sendable {
    var deviceUtilization: Double
    var renderUtilization: Double
    var engines: [String: Double]
    var vramUsed: UInt64      // "In Use System Memory", bytes; 0 if unavailable
    var anePowerMilliWatts: Double = 0   // IOReport Energy Model; 0 = idle / unavailable

    var used: Double { deviceUtilization }

    static let zero = GPUUsage(deviceUtilization: 0, renderUtilization: 0, engines: [:], vramUsed: 0)
}

struct ProcInfo: Sendable {
    var name: String
    var cpuPercent: Double
    var memoryBytes: UInt64
    var diskReadBPS: Double = 0
    var diskWriteBPS: Double = 0
    var networkInBPS: Double = 0
    var networkOutBPS: Double = 0
    var powerImpact: Double = 0

    var diskTotalBPS: Double { diskReadBPS + diskWriteBPS }
    var networkTotalBPS: Double { networkInBPS + networkOutBPS }
}

struct BatteryUsage: Sendable {
    var percentage: Double      // 0.0–100.0
    var isCharging: Bool
    var isPluggedIn: Bool       // AC power connected (may not be actively charging)
    var timeRemaining: Int?     // minutes; nil while estimating
    var cycleCount: Int
    var designCapacity: Int     // mAh
    var maxCapacity: Int        // mAh (current maximum)
    var health: Double          // maxCapacity / designCapacity × 100
}

struct ThermalUsage: Sendable {
    var cpuTemperature: Double      // °C (CPU package / highest cluster temp)
    var gpuTemperature: Double?     // °C; nil when no discrete GPU or key unavailable
}

struct PowerUsage: Sendable {
    var cpuMilliWatts:   Double   // CPU cluster(s) power
    var gpuMilliWatts:   Double   // GPU power
    var totalMilliWatts: Double   // all Energy Model channels
    var externalInputMilliWatts: Double? = nil   // charger / adapter input
    var batteryMilliWatts: Double = 0            // signed: +charging, -discharging

    var totalWatts: Double { totalMilliWatts / 1000 }
    var cpuWatts:   Double { cpuMilliWatts   / 1000 }
    var gpuWatts:   Double { gpuMilliWatts   / 1000 }
    var externalInputWatts: Double? { externalInputMilliWatts.map { $0 / 1000 } }
    var batteryChargeWatts: Double? { batteryMilliWatts > 0 ? batteryMilliWatts / 1000 : nil }
    var batteryDischargeWatts: Double? { batteryMilliWatts < 0 ? abs(batteryMilliWatts) / 1000 : nil }
    var balanceWatts: Double? {
        guard let externalInputMilliWatts else { return nil }
        return (externalInputMilliWatts - totalMilliWatts) / 1000
    }
}

struct FanUsage: Sendable {
    var id: Int
    var currentRPM: Double
    var minRPM: Double
    var maxRPM: Double
    var name: String

    /// Normalised 0–1 fraction of full RPM range. Clamped so spin-down below minRPM and
    /// turbo-boost above maxRPM don't produce out-of-range values.
    var fraction: Double {
        guard maxRPM > minRPM else { return 0 }
        return min(max((currentRPM - minRPM) / (maxRPM - minRPM), 0), 1)
    }
}
