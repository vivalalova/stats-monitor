import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DiagnosticsView: View {
    let settings: AppSettings
    let monitor: SystemMonitor
    let aboutData: AboutView.SnapshotData

    @State private var crashReports: CrashReportScanResult
    @State private var exportStatusText: String?

    init(
        settings: AppSettings,
        monitor: SystemMonitor,
        aboutData: AboutView.SnapshotData = .live
    ) {
        self.settings = settings
        self.monitor = monitor
        self.aboutData = aboutData
        _crashReports = State(initialValue: CrashReportReader.scan())
    }

    private var report: DiagnosticsReport {
        DiagnosticsReport.make(
            aboutData: aboutData,
            settings: settings,
            monitor: monitor,
            crashReports: crashReports
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                diagnosticsSection("Hardware Compatibility") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(report.hardware.items) { item in
                            hardwareRow(item)
                        }
                    }
                }
                diagnosticsSection("Samples") {
                    reportGrid(report.sampleRows)
                }
                diagnosticsSection("Current Metrics") {
                    reportGrid(report.currentMetricRows)
                }
                diagnosticsSection("Recent Crash Reports") {
                    crashReportRows(report.crashReports)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Diagnostics")
                    .font(.title2)
                    .fontWeight(.semibold)
                if let exportStatusText {
                    Text(exportStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                exportDiagnostics()
            } label: {
                Label("Export Diagnostics", systemImage: "square.and.arrow.down")
            }
        }
    }

    private func diagnosticsSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
            Divider()
        }
    }

    private func hardwareRow(_ item: HardwareDiagnosticItem) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: item.availability == .available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(statusColor(for: item.availability))
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(item.title))
                    .fontWeight(.medium)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(LocalizedStringKey(item.availability.title))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(statusColor(for: item.availability))
        }
        .font(.system(size: 13))
    }

    private func reportGrid(_ rows: [DiagnosticReportRow]) -> some View {
        Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 4) {
            ForEach(rows, id: \.label) { row in
                GridRow {
                    Text(LocalizedStringKey(row.label))
                        .foregroundStyle(.secondary)
                    Text(row.value)
                        .monospacedDigit()
                        .fontWeight(.medium)
                }
                .font(.system(size: 13))
            }
        }
    }

    @ViewBuilder
    private func crashReportRows(_ result: CrashReportScanResult) -> some View {
        switch result {
        case .reports(let reports):
            VStack(alignment: .leading, spacing: 4) {
                ForEach(reports, id: \.fileName) { report in
                    statRow(verbatim: report.fileName, value: report.summary)
                }
            }
        case .noReports:
            Text("No recent StatsMonitor crash reports found")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        case .missingDirectory(let path):
            statRow("DiagnosticReports", value: path)
        case .failed(let message):
            statRow("Scan Failed", value: message)
        }
    }

    private func statusColor(for availability: DiagnosticAvailability) -> Color {
        switch availability {
        case .available: .green
        case .unavailable: .secondary
        }
    }

    private func exportDiagnostics() {
        let generatedAt = Date()
        let latestCrashReports = CrashReportReader.scan()
        let report = DiagnosticsReport.make(
            aboutData: aboutData,
            settings: settings,
            monitor: monitor,
            generatedAt: generatedAt,
            crashReports: latestCrashReports
        )
        let savePanel = NSSavePanel()
        savePanel.title = String(localized: "Export Diagnostics")
        savePanel.nameFieldStringValue = DiagnosticsReport.suggestedFileName(generatedAt: generatedAt)
        savePanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText]
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

        do {
            try report.renderMarkdown().write(to: url, atomically: true, encoding: .utf8)
            crashReports = latestCrashReports
            exportStatusText = String(localized: "Exported \(url.lastPathComponent)")
        } catch {
            exportStatusText = String(localized: "Export failed: \(error.localizedDescription)")
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    DiagnosticsView(settings: settings, monitor: monitor)
        .frame(width: 820, height: 520)
}
