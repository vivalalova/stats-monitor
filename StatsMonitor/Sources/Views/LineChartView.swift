import SwiftUI

/// Mini line chart drawn with Canvas + Path.
/// history: sequence of values; maxValue: the 100% line (default 100 for percentage).
struct LineChartView: View {
    var history: [Double]
    var maxValue: Double = 100
    var color: Color = .blue
    var height: CGFloat = 100

    var body: some View {
        Canvas { context, size in
            guard history.count >= 2 else { return }

            let effectiveMax = maxValue > 0 ? maxValue : 1
            let points: [CGPoint] = history.enumerated().map { i, val in
                let x = size.width * Double(i) / Double(history.count - 1)
                let y = size.height * (1.0 - min(val / effectiveMax, 1.0))
                return CGPoint(x: x, y: y)
            }

            // Fill area under the line
            var fillPath = Path()
            fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
            for pt in points { fillPath.addLine(to: pt) }
            fillPath.addLine(to: CGPoint(x: points.last!.x, y: size.height))
            fillPath.closeSubpath()
            context.fill(fillPath, with: .color(color.opacity(0.15)))

            // Stroke the line
            var linePath = Path()
            linePath.move(to: points[0])
            for pt in points.dropFirst() { linePath.addLine(to: pt) }
            context.stroke(linePath, with: .color(color), lineWidth: 1.5)
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}
