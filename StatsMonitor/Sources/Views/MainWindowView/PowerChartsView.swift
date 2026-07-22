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
                statusColor: powerStatusColor(monitor.power?.totalWatts ?? 0),
                lines: powerChartLines(monitor: monitor),
                maxValue: powerChartMax
            )
            MetricChartCard(
                title: "CPU",
                value: monitor.cpuPowerText,
                statusColor: .orange,
                lines: [ChartSeries(history: monitor.paddedCPUPowerHistory, color: .orange)],
                maxValue: powerChartMax
            )
            MetricChartCard(
                title: "GPU",
                value: monitor.gpuPowerText,
                statusColor: .purple,
                lines: [ChartSeries(history: monitor.paddedGPUPowerHistory, color: .purple)],
                maxValue: powerChartMax
            )
            if monitor.hasMediaEngine {
                MetricChartCard(
                    title: "Media Engine",
                    value: monitor.gpuMediaEnginePowerText,
                    statusColor: .pink,
                    lines: [ChartSeries(history: monitor.paddedGPUMediaEngineHistory, color: .pink)],
                    maxValue: powerChartMax
                )
            }
            if monitor.hasExternalInputPower {
                MetricChartCard(
                    title: "External Input",
                    value: monitor.externalInputPowerText,
                    statusColor: .blue,
                    lines: [ChartSeries(history: monitor.paddedExternalInputPowerHistory, color: .blue)],
                    maxValue: powerChartMax
                )
            }
            if monitor.hasBatteryFlowPower {
                MetricChartCard(
                    title: "Battery Flow",
                    value: monitor.batteryFlowPowerText,
                    statusColor: batteryFlowStatusColor,
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

    private var batteryFlowStatusColor: Color {
        let batteryMilliWatts = monitor.power?.batteryMilliWatts ?? 0
        switch batteryMilliWatts {
        case let value where value > 0:
            return .green
        case let value where value < 0:
            return .red
        default:
            return .secondary
        }
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
                                .frame(width: 74, alignment: .trailing)
                            Text("CPU%")
                                .frame(width: 60, alignment: .trailing)
                            Text("Memory")
                                .frame(width: 80, alignment: .trailing)
                        }
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)

                        Divider()

                        ForEach(monitor.topPowerProcesses, id: \.name) { process in
                            HStack {
                                Text(process.name)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Text(monitor.formatProcessPower(process))
                                    .frame(width: 74, alignment: .trailing)
                                Text(monitor.formatProcessCPU(process.cpuPercent))
                                    .frame(width: 60, alignment: .trailing)
                                Text(monitor.formatProcessMemory(process.memoryBytes))
                                    .frame(width: 80, alignment: .trailing)
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
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    PowerChartsView(settings: settings, monitor: monitor)
        .frame(width: 700, height: 520)
}
