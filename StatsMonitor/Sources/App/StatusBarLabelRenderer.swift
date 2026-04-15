import AppKit

@MainActor
enum StatusBarLabelRenderer {
    static func makeAttributedTitle(monitor: SystemMonitor, settings: AppSettings) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let segments = makeSegments(monitor: monitor, settings: settings)

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                result.append(NSAttributedString(string: "  "))
            }
            result.append(makeSegment(symbol: segment.symbol, text: segment.text))
        }

        return result
    }

    static func makeSegments(monitor: SystemMonitor, settings: AppSettings) -> [(symbol: String, text: String)] {
        var segments: [(symbol: String, text: String)] = []

        if settings.showCPU {
            segments.append(("cpu", monitor.cpuPercent))
        }
        if settings.showGPU {
            segments.append(("display", monitor.gpuPercent))
        }
        if settings.showMemory {
            segments.append(("memorychip", monitor.memoryPercent))
        }
        if settings.showDisk {
            segments.append(("internaldrive", monitor.diskPercent))
        }
        if settings.showNetwork {
            segments.append(("network", monitor.networkInText))
        }
        if settings.showBattery, monitor.hasBattery {
            segments.append(("battery.100", monitor.batteryPercent))
        }
        if settings.showThermal, monitor.hasThermal {
            segments.append(("thermometer.medium", monitor.cpuTempText))
        }
        if settings.showPower, monitor.hasPower {
            segments.append(("bolt.fill", monitor.powerText))
        }
        if settings.showFans, monitor.hasFans {
            segments.append(("wind", monitor.fansSummaryText))
        }

        return segments
    }

    private static func makeSegment(symbol: String, text: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let attachment = NSTextAttachment()

        let configuration = NSImage.SymbolConfiguration(pointSize: 11, weight: .regular)
        attachment.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration)

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttributes([
            .baselineOffset: -1,
            .foregroundColor: NSColor.labelColor,
        ], range: NSRange(location: 0, length: attachmentString.length))
        result.append(attachmentString)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular),
            .foregroundColor: NSColor.labelColor,
        ]
        result.append(NSAttributedString(string: " \(text)", attributes: textAttributes))
        return result
    }
}
