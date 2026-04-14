---
title: 本地化 — zh-Hant 與 en 雙語系
created: 2026-04-14
priority: low
suggested_order: E3
blockedBy: [a1-settings-general, c1-dashboard-tab, b2-about-tab]
---

# 本地化 — zh-Hant 與 en 雙語系

Tuist 設定已配置 `defaultKnownRegions: ["zh-Hant", "en"]` 與 `developmentRegion: "zh-Hant"`，但實際零 `.strings` 或 `.xcstrings` 檔案，所有 UI 文字硬編碼英文。

## 範圍

1. **建立本地化檔案**：`Localizable.strings`（或 String Catalog `.xcstrings`）於 `StatsMonitor/Resources/`，涵蓋 zh-Hant 與 en。
2. **替換硬編碼字串**：所有 View 中的文字改為 `String(localized:)` 或 `LocalizedStringKey`。涵蓋：Detail panel titles、stat labels（Used/User/System/Idle/Active/Wired/Compressed 等）、section headers（Per Core/Top Processes/Engines）、Settings 頁面文字、Dashboard 文字、About 文字。
3. **確保 #Preview 正常運作**。

## User Stories

- As a user in a Traditional Chinese locale, I want the app UI in my language, so that it feels native and accessible.

## 驗收條件

- Given macOS system language is zh-Hant, when I open the app, then all UI text displays in Traditional Chinese
- Given macOS system language is en, when I open the app, then all UI text displays in English
- Given `tuist build`, then no missing localization warnings
- Given any View with `#Preview`, then preview renders without crash
