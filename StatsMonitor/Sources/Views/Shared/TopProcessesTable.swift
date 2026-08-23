import SwiftUI

struct TopProcessesTable: View {
    let settings: AppSettings
    var monitor: SystemMonitor

    enum SortColumn { case name, cpu, gpu, memory, disk, network }

    @State private var sortColumn: SortColumn
    @State private var ascending: Bool = false

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
                        colHeader("CPU%",    col: .cpu,     width: ProcessColumnWidth.cpu)
                        colHeader("GPU%",    col: .gpu,     width: ProcessColumnWidth.gpu)
                        colHeader("Memory",  col: .memory,  width: ProcessColumnWidth.memory)
                        colHeader("Disk",    col: .disk,    width: ProcessColumnWidth.disk)
                        colHeader("Network", col: .network, width: ProcessColumnWidth.network)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)

                    Divider()

                    ForEach(rows, id: \.mergeKey) { proc in
                        HStack {
                            ProcessNameCell(process: proc)
                            Spacer()
                            ProcessValueCell(
                                text: monitor.formatProcessCPU(proc.cpuPercent),
                                width: ProcessColumnWidth.cpu,
                                hasValue: proc.cpuPercent != nil,
                                barFraction: SystemMonitor.processBarFraction(
                                    proc.cpuPercent, columnMaximum: cpuMaximum
                                )
                            )
                            ProcessValueCell(
                                text: monitor.formatProcessGPU(proc.gpuPercent),
                                width: ProcessColumnWidth.gpu,
                                hasValue: proc.gpuPercent != nil
                            )
                            ProcessValueCell(
                                text: monitor.formatProcessMemory(proc.memoryBytes),
                                width: ProcessColumnWidth.memory,
                                hasValue: proc.memoryBytes != nil,
                                barFraction: SystemMonitor.processBarFraction(
                                    proc.memoryBytes.map { Double($0) }, columnMaximum: memoryMaximum
                                )
                            )
                            ProcessValueCell(
                                text: monitor.formatProcessDisk(proc.diskTotalBPS),
                                width: ProcessColumnWidth.disk,
                                hasValue: proc.diskTotalBPS != nil
                            )
                            ProcessValueCell(
                                text: monitor.formatProcessNetwork(proc.networkTotalBPS),
                                width: ProcessColumnWidth.network,
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
        .prewarmProcessIcons(rows)
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
