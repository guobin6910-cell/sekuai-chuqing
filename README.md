# 色塊出清

Godot 4 益智遊戲：厚框塑膠棋盤被**黃色十字通道**分成四個象限；點擊邊緣**同色三角箭頭**推動並出清積木。拖曳／WASD 僅在棋盤內滑動。**消除必須透過同色邊框箭頭。**關卡目標可為出清、抵達黃通道、象限同色歸位等。

倉庫：https://github.com/guobin6910-cell/sekuai-chuqing

> 美術與名稱皆為原創，不使用任何第三方商標／App 圖示／專有素材。

## 系統需求

- [Godot 4.2+](https://godotengine.org/)（建議 4.3；CI 使用 4.3-stable）
- 桌面或行動裝置（直向版面友善）

## 如何開啟／執行

1. 用 Godot 4 開啟本專案根目錄（含 `project.godot`）。
2. 主場景：`scenes/MainMenu.tscn`。
3. 按 **F5** 執行。

無需額外套件；棋盤框、黃十字、積木凸粒與箭頭皆以 CanvasItem 程序繪製。

## 操作說明

| 操作 | 說明 |
|------|------|
| 點邊緣色箭頭 | **唯一出清方式**：推動該列／行上「距離閘口最近」的同色積木，沿箭頭方向滑到受阻或出清 |
| 點選積木後拖曳 | 沿上／下／左／右在棋盤**內**滑到受阻（不可推出／消除） |
| 鍵盤 | 選取後方向鍵／WASD（同樣不可推出） |
| 重新開始 | 重載本關 |
| 上一步 | Undo |
| Ctrl+Z | 同上一步 |

頂部提示文案由關卡 JSON 的 `hint_text` 驅動，可高亮指定詞（如「黃色」）。

## 移動規則（精確版）

與 `scripts/BoardModel.gd`、`tools/verify_levels.py` 一致：

1. **格子**：可行走格、固定牆、黃色十字通道（可行走，**不是出口**）。
2. **積木**：多格 polyomino，整塊平移，不可旋轉；不可疊格、不可穿牆。
3. **棋盤內滑動**（拖曳／WASD）：選定方向後連續前進，直到下一步不合法為止；**不可離場出清**。
4. **邊緣箭頭**：每支箭頭綁定 `{side, index, color}`。按下後找出該軌道（該行或該列）上距離該側閘口最近的同色積木，朝該側方向滑動。目前無法推動的箭頭會視覺變暗。
5. **消除必須透過同色邊框箭頭**：離場／出清**只能**由按下同色箭頭觸發。閘口須「同側、同色、同 index」；只要有一格經合法閘口離場，**整塊立即出清**（粒子爆開）。自由滑動即使對準閘口也不能推出。
6. **無同色箭頭不可推出**：沒有對應同色箭頭的邊緣無法滑出；按箭頭若軌道上沒有同色塊會提示「沒有同色色塊可推」。
7. **通關**：依關卡 `goal.type` 判定（見下方 schema），不是一律清空。

### UI 字型（繁中）

Web／iOS Safari 預設 Godot 字型不含 CJK 字形。專案嵌入 `assets/fonts/jf-openhuninn-2.1.ttf`（[jf open 粉圓](https://github.com/justfont/open-huninn-font)，OFL），經 `UITheme` autoload 與 `gui/theme/custom_font` 套用到所有 Label／Button／RichTextLabel。

## 關卡一覽（共 5 關）

1. **邊緣箭頭** — 學會點色箭頭推出
2. **黃色通道** — 把積木滑進黃十字（提示：我搆不到黃色）
3. **多色擁擠** — 出口被擋，先清擋路色
4. **L 型色塊** — L 形需對齊多格閘口
5. **出清與歸位** — 清掉指定色，並把其餘色歸到正確象限

關卡資料：`levels/level_01.json` … `level_05.json`  
驗證可解：`python3 tools/verify_levels.py`

## 關卡 JSON schema

```json
{
  "id": 1,
  "name": "第1關：範例",
  "width": 5,
  "height": 5,
  "yellow_cross": { "type": "plus", "col": 2, "row": 2 },
  "walls": [{"x": 3, "y": 0}],
  "pieces": [
    {
      "id": 1,
      "color": "#FF6B9D",
      "cells": [{"x": 1, "y": 0}, {"x": 1, "y": 1}]
    }
  ],
  "edge_arrows": [
    { "side": "top", "index": 1, "color": "#FF6B9D", "dir": "out" }
  ],
  "goal": { "type": "clear_all" },
  "hint_text": "點上方的粉紅箭頭",
  "hint_highlight": "粉紅",
  "hint_highlight_color": "#FF6B9D"
}
```

### 欄位

| 欄位 | 說明 |
|------|------|
| `width` / `height` | 棋盤寬高 |
| `yellow_cross` | `plus`：以 `col`/`row`（或 `cx`/`cy`）畫十字通道；也可 `cells` 補點 |
| `walls` | 固定牆 |
| `pieces` | 積木；`cells` 為佔格；`color` 為 HTML 色碼 |
| `edge_arrows` | `side`=`top\|bottom\|left\|right`；`index` 為對應直欄 x 或橫列 y；`color` 閘口色；`dir` 目前僅 `out` |
| `goal.type` | 見下表 |
| `hint_text` / `hint_highlight` / `hint_highlight_color` | 頂部提示與高亮詞 |

### `goal.type`

| type | 參數 | 意義 |
|------|------|------|
| `clear_all` | — | 清空所有積木 |
| `clear_color` | `color` | 指定色全部出清即可（其他色可留） |
| `reach_cross` | `color`（可空=任意） | 指定色任一格踩上黃十字 |
| `sort_quadrants` | `quadrants`：`{tl,tr,bl,br}`→色碼 | 黃通道上不可留塊；每象限至多一種色；有寫到的象限必須為該色 |
| `combined` | `clear_colors`[]、`sort_quadrants`{} | 先滿足出清色，再滿足象限歸位 |

新增關卡後，在 `scripts/GameState.gd` 更新 `LEVEL_COUNT` 與 `LEVEL_PATHS`。

## 場景流程

主選單 → 選關 → 遊戲 → 通關 → 下一關／選關／主選單

## 網頁版（GitHub Pages）

- **遊玩網址**：https://guobin6910-cell.github.io/sekuai-chuqing/
- GitHub Actions：Godot 4.3 **單執行緒** Web 預設匯出並部署 Pages
- 預設名 `Web`，路徑 `build/web/index.html`
- 觸發：推送 `main`（或 `feature/sekuai-chuqing-mvp`）、`workflow_dispatch`

單執行緒可避免 SharedArrayBuffer／COOP-COEP，較相容 iOS Safari。

### iOS Safari

1. Safari 開啟上述網址（建議直向）。
2. 可「加入主畫面」。
3. 首次載入需下載 WASM；若空白可強制重新整理。

### 本機匯出

1. 安裝 Godot 4.3 Export Templates。
2. 匯出「Web」（`variant/thread_support=false`）至 `build/web/index.html`。

## 授權

專案程式、關卡與程序美術為原創內容；請依倉庫授權使用。
