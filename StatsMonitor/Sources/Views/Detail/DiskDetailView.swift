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
            Divider()
            statRow("Used",  value: monitor.diskUsedText)
            statRow("Free",  value: monitor.diskFreeText)
            statRow("Total", value: monitor.diskTotalText)
            if !monitor.topDiskProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(monitor.topDiskProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(verbatim: proc.name, value: "↓\(monitor.formatProcessDisk(proc.diskReadBPS)) ↑\(monitor.formatProcessDisk(proc.diskWriteBPS))")
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    DiskDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
