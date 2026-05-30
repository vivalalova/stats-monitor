import AppKit
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

struct DetailToolbar: View {
    let title: LocalizedStringKey
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)

            Spacer()

            HStack(spacing: 8) {
                Button { openWindow(id: AppSceneID.settingsWindow) } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")

                Button { NSApp.terminate(nil) } label: {
                    Image(systemName: "power")
                }
                .help("Quit StatsMonitor")
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.secondary)
        .font(.system(size: 14))
    }
}

struct DetailPanelContent<Content: View>: View {
    private let title: LocalizedStringKey
    private let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = LocalizedStringKey(title)
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DetailToolbar(title: title)
            content
        }
    }
}

typealias DetailMetric = (label: LocalizedStringKey, value: String)

func availableDetailMetrics(_ rows: [DetailMetric]) -> [DetailMetric] {
    rows.filter { !$0.value.isEmpty && $0.value != "N/A" && $0.value != "—" }
}

struct DetailChart: View {
    let lines: [ChartSeries]
    var maxValue: Double?

    var body: some View {
        if !lines.isEmpty {
            if let maxValue {
                LineChartView(lines: lines, maxValue: maxValue)
            } else {
                LineChartView(lines: lines)
            }
        }
    }
}

struct DetailMetricSection: View {
    private let title: LocalizedStringKey?
    private let rows: [DetailMetric]

    init(title: LocalizedStringKey? = nil, rows: [DetailMetric]) {
        self.title = title
        self.rows = rows
    }

    var body: some View {
        if !rows.isEmpty {
            if let title {
                sectionHeader(title)
            }

            compactRows(Array(rows.enumerated()), id: \.offset) { row in
                statRow(row.element.label, value: row.element.value)
            }
        }
    }
}

struct DetailListSection<Data: RandomAccessCollection, ID: Hashable, Content: View>: View {
    private let title: LocalizedStringKey
    private let data: Data
    private let id: KeyPath<Data.Element, ID>
    private let row: (Data.Element) -> Content

    init(
        _ title: LocalizedStringKey,
        data: Data,
        id: KeyPath<Data.Element, ID>,
        @ViewBuilder row: @escaping (Data.Element) -> Content
    ) {
        self.title = title
        self.data = data
        self.id = id
        self.row = row
    }

    var body: some View {
        if !data.isEmpty {
            sectionHeader(title)
            compactRows(data, id: id, row: row)
        }
    }
}

func sectionHeader(_ title: LocalizedStringKey) -> some View {
    Group {
        Divider()
        Text(title)
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
}

func statRow(_ label: LocalizedStringKey, value: String) -> some View {
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

/// For dynamic non-localizable strings such as process names.
func statRow(verbatim label: String, value: String) -> some View {
    HStack {
        Text(verbatim: label)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        Spacer()
        Text(value)
            .monospacedDigit()
            .fontWeight(.medium)
    }
    .font(.system(size: 13))
}

func compactRows<Data: RandomAccessCollection, ID: Hashable, Content: View>(
    _ data: Data,
    id: KeyPath<Data.Element, ID>,
    @ViewBuilder row: @escaping (Data.Element) -> Content
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        ForEach(data, id: id, content: row)
    }
}

func progressColor(_ fraction: Double) -> Color {
    switch fraction {
    case ..<0.6:  .green
    case ..<0.8:  .orange
    default:      .red
    }
}

#Preview("BarView", traits: .sizeThatFitsLayout) {
    HStack(alignment: .bottom, spacing: 8) {
        BarView(width: 32, color: .blue,   value: 80)
        BarView(width: 32, color: .green,  value: 40)
        BarView(width: 32, color: .orange, value: 60)
        BarView(width: 32, color: .red,    value: 95)
    }
    .padding()
}
