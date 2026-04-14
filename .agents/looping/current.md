---
title: 測試補強 — Service 與 ViewModel 層
created: 2026-04-14
priority: medium
suggested_order: E2
blockedBy: [e1-util-dedup, d1-data-layer-performance]
---

# 測試補強 — Service 與 ViewModel 層

目前測試只覆蓋 model struct（CPUUsage.used、MemoryUsage.usedFraction 等），零 service 或 ViewModel 測試。

## 範圍

1. **StatsViewModel 測試**：驗證格式化 computed properties（cpuPercent、memoryPercent、diskPercent 等）、start/stop lifecycle 不 crash。
2. **Service 合理性測試**：`MemoryMonitor.sample()` 回傳 total > 0 且 usedFraction in 0...1；`DiskMonitor.sample()` total > 0 且 used ≤ total；`NetworkMonitor` 初始 sample bytesInPerSec/bytesOutPerSec ≥ 0。
3. **測試策略**：優先 integration test 直接呼叫 real monitor（硬體 API 在 macOS 上可直接跑）。僅在 CI 環境無法執行硬體 API 時才引入 `MonitorProtocol` 做 stub 注入。
4. 使用 Swift Testing framework（`@Test`、`#expect`），與現有風格一致。

## User Stories

- As a developer, I want comprehensive tests for services and view models, so that regressions are caught early and refactoring is safe.

## 驗收條件

- Given `tuist test`, then all new tests pass
- Given MemoryMonitor.sample(), then total > 0 and usedFraction is in 0...1
- Given DiskMonitor.sample(), then total > 0 and used ≤ total
- Given StatsViewModel with known SystemStats input, then formatted strings match expected output
