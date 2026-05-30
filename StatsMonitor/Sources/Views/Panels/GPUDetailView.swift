import SwiftUI

struct GPUDetailView: View {
    static let panelTitle = "GPU"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: [ChartSeries(history: monitor.paddedGPUHistory, color: .purple)])
            DetailMetricSection(rows: availableDetailMetrics([
                ("Device", monitor.gpuPercent),
                ("Renderer", monitor.gpuRenderPercent),
                ("Tiler", monitor.gpuTilerPercent),
            ]))
            DetailMetricSection(title: "Memory", rows: availableDetailMetrics([
                ("Used", monitor.gpuVramUsedText),
                ("Driver", monitor.gpuDriverMemoryText),
                ("Allocated", monitor.gpuAllocatedMemoryText),
            ]))
            if monitor.anePowerMilliWatts > 0 {
                statRow("Neural Engine", value: monitor.anePowerText)
            }
            if !monitor.gpuEngines.isEmpty {
                sectionHeader("Engines")
                EngineGridView(engines: monitor.gpuEngines)
            }
            DetailListSection(
                "Top GPU Apps",
                data: Array(monitor.topGPUProcesses.enumerated()),
                id: \.element.pid
            ) { entry in
                statRow(verbatim: entry.element.name, value: monitor.formatProcessGPU(entry.element))
            }
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    GPUDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}

// MARK: - Engine grid

private struct EngineGridView: View {
    var engines: [String: Double]

    private var sorted: [(key: String, value: Double)] {
        engines.sorted { $0.key < $1.key }
    }

    private var effectiveColumns: Int { min(sorted.count, 8) }

    private var barWidth: CGFloat {
        (BarMetrics.contentWidth - BarMetrics.spacing * CGFloat(effectiveColumns - 1)) / CGFloat(effectiveColumns)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: BarMetrics.spacing) {
            ForEach(sorted, id: \.key) { item in
                VStack(spacing: 1) {
                    BarView(width: barWidth, color: .purple, value: item.value)
                    Text(abbreviate(item.key))
                        .foregroundStyle(.secondary)
                    Text("\(Int(item.value))%")
                }
                .font(.system(size: 7))
                .monospacedDigit()
            }
        }
    }

    // Single-word → first 4 chars. Multi-word → uppercased initials.
    private func abbreviate(_ name: String) -> String {
        let words = name.split(separator: " ")
        if words.count == 1 { return String(words[0].prefix(4)) }
        return words.map { String($0.prefix(1).uppercased()) }.joined()
    }
}
