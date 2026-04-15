import SwiftUI

struct MemoryDetailView: View {
    static let panelTitle = "Memory"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            if monitor.paddedMemoryHistory.count >= 2 {
                LineChartView(lines: [(monitor.paddedMemoryHistory, .orange)])
            }

            statRow("Percent",    value: monitor.memoryPercent)
            statRow("Used",       value: "\(monitor.memoryUsedText) / \(monitor.memoryTotalText)")
            statRow("Free",       value: monitor.memoryFreeText)
            statRow("Active",     value: monitor.memoryActiveText)
            statRow("Wired",      value: monitor.memoryWiredText)
            statRow("Compressed", value: monitor.memoryCompressedText)
            sectionHeader("System")
            statRow("Temperature", value: monitor.cpuTempText)
            statRow("System Power", value: monitor.powerText)
            if !monitor.topMemoryProcesses.isEmpty {
                sectionHeader("Top Processes")
                compactRows(Array(monitor.topMemoryProcesses.enumerated()), id: \.offset) { entry in
                    statRow(verbatim: entry.element.name, value: monitor.formatProcessMemory(entry.element.memoryBytes))
                }
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    MemoryDetailView(monitor: SystemMonitor(settings: AppSettings()))
}
