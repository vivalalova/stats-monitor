---
title: 更新文件（CLAUDE.md / README.md）
created: 2026-04-14
priority: low
suggested_order: Z99
blockedBy: [a1-settings-general, c1-dashboard-tab, b2-about-tab, d1-data-layer-performance, d2-new-sensors, e1-util-dedup, e2-test-coverage, e3-localization]
---

# 更新文件（CLAUDE.md / README.md）

隨所有 task 完成，文件需同步反映新架構。

## 範圍

1. **CLAUDE.md**：新增 Settings 架構說明（@AppStorage keys 列表）、Dashboard/About 分頁說明、新 Services（Battery/Thermal/Fan）、Util package 實際內容、本地化機制、測試覆蓋範圍。
2. **README.md**：功能列表、設定說明。
3. **專案結構段落**反映新增檔案與目錄。

## User Stories

- As a developer onboarding to this project, I want accurate documentation reflecting current architecture.

## 驗收條件

- Given CLAUDE.md, then all new files/services/settings are documented
- Given README.md, then feature list matches current app capabilities
- Given the project structure section, then it matches the actual file tree
