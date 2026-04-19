import AppKit

@MainActor
struct StatusBarLayout {
    struct PlacedSegment {
        let segment: MenuBarItem
        let text: NSAttributedString
        let icon: NSImage?
        let textSize: CGSize
        let textFrame: CGRect
        let iconFrame: CGRect
        let frame: CGRect
        let rowIndex: Int
    }

    static let empty = StatusBarLayout(
        placedSegments: [],
        contentSize: .zero,
        contentInset: 0,
        style: MenuBarTextLayout.style(forRowCount: 1),
        rowHeight: 0,
        rowSpacing: 0
    )

    let placedSegments: [PlacedSegment]
    let contentSize: CGSize
    let contentInset: CGFloat
    let style: MenuBarTextLayout.Style
    let rowHeight: CGFloat
    let rowSpacing: CGFloat

    var rowCount: Int {
        placedSegments.isEmpty ? 0 : (placedSegments.map(\.rowIndex).max() ?? 0) + 1
    }

    var itemWidth: CGFloat {
        ceil(contentSize.width) + contentInset * 2
    }

    func contentFrame(in bounds: CGRect) -> CGRect {
        CGRect(
            x: contentInset,
            y: floor((bounds.height - contentSize.height) / 2),
            width: contentSize.width,
            height: contentSize.height
        )
    }

    func frame(for panel: PanelID, in bounds: CGRect) -> CGRect? {
        guard let placedSegment = placedSegments.first(where: { $0.segment.panel == panel }) else {
            return nil
        }

        let contentFrame = contentFrame(in: bounds)
        return placedSegment.frame.offsetBy(dx: contentFrame.minX, dy: contentFrame.minY)
    }

    func panel(at point: CGPoint, in bounds: CGRect) -> PanelID? {
        guard !placedSegments.isEmpty else { return nil }

        let contentFrame = contentFrame(in: bounds)
        let localPoint = CGPoint(x: point.x - contentFrame.minX, y: point.y - contentFrame.minY)

        if let hitPanel = placedSegments.first(where: { $0.frame.contains(localPoint) })?.segment.panel {
            return hitPanel
        }

        let nearestRow = nearestRowIndex(to: localPoint.y)
        let rowSegments = placedSegments.filter { $0.rowIndex == nearestRow }
        guard !rowSegments.isEmpty else { return placedSegments.first?.segment.panel }

        if localPoint.x <= rowSegments[0].frame.minX {
            return rowSegments[0].segment.panel
        }

        if localPoint.x >= rowSegments[rowSegments.count - 1].frame.maxX {
            return rowSegments[rowSegments.count - 1].segment.panel
        }

        return rowSegments.min { lhs, rhs in
            abs(lhs.frame.midX - localPoint.x) < abs(rhs.frame.midX - localPoint.x)
        }?.segment.panel
    }

    private func nearestRowIndex(to y: CGFloat) -> Int {
        let clampedRowHeight = max(rowHeight + rowSpacing, 1)
        let rawIndex = Int(((contentSize.height - y) / clampedRowHeight).rounded(.down))
        return min(max(rawIndex, 0), max(rowCount - 1, 0))
    }
}
