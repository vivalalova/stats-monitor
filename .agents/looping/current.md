---
title: Popover 細節強化（Chart、Per-Core、Process 排名）
created: 2026-04-13
priority: high
suggested_order: A2
phase: completed
iteration: 1
max_iterations: 5
review_iterations: 0
---

# Popover 細節強化（Chart、Per-Core、Process 排名）

目前 5 個 popover 只顯示即時數字。需強化為：
1. 歷史趨勢 mini chart（最近 N 筆 polling 樣本的折線/長條圖）
2. CPU 每核心使用率
3. GPU 每核心（若硬體支援）使用率
4. 各 popover 顯示佔用該資源最多的 process 排名（top 5）

## 架構設計

### Chart
- `RingBuffer<Double>` 或 `[Double]` 儲存最近 60 筆（約 2 分鐘）polling 樣本
- SwiftUI `Canvas` 或 `Path` 畫折線圖；不引入第三方圖表庫
- `SystemMonitor` 每次 `poll()` 後 append 到各指標的歷史 buffer
- CPU/GPU/Memory/Disk/Network 各自保有歷史序列

### Per-Core CPU
- `CPUMonitor.sample()` 改回傳 per-core 使用率陣列（現在只回傳總平均）
- `CPUUsage` 新增 `perCore: [Double]`（每核心 used%）
- `CPUDetailView` 展示核心列表（`Core 0: 45%` 等）+ 個別 progress bar

### Per-Core GPU
- IOKit `IOAccelerator` PerformanceStatistics 查找 per-engine 使用率（`Vertex Utilization %`, `Fragment Utilization %` 等）
- `GPUUsage` 新增 `engines: [String: Double]`
- `GPUDetailView` 展示各 engine 名稱與使用率

### Process 排名
- 使用 `proc_pidinfo` / `sysctl` 列出所有 process，取 CPU/Memory 各自 top 5
- CPU popover：top 5 CPU 耗用 process（name + %）
- Memory popover：top 5 Memory 耗用 process（name + MB）
- GPU/Disk/Network popover：如取得困難則顯示 N/A 佔位，不影響其他功能交付

## User Stories

- As a user, I want to see a mini chart in each popover, so that I can spot usage trends without opening another tool
- As a user, I want per-core CPU breakdown, so that I can identify which core is under load
- As a user, I want to see which processes are consuming the most CPU/memory, so that I can decide what to kill

## 驗收條件

- Given CPU popover 開啟, when 已有至少 2 筆 polling 數據, then 顯示折線趨勢圖（時間軸 x 軸，使用率 y 軸）
- Given CPU popover 開啟, when 機器有多核心, then 每核心獨立顯示使用率與 progress bar
- Given GPU popover 開啟, when GPU 回傳多個 engine, then 分列顯示各 engine 使用率
- Given CPU popover 開啟, when top process 可取得, then 顯示 top 5 CPU process（name + %）
- Given Memory popover 開啟, when top process 可取得, then 顯示 top 5 Memory process（name + MB）
- Given `tuist build`, then build 成功無 error
- Given `tuist test`, then 所有 tests pass
