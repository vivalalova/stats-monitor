import AppKit

@MainActor
enum StatusBarLabelRenderer {
    static func makeAttributedTitle(monitor: SystemMonitor, settings: AppSettings) -> NSAttributedString {
        makeAttributedTitle(for: makeSegments(monitor: monitor, settings: settings))
    }

    static func makeAttributedTitle(for segments: [MenuBarItem]) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let style = MenuBarTextLayout.style(forRowCount: preferredRowCount(for: segments))

        for (index, segment) in segments.enumerated() {
            if index > 0 {
                result.append(separatorString(for: style))
            }
            result.append(makeSegment(for: segment, style: style))
        }

        return result
    }

    static func makeSegments(monitor: SystemMonitor, settings: AppSettings) -> [MenuBarItem] {
        monitor.menuBarItems(settings: settings)
    }

    static func measuredTitleWidth(for segments: [MenuBarItem]) -> CGFloat {
        layout(for: segments).itemWidth
    }

    static func singleRowWidth(for segments: [MenuBarItem]) -> CGFloat {
        guard !segments.isEmpty else { return 0 }

        let style = MenuBarTextLayout.style(forRowCount: 1)
        let width = segments.enumerated().reduce(0) { partialWidth, item in
            let spacing = item.offset > 0 ? style.segmentSpacing : 0
            return partialWidth + spacing + segmentWidth(for: item.element, style: style)
        }
        return ceil(width) + style.contentInset * 2
    }

    static func layout(for segments: [MenuBarItem]) -> StatusBarLayout {
        guard !segments.isEmpty else { return .empty }

        let rowCount = preferredRowCount(for: segments)
        let style = MenuBarTextLayout.style(forRowCount: rowCount)
        let renderedSegments = segments.map { segment in
            makeRenderedSegment(for: segment, style: style)
        }
        let rowHeight = ceil(renderedSegments.map(\.contentHeight).max() ?? 0)
        let splitIndex = splitIndex(for: renderedSegments.map(\.totalWidth), rowCount: rowCount)
        let rowRanges = ranges(for: renderedSegments.count, splitIndex: splitIndex, rowCount: rowCount)
        let rowWidths = rowRanges.map { rowRange in
            width(for: rowRange, in: renderedSegments, spacing: style.segmentSpacing)
        }
        let contentWidth = ceil(rowWidths.max() ?? 0)
        let contentHeight = CGFloat(rowCount) * rowHeight + CGFloat(max(rowCount - 1, 0)) * style.rowSpacing

        var placedSegments: [StatusBarLayout.PlacedSegment] = []
        for (rowIndex, rowRange) in rowRanges.enumerated() {
            var currentX: CGFloat = 0
            let rowTop = contentHeight - CGFloat(rowIndex + 1) * rowHeight - CGFloat(rowIndex) * style.rowSpacing
            for segmentIndex in rowRange {
                let renderedSegment = renderedSegments[segmentIndex]
                let verticalOffset = floor((rowHeight - renderedSegment.contentHeight) / 2)
                let iconFrame = CGRect(
                    x: currentX,
                    y: rowTop + verticalOffset + floor((renderedSegment.contentHeight - renderedSegment.iconSlotSize) / 2),
                    width: renderedSegment.iconSlotSize,
                    height: renderedSegment.iconSlotSize
                )
                let textFrame = CGRect(
                    x: currentX + renderedSegment.iconSlotSize + renderedSegment.iconSpacing,
                    y: rowTop + verticalOffset,
                    width: renderedSegment.textSlotWidth,
                    height: renderedSegment.contentHeight
                )
                let frame = CGRect(
                    x: currentX,
                    y: rowTop,
                    width: renderedSegment.totalWidth,
                    height: rowHeight
                )
                placedSegments.append(StatusBarLayout.PlacedSegment(
                    segment: renderedSegment.segment,
                    text: renderedSegment.text,
                    icon: renderedSegment.icon,
                    textSize: renderedSegment.textSize,
                    textFrame: textFrame,
                    iconFrame: iconFrame,
                    frame: frame,
                    rowIndex: rowIndex
                ))
                currentX += renderedSegment.totalWidth + style.segmentSpacing
            }
        }

        return StatusBarLayout(
            placedSegments: placedSegments,
            contentSize: CGSize(width: contentWidth, height: contentHeight),
            contentInset: style.contentInset,
            style: style,
            rowHeight: rowHeight,
            rowSpacing: style.rowSpacing
        )
    }

    static func panel(at point: CGPoint, in segments: [MenuBarItem], bounds: CGRect) -> PanelID? {
        layout(for: segments).panel(at: point, in: bounds)
    }

    private static func makeSegment(for segment: MenuBarItem, style: MenuBarTextLayout.Style) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: MenuBarTextLayout.textFont(for: style),
            .foregroundColor: segment.color,
        ]
        result.append(NSAttributedString(string: segment.text, attributes: textAttributes))

        let attachment = NSTextAttachment()
        attachment.image = iconImage(for: segment, style: style)
        attachment.bounds = CGRect(x: 2, y: 0, width: 0, height: 0)

        let attachmentString = NSMutableAttributedString(attachment: attachment)
        attachmentString.addAttributes([
            .baselineOffset: -0.5,
            .foregroundColor: segment.color,
        ], range: NSRange(location: 0, length: attachmentString.length))
        result.append(attachmentString)
        return result
    }

    private static func segmentWidth(for segment: MenuBarItem, style: MenuBarTextLayout.Style) -> CGFloat {
        makeRenderedSegment(for: segment, style: style).totalWidth
    }

    private static func symbolConfiguration(pointSize: CGFloat, paletteColors: [NSColor]) -> NSImage.SymbolConfiguration {
        let baseConfiguration = NSImage.SymbolConfiguration(
            pointSize: pointSize,
            weight: .regular
        )

        let paletteConfiguration = NSImage.SymbolConfiguration(paletteColors: paletteColors)
        let configured = baseConfiguration.applying(paletteConfiguration)
        if paletteColors.count > 1 {
            let multicolorConfiguration = NSImage.SymbolConfiguration.preferringMulticolor()
            return configured.applying(multicolorConfiguration)
        }
        return configured
    }

    private static func separatorString(for style: MenuBarTextLayout.Style) -> NSAttributedString {
        NSAttributedString(
            string: " ",
            attributes: [
                .font: MenuBarTextLayout.textFont(for: style),
                .foregroundColor: NSColor.labelColor,
            ]
        )
    }

    private static func preferredRowCount(for segments: [MenuBarItem]) -> Int {
        segments.count >= MenuBarTextLayout.compactRowThreshold ? 2 : 1
    }

    private static func splitIndex(for segmentWidths: [CGFloat], rowCount: Int) -> Int {
        guard rowCount > 1, segmentWidths.count > 1 else { return segmentWidths.count }

        let totalWidth = segmentWidths.reduce(0, +)
        var leadingWidth: CGFloat = 0
        var bestIndex = 1
        var bestScore = CGFloat.greatestFiniteMagnitude

        for index in 1..<segmentWidths.count {
            leadingWidth += segmentWidths[index - 1]
            let rowsBefore = CGFloat(max(index - 1, 0))
            let rowsAfter = CGFloat(max(segmentWidths.count - index - 1, 0))
            let topWidth = leadingWidth + rowsBefore * MenuBarTextLayout.style(forRowCount: rowCount).segmentSpacing
            let bottomWidth = (totalWidth - leadingWidth) + rowsAfter * MenuBarTextLayout.style(forRowCount: rowCount).segmentSpacing
            let score = abs(topWidth - bottomWidth)
            if score < bestScore {
                bestScore = score
                bestIndex = index
            }
        }

        return bestIndex
    }

    private static func ranges(for count: Int, splitIndex: Int, rowCount: Int) -> [Range<Int>] {
        if rowCount == 1 || splitIndex >= count {
            return [0..<count]
        }

        return [0..<splitIndex, splitIndex..<count]
    }

    private static func width(
        for range: Range<Int>,
        in renderedSegments: [RenderedSegment],
        spacing: CGFloat
    ) -> CGFloat {
        guard !range.isEmpty else { return 0 }

        let widths = range.map { renderedSegments[$0].totalWidth }
        let gapCount = CGFloat(max(widths.count - 1, 0))
        return widths.reduce(0, +) + gapCount * spacing
    }

    private static func makeRenderedSegment(for segment: MenuBarItem, style: MenuBarTextLayout.Style) -> RenderedSegment {
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: MenuBarTextLayout.textFont(for: style),
            .foregroundColor: segment.color,
        ]
        let text = NSAttributedString(string: segment.text, attributes: textAttributes)
        let textSize = text.size()
        let textSlotWidth = MenuBarTextLayout.slotWidth(for: segment.panel, style: style)
        let icon = iconImage(for: segment, style: style)
        let iconSlotSize = icon == nil ? 0 : style.iconSlotSize
        let iconSpacing = icon == nil ? 0 : style.iconSpacing
        let contentHeight = ceil(max(textSize.height, iconSlotSize))

        return RenderedSegment(
            segment: segment,
            text: text,
            icon: icon,
            textSize: textSize,
            iconSlotSize: iconSlotSize,
            textSlotWidth: textSlotWidth,
            iconSpacing: iconSpacing,
            contentHeight: contentHeight,
            totalWidth: iconSlotSize + iconSpacing + textSlotWidth
        )
    }

    private static func iconImage(for segment: MenuBarItem, style: MenuBarTextLayout.Style) -> NSImage? {
        let paletteColors = segment.symbolPaletteColors ?? [segment.color]
        return NSImage(systemSymbolName: segment.symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(symbolConfiguration(
                pointSize: style.symbolPointSize,
                paletteColors: paletteColors
            ))
    }

    private struct RenderedSegment {
        let segment: MenuBarItem
        let text: NSAttributedString
        let icon: NSImage?
        let textSize: CGSize
        let iconSlotSize: CGFloat
        let textSlotWidth: CGFloat
        let iconSpacing: CGFloat
        let contentHeight: CGFloat
        let totalWidth: CGFloat
    }
}
