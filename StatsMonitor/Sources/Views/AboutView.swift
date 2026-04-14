import AppKit
import Darwin
import SwiftUI

// MARK: - AboutView

struct AboutView: View {
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
                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Version \(appVersion) (\(appBuild))")
                    .foregroundStyle(.secondary)
                Text(copyright)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - System info

    private var systemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("系統資訊")
                .font(.headline)

            VStack(spacing: 0) {
                statRow("Mac 型號", value: macModel)
                statRow("晶片", value: chipName)
                statRow("macOS", value: osVersion)
                statRow("記憶體", value: totalRAM)
                statRow("已開機", value: uptime)
            }
        }
    }

    // MARK: - App bundle values

    private var appName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "StatsMonitor"
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    private var copyright: String {
        Bundle.main.infoDictionary?["NSHumanReadableCopyright"] as? String
            ?? "© \(Calendar.current.component(.year, from: Date())) Lova Shih"
    }

    // MARK: - System values

    private var macModel: String {
        sysctlString("hw.model") ?? "—"
    }

    private var chipName: String {
        sysctlString("machdep.cpu.brand_string") ?? "—"
    }

    private var osVersion: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private var totalRAM: String {
        let bytes = ProcessInfo.processInfo.physicalMemory
        let gb = Double(bytes) / 1_073_741_824
        return String(format: "%.0f GB", gb.rounded())
    }

    private var uptime: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: ProcessInfo.processInfo.systemUptime) ?? "—"
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
