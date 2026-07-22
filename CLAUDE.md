# StatsMonitor

macOS menu bar app — SwiftUI + Tuist。

## 技術棧

- macOS 26.0+（Tahoe），menu bar only（`LSUIElement = true`）
- UI 語言：Liquid Glass — sidebar / metric card / detail popover 以 `.glassEffect(.regular, in:)` 呈現，sidebar 列以 `GlassEffectContainer` + `.glassEffect(_:interactive())` 產生選取 morph
- UI：SwiftUI，`MenuBarExtra` 用 `.window` style（非 `.menu`）
- 專案：Tuist（Buildable Folder — 新增檔不需 `tuist generate`）
- Concurrency：Swift Strict Concurrency complete
- 語系：developmentRegion `en`、`Localizable.xcstrings` 管 zh-Hant

## 指令

```bash
tuist install         # SPM 依賴
tuist generate        # 產 Xcode 專案
tuist build
tuist test StatsMonitor --no-selective-testing
fastlane mac install  # Release → /Applications → 啟動
```

## 架構決策（Claude 猜不到）

- `SystemMonitor` 是 single `@Observable` store：集中持有所有 raw sample `MetricHistory`，目前值由 `history.last` 推導 — 不要另存 current 欄位
- 各 `Monitor` 不自己存狀態，只 `sample()` 回傳值，由 `SystemMonitor` 以 typed `record(...)` 寫入 history
- History 容量由 `AppSettings.historyCapacity` 決定，`MetricHistory` 包 `RingBuffer`
- 熱門行程（CPU/Memory/Disk/Network/Power）在 `SystemMonitor` 內用 `Task.detached(priority: .utility)` 收集，避免阻塞 main actor
- Formatting 集中在 `SystemMonitor+Formatting.swift`（`*Text`、`padded*History`、status color 判斷） — View 禁自算
- 硬體不支援時 monitor 回 `nil` / 空陣列，UI 依此 graceful 隱藏（桌機無 Battery、Intel Mac 無 Power、無風扇機型無 Fans、不支援 SMC 溫度無 Thermal）
- `PowerMonitor` 首次 sample 回 `nil`（需兩次算 delta）
- `ThermalMonitor` 與 `FanMonitor` 共用 `SMCClient` 單一連線

## UI 規範

- SwiftUI 優先，禁 AppKit（框架限制例外）、禁 Storyboard/XIB
- 狀態用 `@Observable`，非 `ObservableObject`
- 間距 8pt 倍數
- 所有 `View` 附 `#Preview(traits: .sizeThatFitsLayout)`
- 使用者看得到的畫面（window / panel / popover / alert / sheet / empty / error state）都要有 snapshot 測試

## 本地化陷阱

- UI 字串用英文 `LocalizedStringKey` 字面量；共用 helper 參數型別是 `LocalizedStringKey`
- Process name 用 `statRow(verbatim: proc.name, ...)` — 避免誤查本地化表
- `SystemMonitor+Formatting` 的狀態字串（"Charging"/"N/A"/"No fans" 及單位 "RPM"/"W"/"mW"/"cycles"）是硬編碼英文，不在 xcstrings — 新增這類 text 要評估是否補翻譯

## 測試

- 框架：Swift Testing（`@Suite`、`@Test`、`#expect`）
- Snapshot reference：`Tests/Sources/__Snapshots__/StatsMonitorSnapshotTests/` — 看目前 UI 優先看這裡
- 重錄 snapshot：明確跑 `TEST_RUNNER_RECORD_SNAPSHOTS=1 tuist test StatsMonitor --no-selective-testing`（xcodebuild 只把 `TEST_RUNNER_` 前綴的 env 轉進測試進程，裸 `RECORD_SNAPSHOTS=1` 無效）；record mode 是 `.all`，會重寫全部 reference，只想更新部分時錄完把其餘 png `git checkout` 還原

## Packages/Util

跨 Feature 共用的純邏輯工具（Formatter、RingBuffer）。不收 UI、Feature 專屬邏輯、第三方封裝。引用：`import Util`。
