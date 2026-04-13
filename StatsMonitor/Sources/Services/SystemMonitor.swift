import Foundation
import Observation

@Observable
@MainActor
final class SystemMonitor {
    private(set) var stats = SystemStats()

    private var cpuMonitor     = CPUMonitor()
    private var gpuMonitor     = GPUMonitor()
    private var memoryMonitor  = MemoryMonitor()
    private var diskMonitor    = DiskMonitor()
    private var networkMonitor = NetworkMonitor()

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
        stats = SystemStats(
            cpu:     cpuMonitor.sample(),
            gpu:     gpuMonitor.sample(),
            memory:  memoryMonitor.sample(),
            disk:    diskMonitor.sample(),
            network: networkMonitor.sample()
        )
    }
}
