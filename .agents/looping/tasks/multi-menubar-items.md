---
title: 拆分為多個獨立 MenuBarExtra（CPU / GPU / Memory / Disk / Network）
created: 2026-04-13
priority: high
suggested_order: A1
---

# 拆分為多個獨立 MenuBarExtra（CPU / GPU / Memory / Disk / Network）

目前是單一統合型 `MenuBarExtra`，顯示 CPU % 並展開所有資訊。
需改為 5 個獨立 `MenuBarExtra`，每個各自顯示對應指標、點開只顯示該指標的細節。

## 設計

| MenuBarExtra | Menu bar 顯示 | 點開內容 |
|---|---|---|
| CPU | `cpu` icon + CPU 使用率 % | User / System / Idle + progress bar |
| GPU | `gpu` icon + GPU 使用率 % | 渲染/計算使用率 + progress bar |
| Memory | `memorychip` icon + 已用/總量 | Active / Wired / Compressed + progress bar |
| Disk | `internaldrive` icon + 使用率 % | Used / Free / Total + progress bar |
| Network | `network` icon + ↓ in ↑ out | 各 interface bytes in/out per sec |

## 架構調整

- `StatsMonitorApp.swift`：加入 5 個 `MenuBarExtra` scene
- 每個 `MenuBarExtra` 有獨立的 label view 和 detail view
- `StatsViewModel` 共用，所有 scene 共享同一個 monitor instance
- 新增 `GPUMonitor.swift`（用 `IOKit` + `IOServiceMatching("IOAccelerator")`）
- 新增各 detail view（`CPUDetailView`、`GPUDetailView`、`MemoryDetailView`、`DiskDetailView`、`NetworkDetailView`）
- `StatsDetailView.swift` 可移除或保留

## User Stories

- As a user, I want separate menu bar icons per metric, so that I can see each stat at a glance without opening any popover
- As a user, I want clicking CPU icon to show only CPU details, so that I'm not overwhelmed by unrelated info

## 驗收條件

- Given app 啟動, when 看 menu bar, then 出現 5 個獨立 icon（CPU / GPU / Memory / Disk / Network）
- Given 5 個 icon 都在, when 點擊 CPU icon, then popover 只顯示 CPU 相關數據（User / System / Idle + progress）
- Given 5 個 icon 都在, when 點擊 Memory icon, then popover 只顯示 Memory 數據
- Given GPU icon 在 menu bar, when 點擊, then 顯示 GPU 使用率（若無 GPU 資料則顯示 N/A）
- Given 所有 icon, when 2 秒 polling 更新, then menu bar 上各 icon 數字即時刷新
- Given `tuist build`, then build 成功無 error
- Given `tuist test`, then 所有 tests pass
