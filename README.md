# StatsMonitor

macOS menu bar 系統監控工具。在 menu bar 顯示 CPU 使用率，點擊展開 CPU、Memory、Disk、Network 詳細資訊。

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
Models/         SystemStats — 資料結構
Services/       CPUMonitor / MemoryMonitor / DiskMonitor / NetworkMonitor
ViewModels/     StatsViewModel — @Observable，統一格式化顯示值
Views/          MenuBarLabel（menu bar 文字）+ StatsDetailView（popover）
```

系統資料透過 Darwin C API 取得，`SystemMonitor` 每 2 秒 polling 一次並廣播最新快照。
