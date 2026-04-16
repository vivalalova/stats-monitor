import SwiftUI

struct MemoryDetailView: View {
    static let panelTitle = "Memory"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [(monitor.paddedMemoryHistory, .orange)])
            DetailMetricSection(rows: [
                ("Percent", monitor.memoryPercent),
                ("Used", "\(monitor.memoryUsedText) / \(monitor.memoryTotalText)"),
                ("Free", monitor.memoryFreeText),
                ("Active", monitor.memoryActiveText),
                ("Wired", monitor.memoryWiredText),
                ("Compressed", monitor.memoryCompressedText),
            ])
            DetailListSection(
                "Top Processes",
                data: Array(monitor.topMemoryProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(verbatim: entry.element.name, value: monitor.formatProcessMemory(entry.element.memoryBytes))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MemoryDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}
