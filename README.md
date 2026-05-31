# StatsMonitor

macOS menu bar 系統監控工具，即時顯示 CPU / GPU / Memory / Disk / Network / Battery / Thermal / Power / Fans，點擊展開各指標詳細面板。

## 功能

- Menu bar label：CPU / GPU / Memory / Disk / Network / Battery / Thermal / Power / Fans，可個別開關
- 點擊展開詳細 popover，含歷史折線圖、熱門行程、Wi-Fi 資訊、電池健康度等
- Settings 視窗：CPU / GPU / Memory / Disk / Network / Power / Dashboard / Diagnostics / General / About 十分頁
- Diagnostics：硬體相容性檢查、各監控 sample 狀態、目前指標、最近 crash report 摘要與 Markdown 匯出
- 硬體不支援的指標（桌機無電池、Intel Mac 無 Power、無風扇機型無 Fans）自動隱藏
- 繁體中文 / English，跟隨系統語言

## 需求

- macOS 26.0+（Tahoe，使用 Liquid Glass UI）
- Xcode 26+
- [Tuist](https://tuist.io) 4.x（`brew install tuist`）

> 目前僅在 MacBook Air M3 測試過，其他機型（Intel、桌機、其他 Apple Silicon 型號）未驗證。

## 快速開始

```bash
tuist install
tuist generate
open StatsMonitor.xcworkspace
```

一鍵 Release 安裝：

```bash
fastlane mac install
```
