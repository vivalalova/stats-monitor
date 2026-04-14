---
title: Util Package 充實與格式化函式去重複
created: 2026-04-14
priority: high
suggested_order: E1
---

# Util Package 充實與格式化函式去重複

`ghzString` 在 `SystemStats.swift`（CPUCoreFrequency.ghzString）和 `CPUDetailView.swift`（CoreGridView.ghzString）重複實作。`StatsViewModel` 中的 `formatBytes`、`formatBytesCompact`、`formatThroughput` 是通用格式化邏輯但被定義為 private instance method。`Packages/Util` 目前完全空（`public enum Util {}`）。

## 範圍

1. **建立 `Formatters.swift`**：於 `Packages/Util/Sources/Util/`，將 `ghzString`、`formatBytes`、`formatBytesCompact`、`formatThroughput` 提升為 public static method（或 free function）。
2. **更新呼叫端**：`SystemStats.swift`、`CPUDetailView.swift`、`StatsViewModel.swift` 改為 `import Util` 並使用共用函式，刪除原始 private 實作。
3. **Formatter 單元測試**：於 `Packages/Util/Tests/UtilTests/`，涵蓋各函式的 zero、normal、edge case（超大數值、負數等）。

## User Stories

- As a developer, I want formatting utilities consolidated in one place, so that changes propagate consistently and there is no divergent formatting logic.

## 驗收條件

- Given `Packages/Util/Sources/Util/Formatters.swift` exists, then it exports `ghzString`, `formatBytes`, `formatBytesCompact`, `formatThroughput`
- Given the main target, when searching for duplicate `ghzString` implementations, then only one exists (in Util)
- Given `formatBytes(0)`, then returns "0 B"
- Given `formatBytes(1_073_741_824)`, then returns "1.0 GB"
- Given `formatThroughput(1_048_576)`, then returns "1.0 MB/s"
- Given `tuist build`, then no compilation errors
