import AppKit

@MainActor
enum StatusBarLabelRenderer {
    private static let contentInset: CGFloat = 6
    private static let symbolPointSize: CGFloat = 11
    private static let textFontSize: CGFloat = 12

    enum SegmentEmphasis: Equatable {
        case normal
        case critical
    }

    struct Segment {
        let panel: PanelID
        let symbol: String
        let text: String
        let emphasis: SegmentEmphasis
    }

    static func makeAttributedTitle(monitor: SystemMonitor, settings: AppSettings) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let segments = makeSegments(monitor: monitor, settings: settings)

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                result.append(separatorString)
            }
            result.append(makeSegment(symbol: segment.symbol, text: segment.text, emphasis: segment.emphasis))
        }

        return result
    }

    static func makeSegments(monitor: SystemMonitor, settings: AppSettings) -> [Segment] {
        var segments: [Segment] = []
        appendSegment(to: &segments, isVisible: settings.showCPU, panel: .cpu, symbol: "cpu", text: monitor.cpuPercent)
        appendSegment(to: &segments, isVisible: settings.showGPU, panel: .gpu, symbol: "display", text: monitor.gpuPercent)
        appendSegment(to: &segments, isVisible: settings.showMemory, panel: .memory, symbol: "memorychip", text: monitor.memoryPercent)
        appendSegment(to: &segments, isVisible: settings.showDisk, panel: .disk, symbol: "internaldrive", text: monitor.diskMenuText)
        appendSegment(to: &segments, isVisible: settings.showNetwork, panel: .network, symbol: "network", text: monitor.networkInText)
        appendSegment(
            to: &segments,
            isVisible: settings.showPowerPanel && monitor.hasPowerPanel,
            panel: .power,
            symbol: monitor.powerMenuSymbol,
            text: monitor.powerMenuText
        )
        appendSegment(
            to: &segments,
            isVisible: settings.showThermal && monitor.hasThermal,
            panel: .thermal,
            symbol: "thermometer.medium",
            text: monitor.thermalMenuText,
            emphasis: monitor.thermalPressureState == .critical ? .critical : .normal
        )
        appendSegment(to: &segments, isVisible: settings.showFans && monitor.hasFans, panel: .fans, symbol: "wind", text: monitor.fansSummaryText)
        return segments
    }

    static func measuredTitleWidth(for segments: [Segment]) -> CGFloat {
        guard !segments.isEmpty else { return 0 }

        return segments.enumerated().reduce(0) { partialWidth, item in
            let spacing = item.offset > 0 ? separatorWidth : 0
            return partialWidth + spacing + segmentWidth(for: item.element)
        }
    }

    static func panel(at x: CGFloat, in segments: [Segment]) -> PanelID? {
        guard !segments.isEmpty else { return nil }

        let clampedX = max(0, x - contentInset)
        var currentMinX: CGFloat = 0

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                currentMinX += separatorWidth
            }

            let segmentMaxX = currentMinX + segmentWidth(for: segment)
            if clampedX < segmentMaxX {
                return segment.panel
            }
            currentMinX = segmentMaxX
        }

        return segments.last?.panel
    }

    private static func makeSegment(symbol: String, text: String, emphasis: SegmentEmphasis) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let attachment = NSTextAttachment()
        let color = foregroundColor(for: emphasis)

        attachment.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration(for: emphasis))

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttributes([
            .baselineOffset: -1,
            .foregroundColor: color,
        ], range: NSRange(location: 0, length: attachmentString.length))
        result.append(attachmentString)

        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: textFontSize, weight: .regular),
            .foregroundColor: color,
        ]
        result.append(NSAttributedString(string: " \(text)", attributes: textAttributes))
        return result
    }

    private static func appendSegment(
        to segments: inout [Segment],
        isVisible: Bool,
        panel: PanelID,
        symbol: String,
        text: String,
        emphasis: SegmentEmphasis = .normal
    ) {
        guard isVisible else { return }
        segments.append(Segment(panel: panel, symbol: symbol, text: text, emphasis: emphasis))
    }

    private static func segmentWidth(for segment: Segment) -> CGFloat {
        makeSegment(symbol: segment.symbol, text: segment.text, emphasis: segment.emphasis).size().width
    }

    private static func foregroundColor(for emphasis: SegmentEmphasis) -> NSColor {
        switch emphasis {
        case .normal:
            return .labelColor
        case .critical:
            return .systemRed
        }
    }

    private static func symbolConfiguration(for emphasis: SegmentEmphasis) -> NSImage.SymbolConfiguration {
        let baseConfiguration = NSImage.SymbolConfiguration(pointSize: symbolPointSize, weight: .regular)

        switch emphasis {
        case .normal:
            return baseConfiguration
        case .critical:
            let paletteConfiguration = NSImage.SymbolConfiguration(paletteColors: [.systemRed, .systemOrange])
            let multicolorConfiguration = NSImage.SymbolConfiguration.preferringMulticolor()
            return baseConfiguration.applying(paletteConfiguration).applying(multicolorConfiguration)
        }
    }

    private static var separatorString: NSAttributedString {
        NSAttributedString(
            string: "  ",
            attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: textFontSize, weight: .regular),
                .foregroundColor: NSColor.labelColor,
            ]
        )
    }

    private static var separatorWidth: CGFloat {
        separatorString.size().width
    }
}

extension StatusBarLabelRenderer.Segment: Equatable {}
