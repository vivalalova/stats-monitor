import SwiftUI

/// 行程列的名稱欄：app icon ＋解析後的完整名稱。
/// Top Processes 與 Top Energy Impact 兩表共用 —— icon 尺寸／間距只有這一份。
/// 行程名走 `verbatim`，不查本地化表。
struct ProcessNameCell: View {
    let process: ProcInfo

    private static let iconSize: CGFloat = 14

    var body: some View {
        HStack(spacing: 6) {
            ProcessIconCache.shared.icon(forPath: process.iconPath)
                .resizable()
                .interpolation(.high)
                .frame(width: Self.iconSize, height: Self.iconSize)
            Text(verbatim: process.name)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

extension View {
    /// 把這些列的 icon 路徑補進快取。
    /// icon 是問 LaunchServices／讀 .icns 換來的，載入排在 render pass 之外；
    /// 補進快取後 `ProcessIconCache` 是 `@Observable`，畫面自己重畫。
    @MainActor
    func prewarmProcessIcons(_ processes: [ProcInfo]) -> some View {
        let paths = processes.map { $0.iconPath ?? "" }
        return task(id: paths.joined(separator: "\n")) {
            ProcessIconCache.shared.prewarm(paths)
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 8) {
        ProcessNameCell(process: ProcInfo(pid: 1001, name: "Xcode", iconPath: "/Applications/Xcode.app"))
        ProcessNameCell(process: ProcInfo(pid: 601, name: "WindowServer"))
    }
    .padding()
}
