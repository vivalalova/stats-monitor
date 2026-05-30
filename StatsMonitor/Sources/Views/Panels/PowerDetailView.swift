import SwiftUI

struct PowerDetailView: View {
    static let panelTitle = "Power"

    var monitor: SystemMonitor

    var body: some View {
        DetailPanelContent(title: Self.panelTitle) {
            DetailChart(lines: monitor.hasPower ? [ChartSeries(history: monitor.paddedPowerHistory, color: .red)] : [])
            DetailMetricSection(rows: availableDetailMetrics([
                ("Consumption", monitor.powerText),
                ("External Input", monitor.externalInputPowerText),
                ("Balance", monitor.powerBalanceText),
                ("CPU", monitor.cpuPowerText),
                ("GPU", monitor.gpuPowerText),
                ("Neural Engine", monitor.anePowerText),
                ("Low Power Mode", monitor.lowPowerModeText),
            ]))
            DetailMetricSection(title: "Battery", rows: availableDetailMetrics([
                ("Charge Power", monitor.batteryChargePowerText),
                ("Discharge Power", monitor.batteryDischargePowerText),
                ("Charge", monitor.batteryPercent),
                ("Status", monitor.batteryStatusText),
                ("Time", monitor.batteryTimeRemainingText),
                ("Voltage", monitor.batteryVoltageText),
                ("Current", monitor.batteryCurrentText),
                ("Temperature", monitor.batteryTemperatureText),
                ("Health", monitor.batteryHealthText),
                ("Cycles", monitor.batteryCyclesText),
                ("Max Capacity", monitor.batteryMaxCapacityText),
                ("Design Capacity", monitor.batteryDesignCapacityText),
            ]))
            DetailMetricSection(title: "Thermals", rows: availableDetailMetrics([
                ("CPU Temp", monitor.thermalTemperatureStatusText),
                ("GPU Temp", monitor.gpuTempText),
                ("Fans", monitor.fansSummaryText),
            ]))
            DetailListSection(
                "Top Energy Impact (score)",
                data: Array(monitor.topPowerProcesses.enumerated()),
                id: \.offset
            ) { entry in
                statRow(verbatim: entry.element.name, value: monitor.formatProcessPower(entry.element))
            }
        }
    }
}

#Preview("Live", traits: .sizeThatFitsLayout) {
    PowerDetailView(monitor: SystemMonitor(settings: AppSettings()).start())
}

#Preview("Thermal Pressure Only", traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings)
    monitor.record(thermalPressureState: .nominal)
    monitor.record(battery: BatteryUsage(
        percentage: 78,
        isCharging: false,
        isPluggedIn: false,
        timeRemaining: 165,
        cycleCount: 132,
        designCapacity: 5000,
        maxCapacity: 4630,
        health: 92.6
    ))
    monitor.record(power: PowerUsage(
        cpuMilliWatts: 12_400,
        gpuMilliWatts: 4_200,
        totalMilliWatts: 21_300
    ))
    monitor.record(fans: [
        FanUsage(id: 0, currentRPM: 2410, minRPM: 1200, maxRPM: 5000, name: "Left Fan"),
        FanUsage(id: 1, currentRPM: 2530, minRPM: 1200, maxRPM: 5000, name: "Right Fan"),
    ])

    return PowerDetailView(monitor: monitor)
}
