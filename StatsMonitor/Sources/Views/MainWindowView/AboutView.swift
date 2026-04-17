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

        static let live = SnapshotData(
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
            }()
        )
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
        VStack(alignment: .leading, spacing: 10) {
            Text("System Information")
                .font(.headline)

            VStack(spacing: 0) {
                statRow("Model", value: data.macModel)
                statRow("Chip", value: data.chipName)
                statRow("macOS", value: data.osVersion)
                statRow("Memory", value: data.totalRAM)
                statRow("Uptime", value: data.uptime)
            }
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
