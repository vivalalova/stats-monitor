# StatsMonitor

macOS menu bar app — SwiftUI + Tuist

## 技術棧

- **平台**: macOS 15.0+（menu bar only，LSUIElement）
- **UI**: SwiftUI（MenuBarExtra + `.window` style）
- **專案管理**: Tuist（Buildable Folder 結構）
- **架構**: MVVM（@Observable）
- **Concurrency**: Swift Strict Concurrency complete
- **語系**: zh-Hant（主）、en

## 指令

```bash
tuist install       # 安裝 SPM 依賴
tuist generate      # 生成 Xcode 專案
tuist build         # 建置
tuist test          # 測試
tuist clean         # 清理
```

## 專案結構

```
StatsMonitor/Sources/       # 主程式碼
  App/                      # App 入口（MenuBarExtra scene）
  Models/                   # 資料結構（SystemStats 等）
  Services/                 # 系統監控（CPU、Memory、Disk、Network）
  ViewModels/               # @Observable view models
  Views/                    # SwiftUI views（menu bar label、detail popover）
StatsMonitor/Resources/     # 資源檔案
Tests/Sources/              # 測試（Swift Testing）
Packages/Util/              # 本地共用 Package
```

## Packages 規範

### Packages/Util

**適合放入**：跨 Feature 共用的純邏輯工具（Extension、Formatter、Validator）

**不適合放入**：UI 元件、Feature 專屬邏輯、第三方封裝

**引用方式**：`import Util`

## 重要細節

- Menu-bar-only app（LSUIElement = true，無 Dock icon）
- `MenuBarExtra` 使用 `.window` style，非 `.menu` style
- 系統 stats 透過 Darwin C API（`host_processor_info`、`host_statistics64`、`getifaddrs`）
- Timer polling 約 2 秒間隔
- Detail popover 底部需有 Quit 按鈕（無標準 app menu）

## 慣例

- SwiftUI 優先，禁 AppKit（除非框架限制）
- 禁 Storyboard / XIB
- 檔案命名 PascalCase
- 間距 8pt 倍數
- `@Observable` 管理狀態（非 `ObservableObject`）
- Buildable Folder：在現有資料夾新增檔案不需 `tuist generate`
- 所有 SwiftUI View 必須附 `#Preview(traits: .sizeThatFitsLayout)`
