import SwiftUI

struct TopProcessesTable: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    enum SortColumn { case name, cpu, gpu, memory, disk, network }

    @State private var sortColumn: SortColumn
    @State private var ascending: Bool = false

    /// 比例條寬度上限對齊欄寬；顏色淡到不搶數字。
    private static let barOpacity: Double = 0.18
    private static let iconSize: CGFloat = 14

    init(
        settings: AppSettings,
        monitor: SystemMonitor,
        initialSort: SortColumn
    ) {
        self.settings = settings
        self.monitor = monitor
        _sortColumn = State(initialValue: initialSort)
    }

    private var mergedProcesses: [ProcInfo] {
        SystemMonitor.mergeTopProcesses(
            cpu: monitor.topCPUProcesses,
            memory: monitor.topMemoryProcesses,
            disk: monitor.topDiskProcesses,
            network: monitor.topNetworkProcesses,
            gpu: monitor.topGPUProcesses
        )
        .sorted(using: sortColumn, ascending: ascending)
    }

    private func toggleSort(_ col: SortColumn) {
        if sortColumn == col { ascending.toggle() } else { sortColumn = col; ascending = false }
    }

    @ViewBuilder
    private func colHeader(_ label: LocalizedStringKey, col: SortColumn, width: CGFloat) -> some View {
        Button { toggleSort(col) } label: {
            HStack(spacing: 2) {
                Spacer(minLength: 0)
                Text(label)
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .imageScale(.small)
                    .opacity(sortColumn == col ? 1 : 0)
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .trailing)
    }

    /// 名稱欄：app icon ＋解析後的完整名稱（行程名走 verbatim，不查本地化表）。
    @ViewBuilder
    private func nameCell(_ proc: ProcInfo) -> some View {
        HStack(spacing: 6) {
            ProcessIconCache.shared.icon(forPath: proc.iconPath)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)
            Text(verbatim: proc.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    /// 數值欄：右對齊數字；`barFraction > 0` 時墊一條與該欄最大值成比例的淡色底條。
    /// 無資料（formatter 回破折號）以 tertiary 淡化，跟真的是 0 的列一眼分得開。
    @ViewBuilder
    private func valueCell(
        _ text: String,
        width: CGFloat,
        hasValue: Bool,
        barFraction: Double = 0
    ) -> some View {
        Text(verbatim: text)
            .foregroundStyle(hasValue ? AnyShapeStyle(HierarchicalShapeStyle.primary)
                                     : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
            .frame(width: width, alignment: .trailing)
            .background(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.accentColor.opacity(Self.barOpacity))
                    .frame(width: width * barFraction)
            }
    }

    var body: some View {
        let rows = mergedProcesses
        let cpuMaximum = SystemMonitor.processColumnMaximum(rows.map(\.cpuPercent))
        let memoryMaximum = SystemMonitor.processColumnMaximum(rows.map { $0.memoryBytes.map { Double($0) } })

        return VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.subheadline)
                .fontWeight(.semibold)

            GlassEffectContainer(spacing: 2) {
                VStack(spacing: 0) {
                    HStack {
                        Button { toggleSort(.name) } label: {
                            HStack(spacing: 2) {
                                Text("Name")
                                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                                    .imageScale(.small)
                                    .opacity(sortColumn == .name ? 1 : 0)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        colHeader("CPU%",    col: .cpu,     width: 60)
                        colHeader("GPU%",    col: .gpu,     width: 60)
                        colHeader("Memory",  col: .memory,  width: 72)
                        colHeader("Disk",    col: .disk,    width: 72)
                        colHeader("Network", col: .network, width: 80)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)

                    Divider()

                    ForEach(rows, id: \.mergeKey) { proc in
                        HStack {
                            nameCell(proc)
                            Spacer()
                            valueCell(
                                monitor.formatProcessCPU(proc.cpuPercent),
                                width: 60,
                                hasValue: proc.cpuPercent != nil,
                                barFraction: SystemMonitor.processBarFraction(
                                    proc.cpuPercent, columnMaximum: cpuMaximum
                                )
                            )
                            valueCell(
                                monitor.formatProcessGPU(proc.gpuPercent),
                                width: 60,
                                hasValue: proc.gpuPercent != nil
                            )
                            valueCell(
                                monitor.formatProcessMemory(proc.memoryBytes),
                                width: 72,
                                hasValue: proc.memoryBytes != nil,
                                barFraction: SystemMonitor.processBarFraction(
                                    proc.memoryBytes.map { Double($0) }, columnMaximum: memoryMaximum
                                )
                            )
                            valueCell(
                                monitor.formatProcessDisk(proc.diskTotalBPS),
                                width: 72,
                                hasValue: proc.diskTotalBPS != nil
                            )
                            valueCell(
                                monitor.formatProcessNetwork(proc.networkTotalBPS),
                                width: 80,
                                hasValue: proc.networkTotalBPS != nil
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
        // icon 是問 LaunchServices／讀 .icns 換來的，載入排在 render pass 之外；
        // 補進快取後 `ProcessIconCache` 是 `@Observable`，畫面自己重畫。
        .task(id: rows.map { $0.iconPath ?? "" }.joined(separator: "\n")) {
            ProcessIconCache.shared.prewarm(rows.map(\.iconPath))
        }
    }
}

// MARK: - ProcInfo sort helper

fileprivate extension Array where Element == ProcInfo {
    func sorted(using col: TopProcessesTable.SortColumn, ascending: Bool) -> [ProcInfo] {
        sorted { a, b in
            let primary: Bool?
            switch col {
            case .name:    primary = a.name == b.name ? nil : a.name < b.name
            case .cpu:     primary = compare(a.cpuPercent, b.cpuPercent)
            case .gpu:     primary = compare(a.gpuPercent, b.gpuPercent)
            case .memory:  primary = compare(a.memoryBytes, b.memoryBytes)
            case .disk:    primary = compare(a.diskTotalBPS, b.diskTotalBPS)
            case .network: primary = compare(a.networkTotalBPS, b.networkTotalBPS)
            }
            if let primary { return ascending ? primary : !primary }
            return a.name < b.name
        }
    }

    /// 無資料視同最小值排在最後（降冪時）；兩邊相等回 nil 交給名稱決勝，維持既有規則。
    private func compare<Value: Comparable & ExpressibleByIntegerLiteral>(_ a: Value?, _ b: Value?) -> Bool? {
        let lhs = a ?? 0
        let rhs = b ?? 0
        return lhs == rhs ? nil : lhs < rhs
    }
}

// MARK: - Preview

#Preview(traits: .sizeThatFitsLayout) {
    let settings = AppSettings()
    let monitor = SystemMonitor(settings: settings).start()
    TopProcessesTable(settings: settings, monitor: monitor, initialSort: .cpu)
        .frame(width: 600)
        .padding()
}
