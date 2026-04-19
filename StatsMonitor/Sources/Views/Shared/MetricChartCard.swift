import SwiftUI

struct MetricChartCard: View {
    let title: String
    let value: String
    let statusColor: Color
    let lines: [(history: [Double], color: Color)]
    let maxValue: Double
    var height: CGFloat? = nil

    var body: some View {
        Group {
            if dashboardCardHasChart(lines: lines) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        titleLabel
                        Spacer()
                        statusIndicator
                    }
                    valueLabel
                    LineChartView(
                        lines: lines,
                        maxValue: maxValue,
                        height: nil,
                        cornerRadius: 0,
                        showsBackground: false
                    )
                    .frame(maxHeight: .infinity)
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        titleLabel
                        Spacer()
                        statusIndicator
                    }
                    valueLabel
                }
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(height: height ?? dashboardCardHeight(lines: lines))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var titleLabel: some View {
        Text(LocalizedStringKey(title))
            .font(.subheadline)
            .fontWeight(.semibold)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(statusColor)
            .frame(width: 8, height: 8)
    }

    private var valueLabel: some View {
        Text(value)
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

