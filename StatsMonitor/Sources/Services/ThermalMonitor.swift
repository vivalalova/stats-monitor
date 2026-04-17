import Foundation

struct ThermalMonitor {
    struct Sample {
        var usage: ThermalUsage?
        var pressureState: ProcessInfo.ThermalState
    }

    private let smc: SMCClient
    private static let plausibleTemperatureRange = 10.0...130.0

    init(smc: SMCClient) { self.smc = smc }

    func sample() -> Sample {
        Sample(
            usage: sampleUsage(),
            pressureState: ProcessInfo.processInfo.thermalState
        )
    }

    /// Returns nil when SMC is unavailable or all known keys fail.
    private func sampleUsage() -> ThermalUsage? {
        guard smc.isAvailable else { return nil }
        // Apple Silicon does not expose a verified public CPU/GPU temperature map here.
        // Returning nil is more honest than rendering unvalidated SMC guesses as real values.
        guard !smc.isAppleSilicon else { return nil }

        let cpuTemp = readIntelCPUTemp()
        guard let cpuTemp else { return nil }

        return ThermalUsage(
            cpuTemperature: cpuTemp,
            gpuTemperature: readGPUTemp()
        )
    }

    // MARK: - Private

    /// Intel: try keys in order, return first valid reading.
    private func readIntelCPUTemp() -> Double? {
        let keys = ["TC0P", "TC0H", "TC0D", "TC1C", "TCXC"]
        return keys.lazy.compactMap { Self.sanitizeTemperature(smc.readTemperature($0)) }.first
    }

    private func readGPUTemp() -> Double? {
        let keys = smc.isAppleSilicon
            ? ["Tg0P", "Tg0p", "Tg0H", "TG0P"]
            : ["TG0P", "TG0H", "TGDD"]
        return keys.lazy.compactMap { Self.sanitizeTemperature(smc.readTemperature($0)) }.first
    }

    static func sanitizeTemperature(_ value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        guard plausibleTemperatureRange.contains(value) else { return nil }
        return value
    }
}
