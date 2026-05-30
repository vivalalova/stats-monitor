import SwiftUI

struct SidebarMetricRow: View {
    let title: String
    let value: String
    let statusColor: Color
    let lines: [ChartSeries]
    let maxValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(LocalizedStringKey(title))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer(minLength: 4)
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
            }
            Text(value)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            LineChartView(
                lines: lines,
                maxValue: maxValue,
                height: nil,
                cornerRadius: 0,
                showsBackground: false
            )
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: 64, alignment: .topLeading)
        .frame(maxWidth: .infinity)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let history = (0..<60).map { _ in Double.random(in: 0...100) }
    VStack(spacing: 4) {
        SidebarMetricRow(
            title: "CPU",
            value: "29.1%",
            statusColor: .green,
            lines: [ChartSeries(history: history, color: .blue)],
            maxValue: 100
        )
        SidebarMetricRow(
            title: "Network",
            value: "↓5 KB/s",
            statusColor: .blue,
            lines: [
                ChartSeries(history: history, color: .green),
                ChartSeries(history: Array(history.reversed()), color: .red)
            ],
            maxValue: 100
        )
    }
    .frame(width: 114)
    .padding()
}
