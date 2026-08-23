import SwiftUI

struct MetricChartCard: View {
    let title: String
    let value: String
    /// 由數值推導出的健康程度；無狀態語意的卡片（Network／Disk 吞吐、Fans 等）省略不傳，不顯示 capsule。
    var status: MetricStatus? = nil
    let lines: [ChartSeries]
    /// 雙線圖 legend 文案，順序對齊 `lines`；空陣列代表不顯示 legend。
    var legendLabels: [LocalizedStringKey] = []
    let maxValue: Double
    var height: CGFloat? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: hasChart ? 4 : 6) {
            HStack {
                titleLabel
                Spacer()
                statusCapsule
            }
            valueLabel
            if hasChart {
                LineChartView(
                    lines: lines,
                    maxValue: maxValue,
                    height: nil,
                    cornerRadius: 0,
                    showsBackground: false
                )
                .frame(maxHeight: .infinity)
                legend
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
        .frame(height: height ?? dashboardCardHeight(lines: lines))
    }

    private var hasChart: Bool {
        dashboardCardHasChart(lines: lines)
    }

    /// legend 色直接取 `lines` 的線色，兩者不可能不一致。
    private var legendItems: [(color: Color, label: LocalizedStringKey)] {
        zip(lines.map(\.color), legendLabels).map { (color: $0, label: $1) }
    }

    private var titleLabel: some View {
        Text(LocalizedStringKey(title))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private var statusCapsule: some View {
        if let status {
            Text(status.caption)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(status.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(status.color.opacity(0.12)))
                .overlay(Capsule().strokeBorder(status.color.opacity(0.35), lineWidth: 0.5))
        }
    }

    /// 卡片窄時（雙數值如「↓12 KB/s ↑3 KB/s」）自動降到 .title3，避免截字。
    private var valueLabel: some View {
        ViewThatFits(in: .horizontal) {
            valueText(.title2)
            // 最後一段才允許縮字，否則兩個候選都「永遠塞得下」，ViewThatFits 形同虛設。
            valueText(.title3).minimumScaleFactor(0.55)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func valueText(_ font: Font) -> some View {
        Text(value)
            .font(font)
            .foregroundStyle(.primary)
            .monospacedDigit()
            .lineLimit(1)
    }

    @ViewBuilder
    private var legend: some View {
        if !legendItems.isEmpty {
            HStack(spacing: 8) {
                ForEach(Array(legendItems.enumerated()), id: \.offset) { item in
                    Text(item.element.label)
                        .font(.caption2)
                        .foregroundStyle(item.element.color)
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let history = (0..<60).map { _ in Double.random(in: 0...100) }
    HStack(spacing: 8) {
        MetricChartCard(
            title: "CPU",
            value: "11.9%",
            status: .normal,
            lines: [ChartSeries(history: history, color: .blue)],
            maxValue: 100
        )
        MetricChartCard(
            title: "Network",
            value: "↓46 KB/s  ↑12 KB/s",
            lines: [
                ChartSeries(history: history, color: NetworkChartPalette.inbound),
                ChartSeries(history: Array(history.reversed()), color: NetworkChartPalette.outbound),
            ],
            legendLabels: NetworkChartLegend.labels,
            maxValue: 100
        )
    }
    .frame(width: 460)
    .padding()
}
