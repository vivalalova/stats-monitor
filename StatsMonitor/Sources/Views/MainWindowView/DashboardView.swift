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
        MetricGridPage(columns: columns, gridSpacing: 4) {
            MetricChartCard(
                title: "CPU",
                value: monitor.cpuPercent,
                statusColor: progressColor(monitor.cpuFraction),
                lines: [ChartSeries(history: monitor.paddedCPUHistory, color: .blue)],
                maxValue: histMax(monitor.paddedCPUHistory)
            )
            MetricChartCard(
                title: "GPU",
                value: monitor.gpuPercent,
                statusColor: progressColor(monitor.gpuFraction),
                lines: [ChartSeries(history: monitor.paddedGPUHistory, color: .purple)],
                maxValue: histMax(monitor.paddedGPUHistory)
            )
            MetricChartCard(
                title: "Memory",
                value: monitor.memoryPercent,
                statusColor: progressColor(monitor.memoryFraction),
                lines: [ChartSeries(history: monitor.paddedMemoryHistory, color: .cyan)],
                maxValue: histMax(monitor.paddedMemoryHistory)
            )
            MetricChartCard(
                title: "Network",
                value: "↓\(monitor.networkInText)  ↑\(monitor.networkOutText)",
                statusColor: .blue,
                lines: [
                    ChartSeries(history: monitor.paddedNetworkInHistory, color: .blue),
                    ChartSeries(history: monitor.paddedNetworkOutHistory, color: .green),
                ],
                maxValue: histMax(monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory)
            )
            MetricChartCard(
                title: "Disk I/O",
                value: "↓\(monitor.diskReadText)  ↑\(monitor.diskWriteText)",
                statusColor: .blue,
                lines: [
                    ChartSeries(history: monitor.paddedDiskReadHistory, color: .teal),
                    ChartSeries(history: monitor.paddedDiskWriteHistory, color: .orange),
                ],
                maxValue: histMax(monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory)
            )
            if monitor.hasPower {
                MetricChartCard(
                    title: "Power",
                    value: monitor.powerText,
                    statusColor: powerStatusColor(monitor.power?.totalWatts ?? 0),
                    lines: [ChartSeries(history: monitor.paddedPowerHistory, color: .red)],
                    maxValue: histMax(monitor.paddedPowerHistory)
                )
            }
            if monitor.hasFans {
                MetricChartCard(
                    title: "Fans",
                    value: monitor.fansSummaryText,
                    statusColor: .blue,
                    lines: monitor.paddedFanAverageHistory.count >= 2
                        ? [ChartSeries(history: monitor.paddedFanAverageHistory, color: .blue)]
                        : [],
                    maxValue: monitor.fanChartMaxRPM
                )
            }
        } footer: {
            TopProcessesTable(settings: settings, monitor: monitor, initialSort: .cpu)
        }
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

func dashboardCardHasChart(lines: [ChartSeries]) -> Bool {
    !lines.isEmpty
}

func dashboardCardHeight(lines: [ChartSeries]) -> CGFloat {
    dashboardCardHasChart(lines: lines) ? 100 : 52
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    DashboardView(settings: settings, monitor: monitor)
        .frame(
            width: SettingsWindowLayout.defaultWidth,
            height: SettingsWindowLayout.defaultHeight
        )
}
