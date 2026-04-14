import SwiftUI

struct GPUDetailView: View {
    var viewModel: StatsViewModel

    var body: some View {
        DetailPanel(id: .gpu) {
            if viewModel.gpuHistory.count >= 2 {
                LineChartView(lines: [(viewModel.gpuHistory, .purple)])
            }

            statRow("Device",   value: viewModel.gpuPercent)
            statRow("Renderer", value: viewModel.gpuRenderPercent)
            if viewModel.gpuVramUsed > 0 {
                statRow("GPU Mem", value: viewModel.gpuVramUsedStr)
            }
            if viewModel.anePowerMilliWatts > 0 {
                statRow("Neural Engine", value: viewModel.anePowerStr)
            }
            ProgressView(value: viewModel.monitor.stats.gpu.used / 100)
                .tint(progressColor(viewModel.monitor.stats.gpu.used / 100))

            if !viewModel.gpuEngines.isEmpty {
                sectionHeader("Engines")
                EngineGridView(engines: viewModel.gpuEngines)
            }
        }
    }
}

#Preview {
    GPUDetailView(viewModel: StatsViewModel())
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
