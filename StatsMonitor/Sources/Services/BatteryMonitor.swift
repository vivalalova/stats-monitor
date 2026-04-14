import Foundation
import IOKit

struct BatteryMonitor {

    /// Returns nil on desktop Macs (Mac mini / Mac Pro / Mac Studio) where no battery is present.
    func sample() -> BatteryUsage? {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("AppleSmartBattery")
        )
        guard service != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(service) }

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(
            service, &props, kCFAllocatorDefault, 0
        ) == kIOReturnSuccess,
              let dict = props?.takeRetainedValue() as? [String: Any]
        else { return nil }

        // CurrentCapacity and MaxCapacity are the minimum required fields
        guard let current = dict["CurrentCapacity"] as? Int,
              let maxCap  = dict["MaxCapacity"]      as? Int,
              maxCap > 0
        else { return nil }

        let designCap   = dict["DesignCapacity"]    as? Int ?? maxCap
        let isCharging  = dict["IsCharging"]        as? Bool ?? false
        let isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
        let cycleCount  = dict["CycleCount"]        as? Int ?? 0
        let rawRemain   = dict["TimeRemaining"]     as? Int  // 65535 = estimating

        let timeRemaining: Int? = (rawRemain == nil || rawRemain == 65535) ? nil : rawRemain

        let safeDesign = designCap > 0 ? designCap : maxCap
        return BatteryUsage(
            percentage:     max(0, min(Double(current) / Double(maxCap) * 100.0, 100.0)),
            isCharging:     isCharging,
            isPluggedIn:    isPluggedIn,
            timeRemaining:  timeRemaining,
            cycleCount:     cycleCount,
            designCapacity: safeDesign,
            maxCapacity:    maxCap,
            health:         max(0, min(Double(maxCap) / Double(safeDesign) * 100.0, 100.0))
        )
    }
}
