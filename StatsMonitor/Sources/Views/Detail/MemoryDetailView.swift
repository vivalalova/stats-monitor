import SwiftUI

struct MemoryDetailView: View {
    static let panelTitle = "Memory"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if monitor.paddedMemoryHistory.count >= 2 {
                LineChartView(lines: [(monitor.paddedMemoryHistory, .orange)])
            }

            statRow("Used",       value: "\(monitor.memoryUsedText) / \(monitor.memoryTotalText)")
            statRow("Active",     value: monitor.memoryActiveText)
            statRow("Wired",      value: monitor.memoryWiredText)
            statRow("Compressed", value: monitor.memoryCompressedText)
            if !monitor.topMemoryProcesses.isEmpty {
                sectionHeader("Top Processes")
                ForEach(Array(monitor.topMemoryProcesses.enumerated()), id: \.offset) { _, proc in
                    statRow(verbatim: proc.name, value: monitor.formatProcessMemory(proc.memoryBytes))
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MemoryDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
