import AppKit
import SwiftUI

extension View {
    /// 行程列共用的右鍵選單：Quit 請 app 自己收尾，Force Quit 先跳確認再送 SIGKILL。
    /// 兩張行程表（Top Processes／Power）都套這一份，別各自實作。
    ///
    /// menu bar 詳情面板（Views/Panels/CPUDetailView／PowerDetailView）刻意未掛——
    /// 面板是 `.nonactivatingPanel`，`runModal()` 的焦點問題待 #7 處理。
    @MainActor
    func processTerminationContextMenu(for process: ProcInfo) -> some View {
        modifier(ProcessTerminationContextMenu(process: process))
    }
}

@MainActor
private struct ProcessTerminationContextMenu: ViewModifier {
    let process: ProcInfo

    func body(content: Content) -> some View {
        // 來源列表拿不到 pid（pid 0）、或這列就是 StatsMonitor 自己時，選單項留著但點不動。
        let canTerminate = ProcessTerminator.canTerminate(pid: process.pid)

        content.contextMenu {
            Button("Quit \(process.name)") { quit() }
                .disabled(!canTerminate)

            Button("Force Quit \(process.name)", role: .destructive) { confirmForceQuit() }
                .disabled(!canTerminate)
        }
    }

    private func quit() {
        perform { try ProcessTerminator.quit(pid: process.pid) }
    }

    private func confirmForceQuit() {
        let confirmation = ProcessTerminationAlertFactory.makeForceQuitConfirmation(processName: process.name)
        // App 是 LSUIElement accessory，不先搶到前景 modal 會躲在別的 app 後面。
        NSApp.activate(ignoringOtherApps: true)
        guard confirmation.runModal() == .alertFirstButtonReturn else { return }
        perform { try ProcessTerminator.terminate(pid: process.pid, signal: .forceKill) }
    }

    /// 兩條路徑共用的失敗處理：只認 `ProcessTerminationError`，其餘一律當 bug 炸掉。
    private func perform(_ body: () throws -> Void) {
        do {
            try body()
        } catch let error as ProcessTerminationError {
            let alert = ProcessTerminationAlertFactory
                .makeFailureAlert(processName: process.name, error: error)
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
        } catch {
            preconditionFailure("ProcessTerminator only throws ProcessTerminationError, got \(error)")
        }
    }
}

#Preview(traits: .sizeThatFitsLayout) {
    VStack(alignment: .leading, spacing: 8) {
        Text(verbatim: "Xcode")
            .processTerminationContextMenu(for: ProcInfo(pid: 1001, name: "Xcode"))

        Text(verbatim: "kernel_task (no pid)")
            .processTerminationContextMenu(for: ProcInfo(pid: 0, name: "kernel_task"))
    }
    .padding()
}
