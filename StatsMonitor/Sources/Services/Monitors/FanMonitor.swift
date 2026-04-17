import Foundation

struct FanMonitor {
    private let smc: SMCClient

    init(smc: SMCClient) { self.smc = smc }

    /// Returns an empty array on fanless Macs (e.g. MacBook Air M-series) or when SMC is unavailable.
    func sample() -> [FanUsage] {
        guard smc.isAvailable,
              let count = smc.readUInt8("FNum"),
              count > 0
        else { return [] }

        return (0..<Int(count)).compactMap { i in
            guard let rpm = smc.readFanRPM("F\(i)Ac") else { return nil }
            let minRPM = smc.readFanRPM("F\(i)Mn") ?? 0
            let maxRPM = smc.readFanRPM("F\(i)Mx") ?? 6000
            let name   = readFanName(index: i) ?? "Fan \(i)"
            return FanUsage(
                id:         i,
                currentRPM: rpm,
                minRPM:     minRPM,
                maxRPM:     max(maxRPM, 1),
                name:       name
            )
        }
    }

    // MARK: - Private

    /// `F{n}ID` layout: bytes 4..N are ASCII name (null-padded). Falls back to nil.
    private func readFanName(index: Int) -> String? {
        guard let bytes = smc.readKey("F\(index)ID"), bytes.count > 4 else { return nil }
        let nameBytes = bytes.dropFirst(4).prefix(while: { $0 != 0 })
        guard !nameBytes.isEmpty else { return nil }
        return String(bytes: nameBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces)
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
