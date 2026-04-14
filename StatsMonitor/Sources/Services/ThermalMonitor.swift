import Foundation

struct ThermalMonitor {
    private let smc: SMCClient

    init(smc: SMCClient) { self.smc = smc }

    /// Returns nil when SMC is unavailable or all known keys fail.
    func sample() -> ThermalUsage? {
        guard smc.isAvailable else { return nil }

        let cpuTemp = smc.isAppleSilicon
            ? readAppleSiliconCPUTemp()
            : readIntelCPUTemp()
        guard let cpuTemp else { return nil }

        return ThermalUsage(
            cpuTemperature: cpuTemp,
            gpuTemperature: readGPUTemp()
        )
    }

    // MARK: - Private

    /// Apple Silicon: try all known P-core cluster keys, return maximum (proxy for package temp).
    /// Keys with 0x0000 (= 0.0 °C) are unpopulated sensor slots — filter them out.
    private func readAppleSiliconCPUTemp() -> Double? {
        let keys = ["Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D", "Tp0b", "Tp0j",
                    "Tp0L", "Tp0P", "Tp0X", "Tp0d", "Tp0h", "Tp0l", "Tp0p"]
        let readings = keys.compactMap { smc.readTemperature($0) }.filter { $0 > 0 }
        return readings.isEmpty ? nil : readings.max()
    }

    /// Intel: try keys in order, return first valid reading.
    private func readIntelCPUTemp() -> Double? {
        let keys = ["TC0P", "TC0H", "TC0D", "TC1C", "TCXC"]
        return keys.lazy.compactMap { smc.readTemperature($0) }.first
    }

    private func readGPUTemp() -> Double? {
        let keys = smc.isAppleSilicon
            ? ["Tg0P", "Tg0p", "Tg0H", "TG0P"]
            : ["TG0P", "TG0H", "TGDD"]
        return keys.lazy.compactMap { smc.readTemperature($0) }.first
    }
}
