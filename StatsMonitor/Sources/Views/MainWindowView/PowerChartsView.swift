import SwiftUI

struct PowerChartsView: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    var body: some View {
        MetricGridPage(
            columns: MainWindowMetricGridLayout.columns(for: settings.dashboardColumns),
            gridSpacing: MainWindowMetricGridLayout.spacing
        ) {
            MetricChartCard(
                title: "Total",
                value: monitor.powerText,
                status: MetricStatus(watts: monitor.power?.totalWatts ?? 0),
                lines: powerChartLines(monitor: monitor),
                maxValue: powerChartMax
            )
            MetricChartCard(
                title: "CPU",
                value: monitor.cpuPowerText,
                lines: [ChartSeries(history: monitor.paddedCPUPowerHistory, color: .orange)],
                maxValue: powerChartMax
            )
            MetricChartCard(
                title: "GPU",
                value: monitor.gpuPowerText,
                lines: [ChartSeries(history: monitor.paddedGPUPowerHistory, color: .purple)],
                maxValue: powerChartMax
            )
            if monitor.hasMediaEngine {
                MetricChartCard(
                    title: "Media Engine",
                    value: monitor.gpuMediaEnginePowerText,
                    lines: [ChartSeries(history: monitor.paddedGPUMediaEngineHistory, color: .pink)],
                    maxValue: powerChartMax
                )
            }
            if monitor.hasExternalInputPower {
                MetricChartCard(
                    title: "External Input",
                    value: monitor.externalInputPowerText,
                    lines: [ChartSeries(history: monitor.paddedExternalInputPowerHistory, color: .blue)],
                    maxValue: powerChartMax
                )
            }
            if monitor.hasBatteryFlowPower {
                MetricChartCard(
                    title: "Battery Flow",
                    value: monitor.batteryFlowPowerText,
                    lines: [ChartSeries(history: monitor.paddedBatteryFlowPowerHistory, color: .green)],
                    maxValue: powerChartMax
                )
            }
        } footer: {
            TopPowerProcessesTable(monitor: monitor)
        }
    }

    private var powerChartMax: Double {
        max(
            (
                monitor.paddedPowerHistory
                + monitor.paddedCPUPowerHistory
                + monitor.paddedGPUPowerHistory
                + monitor.paddedGPUMediaEngineHistory
                + monitor.paddedExternalInputPowerHistory
                + monitor.paddedBatteryFlowPowerHistory
            ).max() ?? 0,
            1
        )
    }

}

private struct TopPowerProcessesTable: View {
    var monitor: SystemMonitor

    var body: some View {
        if !monitor.topPowerProcesses.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top Energy Impact")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                GlassEffectContainer(spacing: 2) {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text("Impact")
                                .frame(width: ProcessColumnWidth.impact, alignment: .trailing)
                            Text("CPU%")
                                .frame(width: ProcessColumnWidth.cpu, alignment: .trailing)
                            Text("Memory")
                                .frame(width: ProcessColumnWidth.memory, alignment: .trailing)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)

                        Divider()

                        ForEach(monitor.topPowerProcesses, id: \.mergeKey) { process in
                            HStack {
                                ProcessNameCell(process: process)
                                Spacer()
                                // powerImpact 非 optional，這一欄永遠有值。
                                ProcessValueCell(
                                    text: monitor.formatProcessPower(process),
                                    width: ProcessColumnWidth.impact,
                                    hasValue: true
                                )
                                ProcessValueCell(
                                    text: monitor.formatProcessCPU(process.cpuPercent),
                                    width: ProcessColumnWidth.cpu,
                                    hasValue: process.cpuPercent != nil
                                )
                                ProcessValueCell(
                                    text: monitor.formatProcessMemory(process.memoryBytes),
                                    width: ProcessColumnWidth.memory,
                                    hasValue: process.memoryBytes != nil
                                )
                            }
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .prewarmProcessIcons(monitor.topPowerProcesses)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    PowerChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
