import AppKit
import Darwin

/// 結束行程時送出的 POSIX signal。
enum ProcessTerminationSignal {
    /// SIGTERM：請行程自行收尾。可被攔截，但 Cocoa app 預設沒有 handler——
    /// 收到就直接死，不會走 `applicationShouldTerminate`、來不及存檔。
    /// 所以 Quit 要先試 Apple Event（見 `ProcessTerminator.quit`），這裡只當 fallback。
    case terminate
    /// SIGKILL：核心直接終止，攔不掉也存不了檔。
    case forceKill

    var signalNumber: Int32 {
        switch self {
        case .terminate: SIGTERM
        case .forceKill: SIGKILL
        }
    }
}

enum ProcessTerminationError: Error, Equatable {
    /// pid 不在 `pid_t` 正數範圍內（列表來源沒解析出 pid，或值大到不能轉型）。
    case invalidPID(Int)
    case permissionDenied
    case noSuchProcess
    case other(errorNumber: Int32)

    /// 由 `kill(2)` 失敗後的 `errno` 分類。
    init(errorNumber: Int32) {
        switch errorNumber {
        case EPERM: self = .permissionDenied
        case ESRCH: self = .noSuchProcess
        default:    self = .other(errorNumber: errorNumber)
        }
    }

    /// 對應的系統 `errno`；`nil` ＝這個失敗不是 `kill(2)` 回報的，沒有系統描述可附。
    var errorNumber: Int32? {
        switch self {
        case .invalidPID:                  nil
        case .permissionDenied:            EPERM
        case .noSuchProcess:               ESRCH
        case .other(let errorNumber):      errorNumber
        }
    }
}

enum ProcessTerminator {
    /// pid 是否可送 signal。0 與負值在 `kill(2)` 有「整個 process group／全部行程」的特殊語意，
    /// 絕不能當成普通 pid 傳下去；超出 `pid_t` 範圍的值轉型會 trap。
    /// 自身 pid 也排除：結束 StatsMonitor 只能走選單的離開確認，不給行程表當後門。
    static func canTerminate(
        pid: Int,
        currentPID: Int = Int(ProcessInfo.processInfo.processIdentifier)
    ) -> Bool {
        pid > 0 && pid <= Int(Int32.max) && pid != currentPID
    }

    /// 溫和結束：先請 GUI app 自己 quit（Apple Event，走 `applicationShouldTerminate`、可存檔），
    /// 對不到 app（非 GUI 行程）或請求送不出去時才 fallback 送 SIGTERM。
    ///
    /// - Parameter requestAppTermination: 回 `nil` ＝沒有 LaunchServices app 掛在這個 pid（daemon／多數 helper）；`false` ＝請求沒送出去（典型是行程已不在）。注意 app 在 `applicationShouldTerminate` 拒絕時 `terminate()` 仍回 `true`，拒絕在同步呼叫上不可觀測、不會 fallback。
    @MainActor
    static func quit(
        pid: Int,
        requestAppTermination: (Int32) -> Bool? = { NSRunningApplication(processIdentifier: $0)?.terminate() },
        kill: (Int32, Int32) -> Int32 = Darwin.kill
    ) throws {
        guard canTerminate(pid: pid) else { throw ProcessTerminationError.invalidPID(pid) }
        guard requestAppTermination(Int32(pid)) != true else { return }
        try terminate(pid: pid, signal: .terminate, kill: kill)
    }

    static func terminate(
        pid: Int,
        signal: ProcessTerminationSignal,
        kill: (Int32, Int32) -> Int32 = Darwin.kill
    ) throws {
        guard canTerminate(pid: pid) else { throw ProcessTerminationError.invalidPID(pid) }
        guard kill(Int32(pid), signal.signalNumber) == -1 else { return }
        // errno 只在下一個 libc 呼叫前有效，失敗後立刻讀。
        throw ProcessTerminationError(errorNumber: Darwin.errno)
    }
}
