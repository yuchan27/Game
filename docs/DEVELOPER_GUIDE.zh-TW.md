# 開發導讀

這份文件協助繁體中文開發者理解專案；英文 `AGENTS.md` 與 `WORKFLOW.md`
是技術規範來源。若翻譯有落差，修正翻譯，不維護另一套規則。

## 從哪裡開始

真正的 Git 與 Godot 根目錄都是 `first-game/`。先讀交接文件，再確認工作樹、
分支、引擎版本與需要修改的程式。遊戲已具備標題、序章、村莊、公會、六路線、
敵人與 Boss、裝備、任務、存檔等系統，應在既有架構增量改進。

| 用詞 | 英文 | 專案位置 |
| --- | --- | --- |
| 玩家／回收機器人 | Player / R-17 | `scenes/player/Player.gd` |
| 全域狀態 | GameState | `scripts/autoload/GameState.gd` |
| 資料登錄 | DataRegistry | `scripts/autoload/DataRegistry.gd` |
| 存檔／場景路由 | SaveManager / SceneRouter | `scripts/autoload/` |
| 委託／任務目標 | Contract / Objective | `data/maps/quests.json` |
| 路線 | Route | `data/maps/wasteland_routes.json` |
| 圖集／拆分幀 | Atlas / Split frame | `assets/sprites/player/` |
| 自動驗證／畫面檢查 | QA / Visual review | `scripts/tests/` |

所有玩家文字使用繁體中文。技術規範與 commit 使用英文；對話與任務文案應沿用
「廢鐵、彈藥、異變核心、污染晶核、委託、回報」等資料中的名稱。

## 安全驗證

建立 `.godot/qa-venv` 並安裝根目錄 `requirements-qa.txt`。取得 Godot console
執行檔後，先執行 `--version` 確認 4.6.3，再使用 README 的 `run_qa.py` 命令。
工具會顯示隔離輸出資料夾；日誌、JSON 報告與 PNG 均可追查。不要直接對玩家
存檔執行會寫入的測試，也不要把素材生成工具當成測試。

- `core`：資料／素材完整性、引擎載入、既有驗證器與遊玩／回歸測試。
- `visual`：以真正繪圖後端截圖，之後必須開圖檢查。
- `performance`：物件池與實際場景效能樣本；物理幀節奏不等於渲染 FPS。
- `all`：交付前整合檢查；不能取代人工遊玩與發行包驗證。

只改文件時，檢查內容、連結與 Skill YAML 即可，不必重跑整款遊戲。
失敗或不可用的項目要明說，不能標示 Passed；受影響的必要驗證失敗時不得 commit。

## 使用 Skills

四個專案 Skill 位於 `.agents/skills/`，可用 `$godot-development`、
`$godot-testing`、`$godot-visual-review`、`$godot-safe-refactor` 指定。
它們分別處理功能實作、驗證診斷、視覺檢查、相容性重構，詳細步驟按需載入。

2026-10-21 確認本機 CLI 為 `0.163.0-alpha.10.2`；依
[官方 Skill 文件](https://learn.chatgpt.com/docs/build-skills)，Codex 從工作目錄
到 Git 根目錄搜尋 `.agents/skills`，YAML 至少需要 `name` 與 `description`。
本對話起始工作目錄是上層 `Game/`，因此重新以 `first-game/` 為工作目錄啟動，
或明確讀取／指定這四個 Skill，才能以專案範圍發現它們。已透過本機 app-server 的 `skills/list` 確認四個 Skill
皆為 `scope=repo`、`enabled=true`；Skill Creator 的 UTF-8 frontmatter 驗證也全部通過。
資料驗證器會持續檢查 frontmatter。

## 交接與目前限制

`AI_HANDOFF.md` 只保留當前摘要；稽核保留起始證據，最新結果集中於
`docs/RELEASE_READINESS.md`，未來工作在 `docs/GAMEPLAY_ROADMAP.md`。
路線遭遇目前進場重置；背包沒有容量限制。這些是明列的產品決策空白，不應
在小型修復中擅自改變存檔格式或物品取得規則。禁止遞迴刪除、覆蓋使用者資產、
丟棄未提交內容、改寫 Git 歷史與未經明確要求的 push。
