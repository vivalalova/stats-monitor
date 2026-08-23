import AppKit
import Observation
import SwiftUI
import UniformTypeIdentifiers

/// 行程 icon 快取。icon 只有 AppKit 拿得到（`NSWorkspace`），屬 SwiftUI 的框架限制例外，
/// 也因此把 AppKit 關在這個檔案裡，View 只拿 SwiftUI `Image`。
/// 路徑解析的成本已在背景付掉（`ProcessIdentityCache`），這裡只做 path → `Image` 的記憶化，
/// 同一路徑每個 app 生命週期只問系統一次。
/// 取值（`icon(forPath:)`）是純讀，載入（`prewarm`）由 View 的 `.task` 觸發：
/// 問系統要 icon 會碰 LaunchServices／磁碟，不能在 `body` 求值期間同步做，也不該在 render pass 內改狀態。
@MainActor
@Observable
final class ProcessIconCache {
    static let shared = ProcessIconCache()

    /// 快取上限：路徑數量遠少於行程數，超過就把不在當前這批的路徑丟掉。
    private static let capacity = 256

    private var icons: [String: Image] = [:]
    @ObservationIgnored
    private lazy var genericExecutableIcon = Image(nsImage: NSWorkspace.shared.icon(for: .unixExecutable))

    /// 取得該路徑已快取的 icon；還沒載入或沒有路徑（非 app 或解析不到）時回通用執行檔 icon。
    /// 純讀不改狀態 —— 未命中的路徑靠 `prewarm(_:)` 補，補完 `@Observable` 會讓畫面自己更新。
    func icon(forPath path: String?) -> Image {
        guard let path, !path.isEmpty, let cached = icons[path] else { return genericExecutableIcon }
        return cached
    }

    /// 把還沒載入的路徑補進快取。在 render pass 外呼叫（View 的 `.task`）。
    /// 容量滿時只淘汰不在本批的路徑 —— 整批丟掉會連本批稍早載入的一起抹掉，
    /// 而 `.task(id:)` 對同一份路徑清單不會再觸發，那些列的 icon 就再也補不回來。
    func prewarm(_ paths: [String?]) {
        let wanted = Set(paths.compactMap { $0 }.filter { !$0.isEmpty })
        let missing = wanted.subtracting(icons.keys)
        guard !missing.isEmpty else { return }

        if icons.count + missing.count > Self.capacity {
            icons = icons.filter { wanted.contains($0.key) }
        }
        for path in missing {
            icons[path] = Image(nsImage: NSWorkspace.shared.icon(forFile: path))
        }
    }
}
