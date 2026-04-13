import Foundation
import Observation

@Observable
@MainActor
final class SystemMonitor {
    private(set) var stats = SystemStats()

    private(set) var cpuHistory:        [Double] = []
    private(set) var gpuHistory:        [Double] = []
    private(set) var memoryHistory:     [Double] = []
    private(set) var diskHistory:       [Double] = []
    private(set) var networkInHistory:  [Double] = []
    private(set) var networkOutHistory: [Double] = []

    private static let historyCapacity = 60

    private var cpuMonitor      = CPUMonitor()
    private var gpuMonitor      = GPUMonitor()
    private var memoryMonitor   = MemoryMonitor()
    private var diskMonitor     = DiskMonitor()
    private var networkMonitor  = NetworkMonitor()
    private var processMonitor  = ProcessMonitor()

    private var timer: Timer?

    static let pollInterval: TimeInterval = 2

    func start() {
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: Self.pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.poll()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let cpu     = cpuMonitor.sample()
        let gpu     = gpuMonitor.sample()
        let memory  = memoryMonitor.sample()
        let disk    = diskMonitor.sample()
        let network = networkMonitor.sample()
        let (cpuProcs, memProcs) = processMonitor.sample()

        stats = SystemStats(
            cpu:                cpu,
            gpu:                gpu,
            memory:             memory,
            disk:               disk,
            network:            network,
            topCPUProcesses:    cpuProcs,
            topMemoryProcesses: memProcs
        )

        append(cpu.used,                  to: &cpuHistory)
        append(gpu.used,                  to: &gpuHistory)
        append(memory.usedFraction * 100, to: &memoryHistory)
        append(disk.usedFraction * 100,   to: &diskHistory)
        append(network.bytesInPerSec,     to: &networkInHistory)
        append(network.bytesOutPerSec,    to: &networkOutHistory)
    }

    private func append(_ value: Double, to buffer: inout [Double]) {
        buffer.append(value)
        if buffer.count > Self.historyCapacity { buffer.removeFirst() }
    }
}
