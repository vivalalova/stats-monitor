import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 4), count: settings.dashboardColumns)
    }

    private func histMax(_ h: [Double]) -> Double {
        max(h.max() ?? 0, 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                LazyVGrid(columns: columns, spacing: 4) {
                    MetricChartCard(
                        title: "CPU",
                        value: monitor.cpuPercent,
                        statusColor: progressColor(monitor.cpuFraction),
                        lines: [(history: monitor.paddedCPUHistory, color: .blue)],
                        maxValue: histMax(monitor.paddedCPUHistory)
                    )
                    MetricChartCard(
                        title: "GPU",
                        value: monitor.gpuPercent,
                        statusColor: progressColor(monitor.gpuFraction),
                        lines: [(history: monitor.paddedGPUHistory, color: .purple)],
                        maxValue: histMax(monitor.paddedGPUHistory)
                    )
                    MetricChartCard(
                        title: "Memory",
                        value: monitor.memoryPercent,
                        statusColor: progressColor(monitor.memoryFraction),
                        lines: [(history: monitor.paddedMemoryHistory, color: .cyan)],
                        maxValue: histMax(monitor.paddedMemoryHistory)
                    )
                    MetricChartCard(
                        title: "Network",
                        value: "↓\(monitor.networkInText)  ↑\(monitor.networkOutText)",
                        statusColor: .blue,
                        lines: [
                            (history: monitor.paddedNetworkInHistory,  color: .blue),
                            (history: monitor.paddedNetworkOutHistory, color: .green),
                        ],
                        maxValue: histMax(monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory)
                    )
                    MetricChartCard(
                        title: "Disk I/O",
                        value: "↓\(monitor.diskReadText)  ↑\(monitor.diskWriteText)",
                        statusColor: .blue,
                        lines: [
                            (history: monitor.paddedDiskReadHistory,  color: .teal),
                            (history: monitor.paddedDiskWriteHistory, color: .orange),
                        ],
                        maxValue: histMax(monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory)
                    )
                    if monitor.hasPower {
                        MetricChartCard(
                            title: "Power",
                            value: monitor.powerText,
                            statusColor: powerStatusColor(monitor.power?.totalWatts ?? 0),
                            lines: [(history: monitor.paddedPowerHistory, color: .red)],
                            maxValue: histMax(monitor.paddedPowerHistory)
                        )
                    }
                    if monitor.hasFans {
                        MetricChartCard(
                            title: "Fans",
                            value: monitor.fansSummaryText,
                            statusColor: .blue,
                            lines: monitor.paddedFanAverageHistory.count >= 2
                                ? [(history: monitor.paddedFanAverageHistory, color: .blue)]
                                : [],
                            maxValue: monitor.fanChartMaxRPM
                        )
                    }
                }

                TopProcessesTable(settings: settings, monitor: monitor, initialSort: .cpu)
            }
            .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct DashboardColumnsSlider: View {
    let settings: AppSettings
    private static let valueRange = Double(AppSettings.dashboardColumnRange.lowerBound)...Double(AppSettings.dashboardColumnRange.upperBound)

    static func binding(for settings: AppSettings) -> Binding<Double> {
        Binding(
            get: { Double(settings.dashboardColumns) },
            set: { newValue in
                let clampedValue = min(max(newValue, valueRange.lowerBound), valueRange.upperBound)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    settings.dashboardColumns = Int(clampedValue.rounded())
                }
            }
        )
    }

    var body: some View {
        Slider(value: Self.binding(for: settings), in: Self.valueRange, step: 1)
            .frame(width: 110)
    }
}

// MARK: - Dashboard Helpers

func powerStatusColor(_ watts: Double) -> Color {
    switch watts {
    case ..<10:
        return .green
    case ..<30:
        return .orange
    default:
        return .red
    }
}

func dashboardCardHasChart(lines: [(history: [Double], color: Color)]) -> Bool {
    !lines.isEmpty
}

func dashboardCardHeight(lines: [(history: [Double], color: Color)]) -> CGFloat {
    dashboardCardHasChart(lines: lines) ? 100 : 52
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    DashboardView(settings: settings, monitor: monitor)
        .frame(width: 820, height: 520)
}
