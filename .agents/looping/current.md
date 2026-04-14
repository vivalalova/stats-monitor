---
title: 資料層效能改善（RingBuffer + ProcessMonitor 背景化）
created: 2026-04-14
priority: medium
suggested_order: D1
blockedBy: a1-settings-general
phase: needs-review
iteration: 2
max_iterations: 5
review_iterations: 1
max_review_iterations: 5
---

# 資料層效能改善（RingBuffer + ProcessMonitor 背景化）

兩項效能問題：History 陣列使用 `append + removeFirst`（O(n)）；`ProcessMonitor` 的 sysctl + proc_pidinfo 是 CPU-heavy 操作卻跑在 main actor。

## 範圍

1. **RingBuffer<T> 泛型結構**：定義於 `Packages/Util`，支援 `append`、subscript、`Collection` conformance、轉 `[T]`（for chart consumption）。capacity 從 A1 建立的 `@AppStorage` historyCapacity 讀取。替換 `SystemMonitor` 中 8 條 history `[Double]` 陣列。
2. **ProcessMonitor 背景化**：將 `sample()` 改為在 `Task.detached(priority: .utility)` 執行，結果 dispatch 回 main actor。參考 `pollNetworkProcesses()` 的已有模式。
3. **RingBuffer 單元測試**：capacity、overflow 行為、toArray 順序。

## User Stories

- As a user, I want the monitoring app to use minimal CPU and remain responsive, so that it doesn't degrade my system while monitoring.

## 驗收條件

- Given RingBuffer with capacity 5 and 7 appends, when converted to array, then it contains the last 5 elements in insertion order
- Given ProcessMonitor.sample() is called, when profiling with Instruments, then no work runs on the main thread
- Given Instruments Time Profiler attached, when ProcessMonitor.sample() executes, then sysctl/proc_pidinfo calls appear on a background thread, not Main Thread
