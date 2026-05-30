import SwiftUI

struct FansDetailView: View {
    static let panelTitle = "Fans"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(
                lines: [ChartSeries(history: monitor.paddedFanAverageHistory, color: .blue)],
                maxValue: monitor.fanChartMaxRPM
            )
            DetailMetricSection(rows: [
                ("Average", monitor.fansSummaryText),
                ("Count", monitor.fanCountText),
            ])
            DetailListSection("Per Fan", data: Array(monitor.fans.enumerated()), id: \.element.id) { entry in
                let fan = entry.element
                statRow(
                    verbatim: fan.name,
                    value: "\(monitor.fanRPMText(fan))  \(monitor.fanRangeText(fan))"
                )
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    FansDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
