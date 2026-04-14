---
title: 設定頁基礎建設與 General 分頁
created: 2026-04-14
priority: critical
suggested_order: A1
---

# 設定頁基礎建設與 General 分頁

目前 `SettingsView.swift` 僅為空殼，`GeneralSettingsView` 無任何控制項，整個 app 零持久化機制。所有運作參數（polling interval 2s、history capacity 120、process count 10、5 個 menu bar item 全部顯示）皆硬編碼。缺少 launch at login。

此 task 同時確立「單一視窗 + sidebar 切換」架構——Settings、Dashboard、About 全部作為同一 NSWindow 內 NavigationSplitView 的 sidebar tab，後續 task（C1 Dashboard、B2 About）僅需新增 Tab case + 對應 View。

## 範圍

1. **持久化層**：使用 `@AppStorage` 為所有設定項建立持久化（polling interval、history capacity、process count、每個 menu bar item 的顯示開關、launch at login）。
2. **GeneralSettingsView 完整 UI**：Picker 調整 polling interval（1s/2s/5s/10s）、Stepper/Picker 調整 history capacity、Stepper 調整 process count、5 個 Toggle 控制各 menu bar item 顯示/隱藏、Toggle 控制開機自動啟動。
3. **MenuBarExtra 顯示/隱藏**：將 `StatsMonitorApp.swift` 中 5 個 `MenuBarExtra` 改用 `MenuBarExtra(isInserted:content:label:)` 初始化器，綁定 `@AppStorage` 的 `Binding<Bool>`。
4. **SystemMonitor 整合**：讀取 `@AppStorage` 值，取代硬編碼常數。pollInterval 變更時需 invalidate 現有 Timer 並以新 interval 重建（不需 restart app）。使用 `SMAppService.mainApp` 實作 launch at login。
5. **Tab enum 擴充預備**：確保 Tab enum 已包含 `.general`、`.dashboard`、`.about` case（dashboard/about View 可先用 placeholder，由 C1/B2 實作）。
6. **#Preview** for GeneralSettingsView。

## User Stories

- As a user, I want to customize polling frequency, history length, visible menu bar items, and enable launch at login, so that I can tailor the app to my preferences.
- As a user, I want all settings, dashboard, and about in a single window with sidebar navigation, so that the experience is cohesive.

## 驗收條件

- Given the app launches, when I open Settings, then I see a NavigationSplitView with sidebar containing General / Dashboard / About tabs
- Given I change polling interval to 5s, when I relaunch the app, then polling runs at 5s
- Given I toggle off the GPU menu bar item, when I look at the menu bar, then the GPU icon is gone
- Given I toggle on launch at login, when I check System Settings > General > Login Items, then StatsMonitor appears
- Given I set process count to 5, when I view any detail popover, then only 5 processes are shown
