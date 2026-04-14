---
title: About 分頁（版本與系統資訊）
created: 2026-04-14
priority: medium
suggested_order: B2
blockedBy: a1-settings-general
phase: executing
iteration: 2
max_iterations: 5
review_iterations: 1
max_review_iterations: 5
---

# About 分頁（版本與系統資訊）

Menu-bar-only app 沒有標準 app menu，使用者無法查看版本號等基本資訊。A1 已建立 NavigationSplitView sidebar 架構與 `.about` Tab case placeholder，本 task 填入實際內容。

## 範圍

1. **AboutView 實作**：顯示 app icon、app name、版本號（CFBundleShortVersionString）、build 號（CFBundleVersion）、版權聲明。
2. **系統資訊區**：Mac 型號（sysctl `hw.model`）、晶片名稱（Apple Silicon: IOKit DeviceTree `product-name`；Intel: `machdep.cpu.brand_string`）、macOS 版本（ProcessInfo）、已安裝記憶體、system uptime（`ProcessInfo.processInfo.systemUptime`，格式化為「X 天 Y 時 Z 分」）。
3. **替換 A1 的 placeholder**：將 Tab.about 對應的 View 從 placeholder 換為 AboutView。
4. **#Preview** for AboutView。

## User Stories

- As a user, I want to see app version, build info, and my system specs in one place, so that I can identify my setup when reporting issues.

## 驗收條件

- Given I open Settings and click About tab, then I see app version, build number, and copyright
- Given I'm on About tab, then I see my Mac model, chip name, macOS version, and total RAM
- Given the About tab content, when I compare with System Information.app, then the values match
