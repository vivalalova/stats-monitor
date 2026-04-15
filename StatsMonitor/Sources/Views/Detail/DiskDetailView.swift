import SwiftUI

struct DiskDetailView: View {
    static let panelTitle = "Disk"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            let maxIO = max(
                (monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory).max() ?? 1,
                1_048_576
            )

            LineChartView(
                lines: [(monitor.paddedDiskReadHistory, .yellow), (monitor.paddedDiskWriteHistory, .orange)],
                maxValue: maxIO
            )

            statRow("↓ Read",  value: monitor.diskReadText)
            statRow("↑ Write", value: monitor.diskWriteText)
            statRow("Total I/O", value: monitor.diskActivityText)
            Divider()
            statRow("Percent", value: monitor.diskPercent)
            statRow("Used",  value: monitor.diskUsedText)
            statRow("Free",  value: monitor.diskFreeText)
            statRow("Total", value: monitor.diskTotalText)
            sectionHeader("System")
            statRow("Temperature", value: monitor.cpuTempText)
            statRow("System Power", value: monitor.powerText)
            if !monitor.topDiskProcesses.isEmpty {
                sectionHeader("Top Processes")
                compactRows(Array(monitor.topDiskProcesses.enumerated()), id: \.offset) { entry in
                    statRow(
                        verbatim: entry.element.name,
                        value: "↓\(monitor.formatProcessDisk(entry.element.diskReadBPS)) ↑\(monitor.formatProcessDisk(entry.element.diskWriteBPS))"
                    )
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    DiskDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
