import Foundation
import CoreWLAN

struct WiFiMonitor: Sendable {
    func sample() -> WiFiLinkInfo? {
        guard let interface = CWWiFiClient.shared().interface(),
              interface.powerOn() else { return nil }

        let rssi = interface.rssiValue()
        let noise = interface.noiseMeasurement()
        let rate = interface.transmitRate()
        let channel = interface.wlanChannel()

        let info = WiFiLinkInfo(
            rssiDBm: rssi != 0 ? rssi : nil,
            noiseDBm: noise != 0 ? noise : nil,
            linkRateMbps: rate > 0 ? rate : nil,
            channelNumber: channel?.channelNumber,
            band: channel.map { Self.bandLabel(for: $0.channelBand) },
            hardwareAddress: interface.hardwareAddress()
        )

        // Consider unplugged / inactive Wi-Fi (all nil / zero) as unavailable.
        if info.rssiDBm == nil, info.linkRateMbps == nil, info.channelNumber == nil {
            return nil
        }
        return info
    }

    static func bandLabel(for band: CWChannelBand) -> String {
        switch band {
        case .band2GHz: "2.4 GHz"
        case .band5GHz: "5 GHz"
        case .band6GHz: "6 GHz"
        case .bandUnknown: "—"
        @unknown default: "—"
        }
    }
}
