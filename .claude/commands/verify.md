---
description: 建置 + 測試一次完成
allowed-tools: Bash
---

依序執行，遇錯即停：

1. `tuist build`
2. `tuist test`

輸出格式：

- 全部通過 → 回報 `BUILD SUCCEEDED` + `TEST SUCCEEDED` + 測試總數
- 失敗 → 貼完整錯誤輸出，標明失敗階段（build / test）
