# StatsMonitor

macOS menu bar 系統監控工具，輕量顯示即時硬體狀態，點擊展開各指標詳細面板。

## 功能

- **Menu Bar 即時顯示**：CPU / GPU / Memory / Disk / Network 使用率（可個別開關）
- **點擊展開詳細面板**：
  - CPU：總用量、User/System/Idle 比例、每核心用量與頻率
  - GPU：Device/Renderer 用量、GPU 記憶體、Neural Engine 功率、Engines 分佈
  - Memory：Used/Active/Wired/Compressed、熱門行程
  - Disk：讀寫 throughput、Used/Free/Total、熱門行程
  - Network：In/Out throughput、熱門行程
- **Battery**（MacBook）：電量、充電狀態、剩餘時間、循環次數、健康度
- **Thermal**：CPU/GPU 溫度（透過 SMC；不支援時自動隱藏）
- **Fans**：各風扇 RPM（無風扇機型自動隱藏）
- **Settings 視窗**（八分頁）：
  - **CPU**：每核心用量圖 + 熱門行程
  - **GPU**：各 GPU engine / 頻率 / media engine 圖 + 熱門行程
  - **Memory**：Used / Free / Active / Wired / Compressed / Swap 圖 + 熱門行程
  - **Disk**：容量 / Read / Write / Total I/O 圖 + 熱門行程
  - **Power**：總功耗 / CPU / GPU / media engine / 供電來源圖 + 熱門 energy impact
  - **Dashboard**：所有指標卡片總覽 + 合併熱門行程表
  - **General**：輪詢間隔（1/2/5/10 秒）、歷史容量（1/2/5 分鐘）、行程數量、Menu bar 項目開關、登入自動啟動
  - **About**：版本資訊、Mac 型號/晶片/macOS/RAM/開機時間
- **雙語系**：繁體中文（zh-Hant）/ 英文（en），跟隨系統語言切換

## 需求

- macOS 15.0+
- Xcode 16+
- Tuist 4.x（`brew install tuist`）

## 快速開始

```bash
tuist install    # 安裝 SPM 依賴
tuist generate   # 生成 Xcode 專案
open StatsMonitor.xcworkspace
```

## 架構

```
App/            StatsMonitorApp.swift — MenuBarExtra scene
                AppSettings.swift — @Observable 設定（UserDefaults 持久化）
Models/         SystemStats.swift — 所有硬體資料結構
Services/       CPUMonitor / GPUMonitor / ANEMonitor / MemoryMonitor /
                DiskMonitor / NetworkMonitor / NetworkProcessMonitor /
                ProcessMonitor / BatteryMonitor / ThermalMonitor / FanMonitor /
                SMCClient / SystemMonitor（協調層）
Views/          MenuBarLabel / LineChartView / DashboardView /
                MainWindowView / AboutView / Detail/*
Packages/Util/  formatBytes / formatThroughput / ghzString / RingBuffer
```

系統資料透過 Darwin C API（`host_processor_info`、`host_statistics64`、`getifaddrs`）與 IOKit（SMC、AppleSmartBattery、IOAccelerator）取得。`SystemMonitor` 是單一 `@Observable` store：以 `MetricHistory<T>` 集中管理各指標 raw sample history，目前值直接由 `history.last` 推導；polling service 與其他 monitor 透過 typed `record(...)` 寫入，view 直接訂閱；共用格式化則放在 extension。
