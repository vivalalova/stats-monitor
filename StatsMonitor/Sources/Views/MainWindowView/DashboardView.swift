import SwiftUI

// MARK: - DashboardView

struct DashboardView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    // 等寬填滿 detail 寬度：欄數由 slider 決定，卡片各佔 1/n。
    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: MainWindowMetricGridLayout.spacing),
            count: settings.dashboardColumns
        )
    }

    private func histMax(_ h: [Double]) -> Double {
        max(h.max() ?? 0, 1)
    }

    var body: some View {
        MetricGridPage(columns: columns, gridSpacing: MainWindowMetricGridLayout.spacing) {
            MetricChartCard(
                title: "CPU",
                value: monitor.cpuPercent,
                status: MetricStatus(fraction: monitor.cpuFraction),
                lines: [ChartSeries(history: monitor.paddedCPUHistory, color: .blue)],
                maxValue: histMax(monitor.paddedCPUHistory)
            )
            MetricChartCard(
                title: "GPU",
                value: monitor.gpuPercent,
                status: MetricStatus(fraction: monitor.gpuFraction),
                lines: [ChartSeries(history: monitor.paddedGPUHistory, color: .purple)],
                maxValue: histMax(monitor.paddedGPUHistory)
            )
            MetricChartCard(
                title: "Memory",
                value: monitor.memoryPercent,
                status: MetricStatus(fraction: monitor.memoryFraction),
                lines: [ChartSeries(history: monitor.paddedMemoryHistory, color: .cyan)],
                maxValue: histMax(monitor.paddedMemoryHistory)
            )
            MetricChartCard(
                title: "Network",
                value: "↓\(monitor.networkInText)  ↑\(monitor.networkOutText)",
                lines: networkChartLines(monitor: monitor),
                legendLabels: NetworkChartLegend.labels,
                maxValue: histMax(monitor.paddedNetworkInHistory + monitor.paddedNetworkOutHistory)
            )
            MetricChartCard(
                title: "Disk I/O",
                value: "↓\(monitor.diskReadText)  ↑\(monitor.diskWriteText)",
                lines: [
                    ChartSeries(history: monitor.paddedDiskReadHistory, color: .teal),
                    ChartSeries(history: monitor.paddedDiskWriteHistory, color: .orange),
                ],
                legendLabels: ["↓ Read", "↑ Write"],
                maxValue: histMax(monitor.paddedDiskReadHistory + monitor.paddedDiskWriteHistory)
            )
            if monitor.hasPowerTelemetry {
                MetricChartCard(
                    title: "Power",
                    value: monitor.powerText,
                    status: MetricStatus(watts: monitor.power?.totalWatts ?? 0),
                    lines: powerChartLines(monitor: monitor),
                    maxValue: powerChartUpperBound(monitor: monitor)
                )
            }
            if monitor.hasFans {
                MetricChartCard(
                    title: "Fans",
                    value: monitor.fansSummaryText,
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
        HStack(spacing: 6) {
            // toolbar 的 .automatic label style 會收成 icon-only，明寫 titleAndIcon 才保得住標籤。
            Label("Card Size", systemImage: "square.grid.2x2")
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Slider(value: Self.binding(for: settings), in: Self.valueRange, step: 1)
                .frame(width: 110)
        }
    }
}

// MARK: - Dashboard Helpers

@MainActor
func powerChartLines(monitor: SystemMonitor) -> [ChartSeries] {
    var lines = [ChartSeries(history: monitor.paddedPowerHistory, color: .red)]
    if monitor.hasExternalInputPower {
        lines.append(ChartSeries(history: monitor.paddedExternalInputPowerHistory, color: .green))
    }
    return lines
}

// MARK: - Network Chart Palette

/// 網路上下行配色的唯一來源：Dashboard 卡、sidebar 列、Network 頁一律引用這裡。
enum NetworkChartPalette {
    static let inbound: Color = .blue
    static let outbound: Color = .green
}

/// 網路雙線圖 legend 文案，順序對齊 `networkChartLines` 的 [in, out]。
enum NetworkChartLegend {
    /// 計算屬性而非 `static let`：`LocalizedStringKey` 非 Sendable，存成全域常數在 Swift 6 是錯誤。
    static var labels: [LocalizedStringKey] { ["↓ In", "↑ Out"] }
}

/// 上下行雙線，順序固定 [in, out]。
@MainActor
func networkChartLines(monitor: SystemMonitor) -> [ChartSeries] {
    [networkInChartLine(monitor: monitor), networkOutChartLine(monitor: monitor)]
}

@MainActor
func networkInChartLine(monitor: SystemMonitor) -> ChartSeries {
    ChartSeries(history: monitor.paddedNetworkInHistory, color: NetworkChartPalette.inbound)
}

@MainActor
func networkOutChartLine(monitor: SystemMonitor) -> ChartSeries {
    ChartSeries(history: monitor.paddedNetworkOutHistory, color: NetworkChartPalette.outbound)
}

@MainActor
func powerChartUpperBound(monitor: SystemMonitor) -> Double {
    max(powerChartLines(monitor: monitor).flatMap(\.history).max() ?? 0, 1)
}

func dashboardCardHasChart(lines: [ChartSeries]) -> Bool {
    !lines.isEmpty
}

// 卡片高度 = 固定開銷（padding、caption 標題、.title2 數值、spacing ≈ 64pt）+ chart 區；
// chart 區取原本 72pt 的七成（≈ 48pt）讓多卡頁少捲動，legend 卡另補 legend 自身高度（≈ 16pt），
// 兩種卡的 chart 區才一樣高。改字級或 legend 樣式要一起重算。
func dashboardCardHeight(lines: [ChartSeries], hasLegend: Bool) -> CGFloat {
    guard dashboardCardHasChart(lines: lines) else { return 72 }
    return hasLegend ? 128 : 112
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
