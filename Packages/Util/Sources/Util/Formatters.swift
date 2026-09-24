import Foundation

/// Compares as `%.0f` will round (half-to-even), so 1023.6 MB promotes to GB instead of printing "1024 MB".
private func roundsBelow(_ value: Double, _ limit: Double) -> Bool {
    value.rounded(.toNearestOrEven) < limit
}

// MARK: - Frequency

public func ghzString(_ hz: UInt64) -> String {
    let mhz = Double(hz) / 1_000_000
    guard !roundsBelow(mhz, 1_000) else { return String(format: "%.0fM", mhz) }
    return String(format: "%.1fG", mhz / 1_000)
}

// MARK: - Byte sizes

public func formatBytes(_ bytes: UInt64) -> String {
    if bytes == 0 { return "0 B" }
    let kb = Double(bytes) / 1_024
    if roundsBelow(kb, 1_024) { return String(format: "%.0f KB", kb) }
    let mb = kb / 1_024
    if roundsBelow(mb, 1_024) { return String(format: "%.0f MB", mb) }
    return String(format: "%.1f GB", mb / 1_024)
}

public func formatBytesCompact(_ bytes: UInt64) -> String {
    let mb = Double(bytes) / 1_048_576
    if roundsBelow(mb, 1_024) { return String(format: "%.0fM", mb) }
    return String(format: "%.1fG", mb / 1_024)
}

// MARK: - Throughput

public func formatThroughput(_ bytesPerSec: Double) -> String {
    let kb = bytesPerSec / 1_024
    if roundsBelow(kb, 1_024) { return String(format: "%.0f KB/s", kb) }
    return String(format: "%.1f MB/s", kb / 1_024)
}

// MARK: - Empty state

/// 無資料的統一呈現（em dash U+2014）。「無資料」與「真的是 0」要分得開：
/// 取不到值一律用這個字串，取得到的值（含 0）一律顯示數值。
public let noDataText = "—"
