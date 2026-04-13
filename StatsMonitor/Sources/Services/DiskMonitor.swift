import Foundation

struct DiskMonitor {
    func sample() -> DiskUsage {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: "/"),
              let total = attrs[.systemSize] as? UInt64,
              let free = attrs[.systemFreeSize] as? UInt64
        else {
            return .zero
        }
        return DiskUsage(used: total - free, total: total)
    }
}
