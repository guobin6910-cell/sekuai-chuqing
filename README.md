# 色塊出清

Godot 4 益智遊戲：在格狀棋盤上選取色塊，沿行列滑動；整塊從邊緣推出即清除。清空所有色塊過關。

倉庫：https://github.com/guobin6910-cell/sekuai-chuqing

## 系統需求

- [Godot 4.2+](https://godotengine.org/)（建議 4.2／4.3／4.4）
- 桌面或行動裝置（直向版面友善，亦可橫放視窗遊玩）

## 如何開啟／執行

1. 用 Godot 4 開啟本專案根目錄（含 `project.godot` 的資料夾）。
2. 主場景已設為 `scenes/MainMenu.tscn`。
3. 按 **F5**（或「執行專案」）即可遊玩。

無需額外套件或素材包；色塊與介面皆以程式繪製。

## 操作說明

| 操作 | 說明 |
|------|------|
| 點選／點擊色塊 | 選取該色塊（白邊高亮） |
| 拖曳滑動 | 選取後朝上／下／左／右拖曳，色塊會沿該方向滑到受阻或推出盤外 |
| 鍵盤 | 選取後用方向鍵或 WASD 滑動 |
| 重新開始 | 重載本關 |
| 上一步 | Undo（復原上一次滑動） |
| Ctrl+Z | 同上一步 |

色塊**整塊**滑出棋盤邊緣後會清除，並有簡短粒子效果。全部清除即通關。

## 關卡一覽（共 5 關）

1. **推出教學** — 單格色塊，練習滑出
2. **穿越圍牆** — 固定牆與短棒
3. **擁擠色塊** — 多色互相擋路
4. **L 型色塊** — L 形多格塊
5. **綜合挑戰** — 牆、L、擁擠組合

關卡資料：`levels/level_01.json` … `level_05.json`

## 如何新增關卡

1. 在 `levels/` 新增 JSON，例如 `level_06.json`，格式：

```json
{
  "id": 6,
  "name": "第6關：自訂",
  "width": 6,
  "height": 6,
  "walls": [{"x": 2, "y": 2}],
  "pieces": [
    {
      "id": 1,
      "color": "#FF6B9D",
      "cells": [{"x": 0, "y": 0}, {"x": 1, "y": 0}]
    }
  ]
}
```

2. 在 `scripts/GameState.gd` 的 `LEVEL_COUNT` 與 `LEVEL_PATHS` 加入新路徑。
3. 重新執行專案；選關畫面會依 `LEVEL_COUNT` 顯示。

### 欄位說明

- `width` / `height`：棋盤寬高
- `walls`：不可進入的固定牆座標
- `pieces`：色塊列表；`cells` 為該塊佔用的格子（可為 1×1、長條、L 等）
- `color`：HTML 色碼

## 場景流程

主選單 → 選關 → 遊戲 → 通關 → 下一關／選關／主選單


## 網頁版（GitHub Pages）

可在瀏覽器（含 **iOS Safari**）直接遊玩，無需安裝 Godot。

- **遊玩網址**：https://guobin6910-cell.github.io/sekuai-chuqing/
- **匯出方式**：倉庫以 GitHub Actions 自動以 Godot 4.3 **單執行緒（single-threaded）** Web 預設匯出，並部署至 GitHub Pages。
- 預設名稱為 `Web`，匯出路徑為 `build/web/index.html`（見 `export_presets.cfg`）。
- CI 指令大致為：`godot --headless --export-release "Web" build/web/index.html`
- 觸發條件：推送到 `main`（或 `feature/sekuai-chuqing-mvp`）、以及手動 `workflow_dispatch`。

採用單執行緒匯出是為了在 GitHub Pages 靜態托管上避免 SharedArrayBuffer／COOP-COEP 標頭需求，相容性較好（尤其 iOS Safari）。

### iOS Safari 小提示

1. 用 Safari 開啟上述網址（建議直向握持）。
2. 可選：點分享 →「加入主畫面」，之後像 App 一樣開啟。
3. 若畫面空白或卡住，可強制重新整理；首次載入需下載 WASM，請稍候。
4. 請保持裝置勿進入低耗電、並允許頁面使用足夠記憶體；分頁久置背景後再回來若異常，重新整理即可。

### 本機匯出（選用）

1. Godot 4.3+ 編輯器安裝對應 **Export Templates**。
2. 專案 → 匯出 → 選擇「Web」預設（`variant/thread_support=false`）。
3. 匯出至 `build/web/index.html`，以本機靜態伺服器開啟該目錄測試。

## 授權

專案程式與關卡為原創內容；請依倉庫授權使用。
