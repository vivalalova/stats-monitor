import SwiftUI

struct FansDetailView: View {
    static let panelTitle = "Fans"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if monitor.paddedFanAverageHistory.count >= 2 {
                LineChartView(
                    lines: [(monitor.paddedFanAverageHistory, .blue)],
                    maxValue: monitor.fanChartMaxRPM
                )
            }

            statRow("Average", value: monitor.fansSummaryText)
            statRow("Count", value: monitor.fanCountText)
            sectionHeader("System")
            statRow("CPU Temp", value: monitor.cpuTempText)
            statRow("GPU Temp", value: monitor.gpuTempText)
            statRow("System Power", value: monitor.powerText)

            if !monitor.fans.isEmpty {
                sectionHeader("Per Fan")
                ForEach(Array(monitor.fans.enumerated()), id: \.element.id) { _, fan in
                    statRow(
                        verbatim: fan.name,
                        value: "\(monitor.fanRPMText(fan))  \(monitor.fanRangeText(fan))"
                    )
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    FansDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
