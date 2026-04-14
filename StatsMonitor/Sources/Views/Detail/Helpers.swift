import SwiftUI

// MARK: - Bar primitives

enum BarMetrics {
    // frame width 280 – padding 16*2 = 248
    static let contentWidth: CGFloat = 248
    static let spacing: CGFloat      = 4
    static let height: CGFloat       = 48
}

struct BarView: View {
    let width: CGFloat
    let color: Color
    let value: Double  // 0...100

    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.primary.opacity(0.08))
                .frame(width: width, height: BarMetrics.height)
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: width, height: max(2, BarMetrics.height * value / 100))
        }
    }
}

// MARK: - View helpers

@MainActor
func detailToolbar(_ title: String) -> some View {
    HStack(spacing: 8) {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
        Spacer()
        Button { openSettings() } label: {
            Image(systemName: "gearshape")
        }
        .help("Settings")
        Button { NSApplication.shared.terminate(nil) } label: {
            Image(systemName: "power")
        }
        .help("Quit StatsMonitor")
    }
    .buttonStyle(.plain)
    .foregroundStyle(.secondary)
    .font(.system(size: 14))
}

func sectionHeader(_ title: String) -> some View {
    Group {
        Divider()
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

func statRow(_ label: String, value: String) -> some View {
    HStack {
        Text(label)
            .foregroundStyle(.secondary)
        Spacer()
        Text(value)
            .monospacedDigit()
            .fontWeight(.medium)
    }
    .font(.system(size: 13))
}

func progressColor(_ fraction: Double) -> Color {
    switch fraction {
    case ..<0.6:  .green
    case ..<0.8:  .orange
    default:      .red
    }
}
