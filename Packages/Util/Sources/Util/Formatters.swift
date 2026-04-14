import Foundation

// MARK: - Frequency

public func ghzString(_ hz: UInt64) -> String {
    let ghz = Double(hz) / 1_000_000_000
    return ghz >= 1 ? String(format: "%.1fG", ghz)
                    : String(format: "%.0fM", Double(hz) / 1_000_000)
}

// MARK: - Byte sizes

public func formatBytes(_ bytes: UInt64) -> String {
    if bytes == 0 { return "0 B" }
    let gb = Double(bytes) / 1_073_741_824
    if gb >= 1 { return String(format: "%.1f GB", gb) }
    let mb = Double(bytes) / 1_048_576
    if mb >= 1 { return String(format: "%.0f MB", mb) }
    return String(format: "%.0f KB", Double(bytes) / 1_024)
}

public func formatBytesCompact(_ bytes: UInt64) -> String {
    let gb = Double(bytes) / 1_073_741_824
    if gb >= 1 { return String(format: "%.1fG", gb) }
    let mb = Double(bytes) / 1_048_576
    return String(format: "%.0fM", mb)
}

// MARK: - Throughput

public func formatThroughput(_ bytesPerSec: Double) -> String {
    let mb = bytesPerSec / 1_048_576
    if mb >= 1 { return String(format: "%.1f MB/s", mb) }
    let kb = bytesPerSec / 1_024
    return String(format: "%.0f KB/s", kb)
}
