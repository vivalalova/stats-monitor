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
        var byName: [String: ProcInfo] = [:]
        let gpuAsProcInfo = monitor.topGPUProcesses.map { gpu in
            ProcInfo(name: gpu.name, cpuPercent: 0, memoryBytes: 0, gpuPercent: gpu.utilizationPercent)
        }
        let all = monitor.topCPUProcesses
            + monitor.topMemoryProcesses
            + monitor.topDiskProcesses
            + monitor.topNetworkProcesses
            + gpuAsProcInfo
        for proc in all {
            if let existing = byName[proc.name] {
                byName[proc.name] = ProcInfo(
                    name:          proc.name,
                    cpuPercent:    max(existing.cpuPercent,    proc.cpuPercent),
                    memoryBytes:   max(existing.memoryBytes,   proc.memoryBytes),
                    diskReadBPS:   max(existing.diskReadBPS,   proc.diskReadBPS),
                    diskWriteBPS:  max(existing.diskWriteBPS,  proc.diskWriteBPS),
                    networkInBPS:  max(existing.networkInBPS,  proc.networkInBPS),
                    networkOutBPS: max(existing.networkOutBPS, proc.networkOutBPS),
                    gpuPercent:    max(existing.gpuPercent,    proc.gpuPercent)
                )
            } else {
                byName[proc.name] = proc
            }
        }
        return Array(byName.values).sorted(using: sortColumn, ascending: ascending)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Top Processes")
                .font(.subheadline)
                .fontWeight(.semibold)

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

                ForEach(mergedProcesses, id: \.name) { proc in
                    HStack {
                        Text(proc.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(monitor.formatProcessCPU(proc.cpuPercent))
                            .frame(width: 60, alignment: .trailing)
                        Text(proc.gpuPercent > 0
                             ? monitor.formatProcessGPU(proc.gpuPercent) : "—")
                            .frame(width: 60, alignment: .trailing)
                        Text(monitor.formatProcessMemory(proc.memoryBytes))
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.diskTotalBPS > 0
                             ? monitor.formatProcessDisk(proc.diskTotalBPS) : "—")
                            .frame(width: 72, alignment: .trailing)
                        Text(proc.networkTotalBPS > 0
                             ? monitor.formatProcessNetwork(proc.networkTotalBPS) : "—")
                            .frame(width: 80, alignment: .trailing)
                    }
                    .font(.system(size: 12))
                    .monospacedDigit()
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.primary.opacity(0.02), in: RoundedRectangle(cornerRadius: 4))
                }
            }
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
            case .cpu:     primary = a.cpuPercent == b.cpuPercent ? nil : a.cpuPercent < b.cpuPercent
            case .gpu:     primary = a.gpuPercent == b.gpuPercent ? nil : a.gpuPercent < b.gpuPercent
            case .memory:  primary = a.memoryBytes == b.memoryBytes ? nil : a.memoryBytes < b.memoryBytes
            case .disk:    primary = a.diskTotalBPS == b.diskTotalBPS ? nil : a.diskTotalBPS < b.diskTotalBPS
            case .network: primary = a.networkTotalBPS == b.networkTotalBPS ? nil : a.networkTotalBPS < b.networkTotalBPS
            }
            if let primary { return ascending ? primary : !primary }
            return a.name < b.name
        }
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
