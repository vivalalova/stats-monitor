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

        return Self.parseUsage(from: dict)
    }

    static func parseUsage(from dict: [String: Any]) -> BatteryUsage? {
        guard let current = positiveInt(from: dict["CurrentCapacity"]),
              let reportedMax = positiveInt(from: dict["MaxCapacity"])
        else { return nil }

        let designCap = positiveInt(from: dict["DesignCapacity"]) ?? reportedMax
        let nominalMaxCapacity = positiveInt(from: dict["NominalChargeCapacity"])
        let rawMaxCapacity = positiveInt(from: dict["AppleRawMaxCapacity"])
        let maxCap = nominalMaxCapacity
            ?? rawMaxCapacity
            ?? (reportedMax > 100 ? reportedMax : nil)
            ?? reportedMax

        let safeDesign = designCap > 0 ? designCap : maxCap
        let isCharging  = dict["IsCharging"]        as? Bool ?? false
        let isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
        let cycleCount  = dict["CycleCount"]        as? Int ?? 0
        let rawRemain   = dict["TimeRemaining"]     as? Int
        let timeRemaining = validTimeRemaining(rawRemain)

        let voltage = (dict["Voltage"] as? Int) ?? 0
        let instantAmperage = dict["InstantAmperage"] as? Int
        let steadyAmperage = dict["Amperage"] as? Int
        let amperage = instantAmperage ?? steadyAmperage ?? 0
        let temperature = temperatureCelsius(from: dict["Temperature"] as? Int)

        return BatteryUsage(
            percentage:     clamp(Double(current) / Double(reportedMax) * 100.0),
            isCharging:     isCharging,
            isPluggedIn:    isPluggedIn,
            timeRemaining:  timeRemaining,
            cycleCount:     cycleCount,
            designCapacity: safeDesign,
            maxCapacity:    maxCap,
            health:         clamp(Double(maxCap) / Double(safeDesign) * 100.0),
            voltageMilliVolts: max(voltage, 0),
            amperageMilliAmps: signedAmperage(amperage, isCharging: isCharging),
            temperatureCelsius: temperature
        )
    }

    /// AppleSmartBattery encodes amperage as unsigned 16-bit while charging and signed
    /// (as Int) while discharging. Normalise so that charging is positive, discharging
    /// is negative, and zero remains zero.
    static func signedAmperage(_ raw: Int, isCharging: Bool) -> Int {
        guard raw != 0 else { return 0 }
        // Raw Int may come through as negative already (discharging on Apple Silicon).
        if raw < 0 { return raw }
        return isCharging ? raw : -raw
    }

    /// AppleSmartBattery reports temperature in 0.01 °C units (e.g. 3010 → 30.10 °C).
    static func temperatureCelsius(from raw: Int?) -> Double? {
        guard let raw, raw > 0 else { return nil }
        return Double(raw) / 100.0
    }

    private static func positiveInt(from value: Any?) -> Int? {
        guard let value = value as? Int, value > 0 else { return nil }
        return value
    }

    private static func validTimeRemaining(_ rawValue: Int?) -> Int? {
        guard let rawValue, rawValue >= 0, rawValue != 65535 else { return nil }
        return rawValue
    }

    private static func clamp(_ percentage: Double) -> Double {
        max(0, min(percentage, 100))
    }
}
