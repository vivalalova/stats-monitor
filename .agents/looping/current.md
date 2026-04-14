---
title: 新增感測器 — 電池、溫度、風扇、系統運行時間
created: 2026-04-14
priority: medium
suggested_order: D2
blockedBy: [a1-settings-general, b2-about-tab]
phase: needs-review
iteration: 2
max_iterations: 5
review_iterations: 3
max_review_iterations: 5
---

# 新增感測器 — 電池、溫度、風扇

目前缺少 battery/power、temperature、fan speed 等常見系統監控資訊。System uptime 已由 B2 About 分頁實作。

## 範圍

1. **BatteryMonitor**：via IOKit `AppleSmartBattery`——電量百分比、充電狀態、剩餘時間、循環次數、健康度。桌機（Mac mini/Studio/Pro）無電池時 graceful 回傳 nil，UI 不顯示。
2. **ThermalMonitor**：via IOKit SMC——CPU package 溫度、GPU 溫度。Apple Silicon 與 Intel SMC key 不同（Apple Silicon: `Tp09`/`Tg0P` 等；Intel: `TC0P`/`TG0P`），需做降級處理（unavailable 時不顯示）。
3. **FanMonitor**：via IOKit SMC——各風扇 RPM。無風扇機型（MacBook Air）graceful nil。
4. **Model 擴充**：`SystemStats` 新增對應欄位，`StatsViewModel` 新增格式化 computed properties。
5. **UI 呈現**：新增 System 相關區塊至 Dashboard（C1 已完成）。Battery 可在 menu bar 新增圖示（A1 設定開關已就緒）。
6. **#Preview** for 新 UI。

## User Stories

- As a MacBook user, I want to see battery status, temperatures, and fan speeds alongside existing metrics, so that I have complete hardware awareness. (System uptime already in B2 About tab.)
- As a desktop Mac user, I want battery/fan sections to gracefully hide when hardware is absent.

## 驗收條件

- Given a MacBook, when I view the battery section, then I see charge %, charging state, cycle count, and health
- Given a Mac mini (no battery), when the app loads, then no battery section is shown and no errors logged
- Given ThermalMonitor, when I compare CPU temperature with a third-party tool (like TG Pro), then values are within ±3°C
- Given FanMonitor on a MacBook Pro, when I see fan RPM, then it matches `smc` CLI output
