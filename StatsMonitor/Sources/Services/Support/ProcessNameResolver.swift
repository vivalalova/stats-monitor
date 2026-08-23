import Darwin
import Foundation

/// 行程顯示名稱解析。純函式部分（fallback 鏈、`.app` 祖先）可單測，
/// 需要問 kernel／檔案系統的部分獨立成另外的 static func。
enum ProcessNameResolver {

    /// 名稱 fallback 鏈：bundle display name → 執行檔檔名 → kernel `p_comm`（`MAXCOMLEN` 16 字元硬截）。
    static func displayName(
        bundleDisplayName: String?,
        executableFileName: String?,
        commName: String
    ) -> String {
        if let bundleDisplayName, !bundleDisplayName.isEmpty { return bundleDisplayName }
        if let executableFileName, !executableFileName.isEmpty { return executableFileName }
        return commName
    }

    /// 由執行檔路徑往上找最近的 `.app` 祖先（Chrome Helper 這類巢狀 bundle 要的是最近的那個）。
    /// 非 app 行程（`/usr/bin/zsh`）回 nil。
    static func appBundlePath(forExecutablePath path: String) -> String? {
        var components = path.split(separator: "/", omittingEmptySubsequences: false).map(String.init)
        while components.count > 1 {
            if let last = components.last, last.hasSuffix(".app") {
                return components.joined(separator: "/")
            }
            components.removeLast()
        }
        return nil
    }

    /// 執行檔路徑的檔名部分；路徑為空或以 `/` 結尾時回 nil。
    static func executableFileName(fromPath path: String) -> String? {
        guard let last = path.split(separator: "/").last else { return nil }
        return String(last)
    }

    /// `proc_pidpath` 取執行檔完整路徑；行程已結束或無權限時回 nil。
    static func executablePath(forPID pid: Int) -> String? {
        // `PROC_PIDPATHINFO_MAXSIZE` 是 C macro（`4 * MAXPATHLEN`），不進 Swift，只能展開。
        var buffer = [CChar](repeating: 0, count: 4 * Int(MAXPATHLEN))
        let length = proc_pidpath(Int32(pid), &buffer, UInt32(buffer.count))
        guard length > 0 else { return nil }
        return String(cString: buffer)
    }

    /// 讀 bundle 的 `CFBundleDisplayName` / `CFBundleName`；不是 bundle 或兩個 key 都沒有時回 nil。
    static func bundleDisplayName(forBundlePath path: String) -> String? {
        guard let bundle = Bundle(path: path) else { return nil }
        let info = bundle.localizedInfoDictionary ?? bundle.infoDictionary
        for key in ["CFBundleDisplayName", "CFBundleName"] {
            if let value = info?[key] as? String, !value.isEmpty { return value }
        }
        return nil
    }
}

/// 行程的顯示身分：解析過的名稱＋icon 來源路徑。
struct ProcessIdentity: Sendable {
    var displayName: String
    var iconPath: String?
}

/// pid → 顯示身分的快取。解析成本（`proc_pidpath`、bundle Info.plist）只在背景 sample 時付一次，
/// main actor 不碰；pid 被回收給別的行程時以行程名（前 15 字元，見 `commNameCompareLength`）比對失效重解。
final class ProcessIdentityCache: @unchecked Sendable {
    static let shared = ProcessIdentityCache()

    /// 快取上限：超過就整批丟掉重建。行程來來去去，留著死 pid 只是佔記憶體。
    private static let capacity = 512

    private struct CacheEntry {
        var commName: String
        var identity: ProcessIdentity
    }

    private let lock = NSLock()
    private var entries: [Int: CacheEntry] = [:]

    /// 把 top list 的 `name`（p_comm／nettop key）換成解析後的顯示名稱並補上 icon 路徑。
    /// 只在 `Task.detached(priority: .utility)` 內呼叫。
    func resolved(_ processes: [ProcInfo]) -> [ProcInfo] {
        processes.map { process in
            guard process.pid > 0 else { return process }
            var process = process
            let identity = identity(pid: process.pid, commName: process.name)
            process.name = identity.displayName
            process.iconPath = identity.iconPath
            return process
        }
    }

    /// 比對用的名稱長度：nettop 的 key 名稱截到 15 字元、kernel `p_comm` 截到 16 字元，
    /// 同一個行程從兩份 list 進來會是長短不同的兩個字串。取共同的前 15 字元比對，
    /// 否則長名行程（Chrome Helper 之類）每拍都會判定成 pid 被回收而重解析，快取形同無效。
    private static let commNameCompareLength = 15

    private static func sameProcess(_ lhs: String, _ rhs: String) -> Bool {
        lhs.prefix(commNameCompareLength) == rhs.prefix(commNameCompareLength)
    }

    func identity(pid: Int, commName: String) -> ProcessIdentity {
        lock.lock()
        let cached = entries[pid]
        lock.unlock()
        if let cached, Self.sameProcess(cached.commName, commName) { return cached.identity }

        // 解析放在鎖外：syscall 與讀 Info.plist 不該擋住其他 pid 的查詢。
        let identity = Self.resolve(pid: pid, commName: commName)

        lock.lock()
        if entries.count >= Self.capacity { entries.removeAll(keepingCapacity: true) }
        entries[pid] = CacheEntry(commName: commName, identity: identity)
        lock.unlock()
        return identity
    }

    private static func resolve(pid: Int, commName: String) -> ProcessIdentity {
        guard let executablePath = ProcessNameResolver.executablePath(forPID: pid) else {
            return ProcessIdentity(displayName: commName, iconPath: nil)
        }
        let bundlePath = ProcessNameResolver.appBundlePath(forExecutablePath: executablePath)
        let displayName = ProcessNameResolver.displayName(
            bundleDisplayName: bundlePath.flatMap(ProcessNameResolver.bundleDisplayName(forBundlePath:)),
            executableFileName: ProcessNameResolver.executableFileName(fromPath: executablePath),
            commName: commName
        )
        return ProcessIdentity(displayName: displayName, iconPath: bundlePath ?? executablePath)
    }
}
