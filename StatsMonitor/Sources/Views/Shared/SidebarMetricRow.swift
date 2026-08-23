import SwiftUI

struct SidebarMetricRow: View {
    let title: String
    let value: String
    let lines: [ChartSeries]
    let maxValue: Double
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(LocalizedStringKey(title))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            LineChartView(
                lines: lines,
                maxValue: maxValue,
                height: nil,
                cornerRadius: 0,
                showsBackground: false
            )
            .frame(width: SidebarRowLayout.chartWidth)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(height: SidebarRowLayout.height)
        .frame(maxWidth: .infinity)
        .sidebarSelection(isSelected)
    }
}

enum SidebarRowLayout {
    static let height: CGFloat = 48
    static let chartWidth: CGFloat = 48
    static let cornerRadius: CGFloat = 8
}

extension View {
    /// sidebar 選取態的唯一樣式來源：chart 列與文字導覽列共用同一套 Liquid Glass 語言。
    @ViewBuilder
    func sidebarSelection(_ isSelected: Bool) -> some View {
        if isSelected {
            glassEffect(
                .regular.tint(.accentColor.opacity(0.25)).interactive(),
                in: RoundedRectangle(cornerRadius: SidebarRowLayout.cornerRadius)
            )
        } else {
            self
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let history = (0..<60).map { _ in Double.random(in: 0...100) }
    VStack(spacing: 4) {
        SidebarMetricRow(
            title: "CPU",
            value: "29.1%",
            lines: [ChartSeries(history: history, color: .blue)],
            maxValue: 100,
            isSelected: true
        )
        SidebarMetricRow(
            title: "Network",
            value: "↓5 KB/s",
            lines: [
                ChartSeries(history: history, color: NetworkChartPalette.inbound),
                ChartSeries(history: Array(history.reversed()), color: NetworkChartPalette.outbound),
            ],
            maxValue: 100
        )
    }
    .frame(width: 114)
    .padding()
}
