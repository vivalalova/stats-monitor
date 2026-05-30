import SwiftUI

/// Mini line chart drawn with Canvas + Path. Supports multiple series.
struct LineChartView: View {
    var lines: [ChartSeries]
    var maxValue: Double = 100
    var height: CGFloat? = 100
    var cornerRadius: CGFloat = 4
    var showsBackground: Bool = true

    var body: some View {
        Canvas { context, size in
            let effectiveMax = maxValue > 0 ? maxValue : 1

            for line in lines {
                guard line.history.count >= 2 else { continue }

                let points: [CGPoint] = line.history.enumerated().map { i, val in
                    let x = size.width * Double(i) / Double(line.history.count - 1)
                    let y = size.height * (1.0 - min(val / effectiveMax, 1.0))
                    return CGPoint(x: x, y: y)
                }

                // Fill area under the line
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: points[0].x, y: size.height))
                for pt in points { fillPath.addLine(to: pt) }
                fillPath.addLine(to: CGPoint(x: points.last!.x, y: size.height))
                fillPath.closeSubpath()
                context.fill(fillPath, with: .color(line.color.opacity(0.15)))

                // Stroke the line
                var linePath = Path()
                linePath.move(to: points[0])
                for pt in points.dropFirst() { linePath.addLine(to: pt) }
                context.stroke(linePath, with: .color(line.color), lineWidth: 1.5)
            }
        }
        .frame(height: height)
        .modifier(LineChartBackgroundModifier(enabled: showsBackground, cornerRadius: cornerRadius))
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

private struct LineChartBackgroundModifier: ViewModifier {
    let enabled: Bool
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let history = (0..<60).map { _ in Double.random(in: 0...100) }
    LineChartView(lines: [
        ChartSeries(history: history, color: .blue),
        ChartSeries(history: (0..<60).map { _ in Double.random(in: 0...60) }, color: .green),
    ])
    .padding()
    .frame(width: 280)
}
