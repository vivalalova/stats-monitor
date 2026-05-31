import Foundation

enum DiagnosticAvailability: String, Equatable {
    case available
    case unavailable

    var title: String {
        switch self {
        case .available: "Available"
        case .unavailable: "Unavailable"
        }
    }
}

enum HardwareDiagnosticID: String, CaseIterable, Identifiable {
    case battery
    case powerTelemetry
    case thermalSensors
    case fanSensors
    case wifiLink
    case gpuFrequency
    case mediaEnginePower
    case displayMode

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .powerTelemetry: "Power Telemetry"
        case .thermalSensors: "Thermal Sensors"
        case .fanSensors: "Fan Sensors"
        case .wifiLink: "Wi-Fi Link"
        case .gpuFrequency: "GPU Frequency"
        case .mediaEnginePower: "Media Engine Power"
        case .displayMode: "Display Mode"
        }
    }
}

struct HardwareDiagnosticItem: Identifiable, Equatable {
    let id: HardwareDiagnosticID
    let title: String
    let availability: DiagnosticAvailability
    let detail: String
}

struct HardwareDiagnosticsSnapshot: Equatable {
    let items: [HardwareDiagnosticItem]

    func item(id: HardwareDiagnosticID) -> HardwareDiagnosticItem? {
        items.first { $0.id == id }
    }

    @MainActor
    static func make(monitor: SystemMonitor) -> HardwareDiagnosticsSnapshot {
        HardwareDiagnosticsSnapshot(items: [
            makeItem(
                id: .battery,
                isAvailable: monitor.hasBattery,
                detail: monitor.hasBattery ? "\(monitor.batteryPercent), \(monitor.batteryStatusText)" : "No battery telemetry sample"
            ),
            makeItem(
                id: .powerTelemetry,
                isAvailable: monitor.hasPower,
                detail: monitor.hasPower ? monitor.powerText : "No power telemetry sample"
            ),
            makeItem(
                id: .thermalSensors,
                isAvailable: monitor.hasTemperatureReadings,
                detail: monitor.hasTemperatureReadings ? monitor.thermalDashboardText : monitor.thermalTemperatureStatusText
            ),
            makeItem(
                id: .fanSensors,
                isAvailable: monitor.hasFans,
                detail: monitor.hasFans ? monitor.fansSummaryText : "No fan telemetry sample"
            ),
            makeItem(
                id: .wifiLink,
                isAvailable: monitor.hasWiFi,
                detail: wifiDetail(monitor: monitor)
            ),
            makeItem(
                id: .gpuFrequency,
                isAvailable: monitor.hasGPUFrequency,
                detail: monitor.hasGPUFrequency ? monitor.gpuFrequencyText : "No GPU frequency sample"
            ),
            makeItem(
                id: .mediaEnginePower,
                isAvailable: monitor.hasMediaEngine,
                detail: monitor.hasMediaEngine ? monitor.gpuMediaEnginePowerText : "No media engine power sample"
            ),
            makeItem(
                id: .displayMode,
                isAvailable: monitor.hasDisplayInfo,
                detail: monitor.hasDisplayInfo ? monitor.displayInfoText : "No display mode sample"
            ),
        ])
    }

    private static func makeItem(id: HardwareDiagnosticID, isAvailable: Bool, detail: String) -> HardwareDiagnosticItem {
        HardwareDiagnosticItem(
            id: id,
            title: id.title,
            availability: isAvailable ? .available : .unavailable,
            detail: detail
        )
    }

    @MainActor
    private static func wifiDetail(monitor: SystemMonitor) -> String {
        guard monitor.hasWiFi else { return "No Wi-Fi link sample" }
        return [
            monitor.wifiLinkRateText,
            monitor.wifiSignalText,
            monitor.wifiChannelText,
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }
}

struct DiagnosticReportRow: Equatable {
    let label: String
    let value: String
}

struct DiagnosticsReport: Equatable {
    let generatedAt: Date
    let appRows: [DiagnosticReportRow]
    let systemRows: [DiagnosticReportRow]
    let settingsRows: [DiagnosticReportRow]
    let hardware: HardwareDiagnosticsSnapshot
    let sampleRows: [DiagnosticReportRow]
    let currentMetricRows: [DiagnosticReportRow]
    let crashReports: CrashReportScanResult

    @MainActor
    static func make(
        aboutData: AboutView.SnapshotData,
        settings: AppSettings,
        monitor: SystemMonitor,
        generatedAt: Date = Date(),
        crashReports: CrashReportScanResult = CrashReportReader.scan()
    ) -> DiagnosticsReport {
        DiagnosticsReport(
            generatedAt: generatedAt,
            appRows: [
                DiagnosticReportRow(label: "Name", value: aboutData.appName),
                DiagnosticReportRow(label: "Version", value: "\(aboutData.appVersion) (\(aboutData.appBuild))"),
            ],
            systemRows: [
                DiagnosticReportRow(label: "Model", value: aboutData.macModel),
                DiagnosticReportRow(label: "Chip", value: aboutData.chipName),
                DiagnosticReportRow(label: "macOS", value: aboutData.osVersion),
                DiagnosticReportRow(label: "Memory", value: aboutData.totalRAM),
                DiagnosticReportRow(label: "Display", value: aboutData.display),
                DiagnosticReportRow(label: "Uptime", value: aboutData.uptime),
                DiagnosticReportRow(label: "Load Average", value: aboutData.loadAverage),
                DiagnosticReportRow(label: "Processes", value: aboutData.processCount),
            ],
            settingsRows: [
                DiagnosticReportRow(label: "Poll Interval", value: "\(Int(settings.pollInterval)) sec"),
                DiagnosticReportRow(label: "History Capacity", value: "\(settings.historyCapacity) samples"),
                DiagnosticReportRow(label: "Process Count", value: "\(settings.processCount) items"),
                DiagnosticReportRow(label: "Dashboard Columns", value: "\(settings.dashboardColumns)"),
                DiagnosticReportRow(label: "Launch at Login", value: settings.launchAtLogin ? "On" : "Off"),
                DiagnosticReportRow(label: "Menu Bar Items", value: enabledMenuBarItems(settings: settings)),
            ],
            hardware: HardwareDiagnosticsSnapshot.make(monitor: monitor),
            sampleRows: sampleRows(monitor: monitor),
            currentMetricRows: currentMetricRows(monitor: monitor),
            crashReports: crashReports
        )
    }

    func renderMarkdown() -> String {
        var lines: [String] = [
            "# StatsMonitor Diagnostics",
            "",
            "Generated: \(Self.isoString(from: generatedAt))",
            "",
        ]
        appendSection("App", rows: appRows, to: &lines)
        appendSection("System", rows: systemRows, to: &lines)
        appendSection("Settings", rows: settingsRows, to: &lines)
        appendHardwareSection(to: &lines)
        appendSection("Samples", rows: sampleRows, to: &lines)
        appendSection("Current Metrics", rows: currentMetricRows, to: &lines)
        appendCrashReports(to: &lines)
        return lines.joined(separator: "\n") + "\n"
    }

    static func suggestedFileName(generatedAt: Date = Date()) -> String {
        let stamp = fileNameString(from: generatedAt)
        return "StatsMonitor-Diagnostics-\(stamp).md"
    }

    private func appendSection(_ title: String, rows: [DiagnosticReportRow], to lines: inout [String]) {
        lines.append("## \(title)")
        for row in rows {
            lines.append("- \(row.label): \(row.value)")
        }
        lines.append("")
    }

    private func appendHardwareSection(to lines: inout [String]) {
        lines.append("## Hardware Compatibility")
        for item in hardware.items {
            lines.append("- \(item.title): \(item.availability.title) — \(item.detail)")
        }
        lines.append("")
    }

    private func appendCrashReports(to lines: inout [String]) {
        lines.append("## Recent Crash Reports")
        switch crashReports {
        case .reports(let reports):
            for report in reports {
                lines.append("- \(report.fileName): \(report.summary)")
            }
        case .noReports:
            lines.append("- No recent StatsMonitor crash reports found")
        case .missingDirectory(let path):
            lines.append("- DiagnosticReports directory missing: \(path)")
        case .failed(let message):
            lines.append("- Crash report scan failed: \(message)")
        }
        lines.append("")
    }

    @MainActor
    private static func sampleRows(monitor: SystemMonitor) -> [DiagnosticReportRow] {
        [
            DiagnosticReportRow(label: "CPU Samples", value: sampleCountText(monitor.cpuSamples.values.count, monitor.cpuSamples.capacity)),
            DiagnosticReportRow(label: "GPU Samples", value: sampleCountText(monitor.gpuSamples.values.count, monitor.gpuSamples.capacity)),
            DiagnosticReportRow(label: "Memory Samples", value: sampleCountText(monitor.memorySamples.values.count, monitor.memorySamples.capacity)),
            DiagnosticReportRow(label: "Disk Samples", value: sampleCountText(monitor.diskSamples.values.count, monitor.diskSamples.capacity)),
            DiagnosticReportRow(label: "Network Samples", value: sampleCountText(monitor.networkSamples.values.count, monitor.networkSamples.capacity)),
            DiagnosticReportRow(label: "Battery Samples", value: sampleCountText(monitor.batterySamples.values.count, monitor.batterySamples.capacity)),
            DiagnosticReportRow(label: "Thermal Samples", value: sampleCountText(monitor.thermalSamples.values.count, monitor.thermalSamples.capacity)),
            DiagnosticReportRow(label: "Power Samples", value: sampleCountText(monitor.powerSamples.values.count, monitor.powerSamples.capacity)),
            DiagnosticReportRow(label: "Fan Samples", value: sampleCountText(monitor.fansSamples.values.count, monitor.fansSamples.capacity)),
        ]
    }

    @MainActor
    private static func currentMetricRows(monitor: SystemMonitor) -> [DiagnosticReportRow] {
        [
            DiagnosticReportRow(label: "CPU", value: monitor.cpuPercent),
            DiagnosticReportRow(label: "GPU", value: monitor.gpuPercent),
            DiagnosticReportRow(label: "Memory", value: monitor.memoryPercent),
            DiagnosticReportRow(label: "Disk", value: "\(monitor.diskPercent), \(monitor.diskActivityText)"),
            DiagnosticReportRow(label: "Network", value: monitor.networkTotalText),
            DiagnosticReportRow(label: "Battery", value: monitor.hasBattery ? "\(monitor.batteryPercent), \(monitor.batteryStatusText)" : "N/A"),
            DiagnosticReportRow(label: "Thermal", value: monitor.thermalDashboardText.isEmpty ? "N/A" : monitor.thermalDashboardText),
            DiagnosticReportRow(label: "Power", value: monitor.powerText),
            DiagnosticReportRow(label: "Fans", value: monitor.fansSummaryText),
        ]
    }

    private static func sampleCountText(_ count: Int, _ capacity: Int) -> String {
        "\(count) / \(capacity)"
    }

    @MainActor
    private static func enabledMenuBarItems(settings: AppSettings) -> String {
        let items: [(String, Bool)] = [
            ("CPU", settings.showCPU),
            ("GPU", settings.showGPU),
            ("Memory", settings.showMemory),
            ("Disk", settings.showDisk),
            ("Network", settings.showNetwork),
            ("Battery", settings.showBattery),
            ("Thermal", settings.showThermal),
            ("Power", settings.showPower),
            ("Fans", settings.showFans),
        ]
        return items.filter(\.1).map(\.0).joined(separator: ", ")
    }

    private static func isoString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private static func fileNameString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: date)
    }
}

struct CrashReportSummary: Equatable {
    let fileName: String
    let modifiedAt: Date
    let exception: String
    let signal: String
    let termination: String

    var summary: String {
        [exceptionSummary, termination]
            .filter { !$0.isEmpty && $0 != "N/A" }
            .joined(separator: ", ")
    }

    private var exceptionSummary: String {
        [exception, signal]
            .filter { !$0.isEmpty && $0 != "N/A" }
            .joined(separator: " / ")
    }
}

enum CrashReportScanResult: Equatable, CustomStringConvertible {
    case reports([CrashReportSummary])
    case noReports(directory: String)
    case missingDirectory(String)
    case failed(String)

    var description: String {
        switch self {
        case .reports(let reports): "reports(\(reports.count))"
        case .noReports(let directory): "noReports(\(directory))"
        case .missingDirectory(let path): "missingDirectory(\(path))"
        case .failed(let message): "failed(\(message))"
        }
    }
}

enum CrashReportReader {
    static let defaultAppName = "StatsMonitor"

    static var defaultDiagnosticReportsDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("DiagnosticReports", isDirectory: true)
    }

    static func scan(
        appName: String = defaultAppName,
        directory: URL = defaultDiagnosticReportsDirectory,
        limit: Int = 3,
        fileManager: FileManager = .default
    ) -> CrashReportScanResult {
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return .missingDirectory(directory.path)
        }

        let reportURLs: [URL]
        do {
            reportURLs = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        } catch {
            return .failed(error.localizedDescription)
        }

        let summaries = reportURLs
            .filter { isCrashReportURL($0, appName: appName) }
            .map { parseSummary(url: $0) }
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(max(limit, 0))

        let reports = Array(summaries)
        return reports.isEmpty ? .noReports(directory: directory.path) : .reports(reports)
    }

    private static func isCrashReportURL(_ url: URL, appName: String) -> Bool {
        let fileName = url.lastPathComponent
        return fileName.hasPrefix("\(appName)-")
            && (url.pathExtension == "ips" || url.pathExtension == "crash")
    }

    private static func parseSummary(url: URL) -> CrashReportSummary {
        let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        do {
            let data = try Data(contentsOf: url)
            let metadata = parseMetadata(data: data)
            return CrashReportSummary(
                fileName: url.lastPathComponent,
                modifiedAt: modifiedAt,
                exception: metadata.exception,
                signal: metadata.signal,
                termination: metadata.termination
            )
        } catch {
            return CrashReportSummary(
                fileName: url.lastPathComponent,
                modifiedAt: modifiedAt,
                exception: "Unreadable",
                signal: "",
                termination: error.localizedDescription
            )
        }
    }

    private static func parseMetadata(data: Data) -> (exception: String, signal: String, termination: String) {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            return parseJSONMetadata(json)
        }

        let text = String(data: Data(data.prefix(64 * 1024)), encoding: .utf8) ?? ""
        return (
            firstRegexCapture(#""type"\s*:\s*"([^"]+)""#, in: text) ?? "N/A",
            firstRegexCapture(#""signal"\s*:\s*"([^"]+)""#, in: text) ?? "N/A",
            firstRegexCapture(#""termination"\s*:\s*"([^"]+)""#, in: text) ?? "N/A"
        )
    }

    private static func parseJSONMetadata(_ json: [String: Any]) -> (exception: String, signal: String, termination: String) {
        let exception = json["exception"] as? [String: Any]
        let termination = json["termination"] as? [String: Any]
        let namespace = termination?["namespace"] as? String
        let code = termination?["code"].map { "\($0)" }

        return (
            exception?["type"] as? String ?? "N/A",
            exception?["signal"] as? String ?? "N/A",
            [namespace, code].compactMap(\.self).joined(separator: " ")
        )
    }

    private static func firstRegexCapture(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard
            let match = regex.firstMatch(in: text, range: range),
            match.numberOfRanges > 1,
            let captureRange = Range(match.range(at: 1), in: text)
        else {
            return nil
        }
        return String(text[captureRange])
    }
}
