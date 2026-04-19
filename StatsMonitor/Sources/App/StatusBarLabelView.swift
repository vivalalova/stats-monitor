import AppKit

@MainActor
final class StatusBarLabelView: NSView {
    var layout: StatusBarLayout = .empty {
        didSet {
            invalidateIntrinsicContentSize()
            needsDisplay = true
        }
    }

    override var intrinsicContentSize: NSSize {
        layout.contentSize
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let contentFrame = layout.contentFrame(in: bounds)
        for placedSegment in layout.placedSegments {
            if let icon = placedSegment.icon {
                let iconFrame = placedSegment.iconFrame.offsetBy(dx: contentFrame.minX, dy: contentFrame.minY)
                let drawFrame = aspectFitRect(for: icon.size, in: iconFrame)
                icon.draw(in: drawFrame)
            }

            let textOrigin = CGPoint(
                x: contentFrame.minX + placedSegment.textFrame.maxX - placedSegment.textSize.width,
                y: contentFrame.minY + placedSegment.textFrame.minY + floor((placedSegment.textFrame.height - placedSegment.textSize.height) / 2)
            )
            placedSegment.text.draw(at: textOrigin)
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func aspectFitRect(for imageSize: CGSize, in container: CGRect) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return container }

        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let fittedSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: container.minX + (container.width - fittedSize.width) / 2,
            y: container.minY + (container.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}
