import AppKit
import Darwin
import SwiftUI

// MARK: - AboutView

struct AboutView: View {
    struct SnapshotData {
        let appName: String
        let appVersion: String
        let appBuild: String
        let copyright: String
        let macModel: String
        let chipName: String
        let osVersion: String
        let totalRAM: String
        let uptime: String
        let loadAverage: String
        let processCount: String
        let display: String

        static let live: SnapshotData = {
            let load = SystemLoadMonitor.readLoadAverage()
            let processCount = SystemLoadMonitor.readProcessCount()
            let display = DisplayInfoMonitor().sample()
            return SnapshotData(
                appName: Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
                    ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
                    ?? "StatsMonitor",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—",
                appBuild: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—",
                copyright: Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
                    ?? "© \(Calendar.current.component(.year, from: Date())) Lova Shih",
                macModel: sysctlString("hw.model") ?? "—",
                chipName: sysctlString("machdep.cpu.brand_string") ?? "—",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                totalRAM: {
                    let bytes = ProcessInfo.processInfo.physicalMemory
                    let gb = Double(bytes) / 1_073_741_824
                    return String(format: "%.0f GB", gb.rounded())
                }(),
                uptime: {
                    let formatter = DateComponentsFormatter()
                    formatter.allowedUnits = [.day, .hour, .minute]
                    formatter.unitsStyle = .abbreviated
                    formatter.zeroFormattingBehavior = .dropAll
                    return formatter.string(from: ProcessInfo.processInfo.systemUptime) ?? "—"
                }(),
                loadAverage: String(format: "%.2f, %.2f, %.2f", load.one, load.five, load.fifteen),
                processCount: processCount > 0 ? "\(processCount)" : "—",
                display: display.text
            )
        }()
    }

    private let data: SnapshotData

    init(data: SnapshotData = .live) {
        self.data = data
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                appSection
                Divider()
                systemSection
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - App info

    private var appSection: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text(data.appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Version \(data.appVersion) (\(data.appBuild))")
                    .foregroundStyle(.secondary)
                Text(data.copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - System info

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("System Information")
                .font(.headline)

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 24, verticalSpacing: 4) {
                infoGroup("Hardware", rows: [
                    ("Model", data.macModel),
                    ("Chip", data.chipName),
                    ("Memory", data.totalRAM),
                    ("Display", data.display),
                ], isFirst: true)
                infoGroup("Software", rows: [
                    ("macOS", data.osVersion),
                    ("Uptime", data.uptime),
                ], isFirst: false)
                infoGroup("Runtime", rows: [
                    ("Load Average", data.loadAverage),
                    ("Processes", data.processCount),
                ], isFirst: false)
            }
        }
    }

    @ViewBuilder
    private func infoGroup(
        _ title: LocalizedStringKey,
        rows: [(LocalizedStringKey, String)],
        isFirst: Bool
    ) -> some View {
        GridRow {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .gridCellColumns(2)
                .padding(.top, isFirst ? 0 : 12)
        }

        ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
            GridRow {
                Text(row.0)
                    .foregroundStyle(.secondary)
                Text(row.1)
                    .monospacedDigit()
                    .fontWeight(.medium)
            }
            .font(.system(size: 13))
        }
    }
}

// MARK: - sysctlbyname helper

private func sysctlString(_ name: String) -> String? {
    var size = 0
    guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 0 else { return nil }
    var buf = [CChar](repeating: 0, count: size)
    guard sysctlbyname(name, &buf, &size, nil, 0) == 0 else { return nil }
    return String(cString: buf)
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    AboutView()
        .frame(width: 480, height: 320)
}
