# StatsMonitor

macOS menu bar app — SwiftUI + Tuist

## 技術棧

- **平台**: macOS 15.0+（menu bar only，LSUIElement）
- **UI**: SwiftUI（MenuBarExtra + `.window` style）
- **專案管理**: Tuist（Buildable Folder 結構）
- **架構**: MVVM（@Observable）
- **Concurrency**: Swift Strict Concurrency complete
- **語系**: en（developmentRegion）、zh-Hant

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
StatsMonitor/Sources/
  App/
    StatsMonitorApp.swift              # MenuBarExtra scene + window management
    AppSettings.swift                  # @Observable 使用者設定，UserDefaults 持久化
    QuitConfirmationController.swift   # 退出確認流程（AppTerminationGate、QuitConfirmationController）
  Models/
    SystemStats.swift         # 硬體資料結構（CPUUsage/MemoryUsage/DiskUsage/…；無 SystemStats 容器）
  Services/
    SystemMonitor.swift       # 單一 @Observable store，集中管理 raw sample histories，current 由 history.last 推導
    CPUMonitor.swift          # host_processor_info
    CPUFrequencyMonitor.swift # sysctl cpu frequency
    GPUMonitor.swift          # IOAccelerator（Metal GPU stats）
    ANEMonitor.swift          # IOReport Apple Neural Engine 功率
    MemoryMonitor.swift       # host_statistics64
    DiskMonitor.swift         # statfs + DiskArbitration IO stats
    NetworkMonitor.swift      # getifaddrs
    NetworkProcessMonitor.swift # lsof-based per-process network
    ProcessMonitor.swift      # proc_pidinfo（CPU/Memory/Disk top processes）
    BatteryMonitor.swift      # IOKit AppleSmartBattery（桌機回傳 nil）
    ThermalMonitor.swift      # IOKit SMC（CPU/GPU 溫度；不支援時回傳 nil）
    FanMonitor.swift          # IOKit SMC（風扇 RPM；無風扇機型回傳空陣列）
    SMCClient.swift           # SMC 連線管理，ThermalMonitor/FanMonitor 共用
    PowerMonitor.swift        # IOReport Energy Model（CPU/GPU/整機功率 mW；非 Apple Silicon 回傳 nil）
  Views/
    LineChartView.swift       # 共用折線圖元件
    DashboardView.swift       # Settings 視窗 Dashboard 分頁（總覽卡片 + 行程表）
    MainWindowView.swift      # 主視窗 sidebar tabs（CPU / GPU / Memory / Disk / Power / Dashboard / General / About）
    AboutView.swift           # About 分頁（版本資訊 + 系統規格）
    Detail/
      DetailPanel.swift           # 點擊 menu bar 展開的 popover 容器
      CPUDetailView.swift         # CPU 詳細（用量、每核心、頻率、熱門行程）
      GPUDetailView.swift         # GPU 詳細（Device/Renderer/VRAM/ANE/Engines）
      MemoryDetailView.swift      # Memory 詳細（Used/Active/Wired/Compressed/行程）
      DiskDetailView.swift        # Disk 詳細（IO throughput/Used/Free/Total/行程）
      NetworkDetailView.swift     # Network 詳細（In/Out throughput/行程）
      ThermalDetailView.swift     # Thermal 詳細（溫度歷史圖、CPU/GPU 溫度、風扇統計）
      PowerDetailView.swift       # Power 詳細（功耗歷史圖、CPU/GPU/整機功率、電池充放電）
      FansDetailView.swift        # Fans 詳細（平均 RPM 歷史圖、各風扇 RPM 範圍）
      DetailComponents.swift      # statRow/sectionHeader/detailToolbar/BarView 等共用元件
StatsMonitor/Resources/
  Assets.xcassets             # App 圖示
  Localizable.xcstrings       # String Catalog（en 為 sourceLanguage，含 zh-Hant 翻譯）
Tests/Sources/
  StatsMonitorTests.swift     # Swift Testing：Model / ViewModel / Service 整合測試
Packages/Util/
  Sources/Util/
    Formatters.swift          # formatBytes / formatBytesCompact / formatThroughput / ghzString
    RingBuffer.swift          # 固定容量 O(1) 環形緩衝（history 用）
```

## AppSettings — UserDefaults Keys

| Property | Key | 預設值 | 說明 |
|---|---|---|---|
| `pollInterval` | `pollInterval` | `2.0` 秒 | 感測器輪詢間隔（1/2/5/10 秒） |
| `historyCapacity` | `historyCapacity` | `120` | RingBuffer 容量（60/120/300 筆） |
| `processCount` | `processCount` | `10` | 熱門行程顯示數量（5/10/15/20 Picker） |
| `dashboardColumns` | `dashboardColumns` | `4` | Dashboard / chart tabs 共用 grid 尺寸設定（3–6 滑桿，toolbar 控制） |
| `showCPU` | `showCPU` | `true` | Menu bar 顯示 CPU |
| `showGPU` | `showGPU` | `true` | Menu bar 顯示 GPU |
| `showMemory` | `showMemory` | `true` | Menu bar 顯示 Memory |
| `showDisk` | `showDisk` | `true` | Menu bar 顯示 Disk |
| `showNetwork` | `showNetwork` | `true` | Menu bar 顯示 Network |
| `launchAtLogin` | SMAppService | system | 登入時自動啟動 |

## Settings 視窗分頁

- **CPU**：每核心用量圖 + 熱門 CPU 行程；toolbar slider 與 Dashboard 共用，調整 grid item 尺寸
- **GPU**：GPU engines / frequency / media engine 圖 + 熱門 GPU 行程；toolbar slider 與 Dashboard 共用，調整 grid item 尺寸
- **Memory**：Used / Free / Active / Wired / Compressed / Swap 圖 + 熱門記憶體行程；toolbar slider 與 Dashboard 共用，調整 grid item 尺寸
- **Disk**：容量 / Read / Write / Total I/O 圖 + 熱門磁碟行程；toolbar slider 與 Dashboard 共用，調整 grid item 尺寸
- **Power**：總功耗 / CPU / GPU / media engine / 供電來源圖 + 熱門 energy impact；toolbar slider 與 Dashboard 共用，調整 grid item 尺寸
- **Dashboard**：總覽卡片（CPU/GPU/Memory/Disk/Network/Disk I/O/Battery/Thermal/Power/Fans 折線圖 + 數值）+ 合併熱門行程表；toolbar slider 控制共用 grid 尺寸（3–6）
- **General**：AppSettings 所有可調選項
- **About**：版本資訊、系統規格（型號/晶片/macOS/RAM/開機時間）

## Packages 規範

### Packages/Util

**適合放入**：跨 Feature 共用的純邏輯工具（Formatter、RingBuffer 等）

**不適合放入**：UI 元件、Feature 專屬邏輯、第三方封裝

**引用方式**：`import Util`

**目前內容**：
- `formatBytes(UInt64) -> String` — KB/MB/GB 格式化
- `formatBytesCompact(UInt64) -> String` — 緊湊格式（用於 menu bar label）
- `formatThroughput(Double) -> String` — KB/s、MB/s
- `ghzString(UInt64) -> String` — CPU 頻率顯示
- `RingBuffer<T>` — 固定容量 O(1) append，Collection，用於 history chart data

## 本地化機制

- `developmentRegion: "en"`：英文為原始語言（source language）
- 格式：`Localizable.xcstrings`（String Catalog），統一管理所有語言翻譯
- UI 字串：以英文 `LocalizedStringKey` 字面量傳入，SwiftUI `Text` 自動查找翻譯
- 共用 helper（`statRow`、`sectionHeader` 等）接受 `LocalizedStringKey`，字串字面量自動轉型
- **Process name** 顯示用 `statRow(verbatim: proc.name, ...)` 避免誤查本地化表
- `AboutView.uptime` 使用 `DateComponentsFormatter` 自動跟隨系統語言
- **未本地化字串在 monitor extension 層**：`SystemMonitor` 的格式化 extension 中狀態字串（"Charging"/"Plugged In"/"On Battery"/"N/A"/"No fans" 及 "RPM"/"W"/"mW"/"cycles" 等單位）為硬編碼英文，不在 xcstrings 中

## 測試覆蓋

測試框架：**Swift Testing**（`@Suite`、`@Test`、`#expect`）

- 想看目前 UI 截圖時，優先看 snapshot 測試產出的參考圖：`Tests/Sources/__Snapshots__/StatsMonitorSnapshotTests/`
- 任何使用者看得到的畫面都必須有 screenshot test；新增或修改 UI 時，對應的 alert / sheet / panel / popover / window / empty state / error state 都要補 snapshot reference

| 層 | 測試內容 |
|---|---|
| Model | CPUUsage.used、MemoryUsage.usedFraction/used、DiskUsage.usedFraction、GPUUsage、BatteryUsage、FanUsage.fraction、ThermalUsage、PowerUsage、ProcInfo |
| SystemMonitor presentation extension | formatted properties（cpuPercent、memoryPercent 等）with known raw sample input、batteryStatus 所有分支、anePowerText 分支、lifecycle（start/stop）、formatProcess helpers |
| Service 整合 | MemoryMonitor.sample()（total > 0、usedFraction in 0…1）、DiskMonitor.sample()（total > 0、used ≤ total）、NetworkMonitor.sample()（bytesIn/Out ≥ 0） |
| Util | formatBytes / formatBytesCompact / formatThroughput / ghzString / RingBuffer |

## 重要細節

- Menu-bar-only app（LSUIElement = true，無 Dock icon）
- `MenuBarExtra` 使用 `.window` style，非 `.menu` style
- 系統 stats 透過 Darwin C API（`host_processor_info`、`host_statistics64`、`getifaddrs`）+ IOKit SMC
- Poll interval 由 `AppSettings.pollInterval` 控制（預設 2 秒），可即時調整
- `SystemMonitor` 內每個圖表/即時指標集中持有 raw sample `history`，目前值由 `history.last` 推導
- Polling service 與其他 monitor 透過 typed `record(...)` 寫入對應 raw sample history
- History 透過 `MetricHistory<T>` 包裝 `RingBuffer<T>`，容量由 `AppSettings.historyCapacity` 決定
- `ProcessMonitor` 與 `NetworkProcessMonitor` 背景非同步執行（`Task.detached`）
- Battery/Thermal/Fan monitor 在不支援硬體時回傳 nil / 空陣列，UI graceful 隱藏
- ThermalMonitor 與 FanMonitor 共用 `SMCClient` 連線
- `PowerMonitor` 使用 IOReport Energy Model 量測 CPU/GPU/整機功率（mW）；非 Apple Silicon 或首次呼叫回傳 nil（需兩次 sample 計算 delta）

## 慣例

- SwiftUI 優先，禁 AppKit（除非框架限制）
- 禁 Storyboard / XIB
- 檔案命名 PascalCase
- 間距 8pt 倍數
- `@Observable` 管理狀態（非 `ObservableObject`）
- Buildable Folder：在現有資料夾新增檔案不需 `tuist generate`
- 所有 SwiftUI View 必須附 `#Preview(traits: .sizeThatFitsLayout)`
