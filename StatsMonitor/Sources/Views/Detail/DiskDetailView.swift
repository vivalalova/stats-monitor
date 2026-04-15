import SwiftUI

struct DiskDetailView: View {
    static let panelTitle = "Disk"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: diskChartLines, maxValue: diskChartMax)
            DetailMetricSection(rows: [
                ("↓ Read", monitor.diskReadText),
                ("↑ Write", monitor.diskWriteText),
                ("Total I/O", monitor.diskActivityText),
            ])
            Divider()
            DetailMetricSection(rows: [
                ("Percent", monitor.diskPercent),
                ("Used", monitor.diskUsedText),
                ("Free", monitor.diskFreeText),
                ("Total", monitor.diskTotalText),
            ])
            DetailMetricSection(title: "System", rows: [
                ("Temperature", monitor.cpuTempText),
                ("System Power", monitor.powerText),
            ])
            DetailListSection(
                "Top Processes",
                data: Array(monitor.topDiskProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(
                    verbatim: entry.element.name,
                    value: "↓\(monitor.formatProcessDisk(entry.element.diskReadBPS)) ↑\(monitor.formatProcessDisk(entry.element.diskWriteBPS))"
                )
            }
        }
    }

    private var diskChartLines: [(history: [Double], color: Color)] {
        [(monitor.paddedDiskReadHistory, .yellow), (monitor.paddedDiskWriteHistory, .orange)]
    }

    private var diskChartMax: Double {
        max((monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory).max() ?? 1, 1_048_576)
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    DiskDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
