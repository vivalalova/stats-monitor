---
title: Dashboard 總覽分頁
created: 2026-04-14
priority: high
suggested_order: C1
blockedBy: a1-settings-general
phase: needs-review
iteration: 1
max_iterations: 5
review_iterations: 1
max_review_iterations: 5
---

# Dashboard 總覽分頁

目前只能逐一點擊 menu bar item 查看單一資源的 detail popover，缺乏一覽全局的總覽頁。A1 已在 NavigationSplitView sidebar 建立 `.dashboard` Tab case，本 task 填入實際內容。

## 範圍

1. **DashboardView 實作**：在 Settings 視窗的 sidebar Dashboard tab 中，以 grid 排列 5 項監控摘要（CPU / GPU / Memory / Disk / Network），每項包含：
   - mini LineChartView（重用現有元件，縮小 height）
   - 關鍵數值（使用率百分比 / 主要指標 / 狀態色塊，重用 `progressColor`）
2. **統一 Process Table**：Dashboard 底部顯示合併的 top processes 表格（Name / CPU% / Memory / Disk I/O / Network I/O），取各維度 top N 聯集。
3. **共享 ViewModel**：使用 `StatsMonitorApp` 已有的共享 `@State StatsViewModel` instance，透過 Environment 或參數傳入 DashboardView。
4. **Dashboard 作為預設 tab**：Settings 視窗開啟時，sidebar 預設選中 Dashboard（非 General）。
5. **視窗尺寸調整**：Dashboard 內容較多，可能需要擴大視窗 minWidth 或讓視窗 resizable。
6. **#Preview** for DashboardView。

## User Stories

- As a user, I want a single dashboard view showing all system metrics and charts at once, so that I can monitor everything without clicking multiple menu bar items.
- As a user, I want to see which processes are consuming the most resources across all categories in one table.

## 驗收條件

- Given I open Settings, then Dashboard tab is selected by default and shows 5 metric cards
- Given the dashboard is visible, when system stats update every poll cycle, then all mini charts and values refresh in real time
- Given the dashboard, then I see a unified process table showing top consumers across CPU/memory/disk/network
- Given I resize the window, then the grid layout adapts responsively
