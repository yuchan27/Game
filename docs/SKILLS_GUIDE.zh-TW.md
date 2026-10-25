# 專案 Skills 導讀

`AGENTS.md` 是技術規範入口；本頁只協助找到重複使用的工作流程。

| Skill | 用途 |
| --- | --- |
| godot-development | 遊戲功能、資料與介面整合 |
| godot-2p5d-pixel-art-and-animation | 像素素材比例、方向、握持與動作製作 |
| godot-audio-and-voice-pipeline | 音效、音樂與對白素材 |
| godot-visual-review | 實際畫面、美術與排版審閱 |
| godot-testing | 需要驗證時使用既有隔離執行器 |
| godot-safe-refactor | 保留現有行為與資料相容性的整理 |

先讀 `.agents/skills/<name>/SKILL.md`，再按需要讀其中參考文件。
技能是否自動被發現依所用工具而定，不宣稱其他 AI 工具都會自動載入。

目前完整專案目標要求依風險執行隔離驗證與實際畫面審閱。沿用
`scripts/tools/run_qa.py` 的外部輸出與隔離存檔；舊報告只代表其來源快照，
不能當成目前結果。

更新素材後使用 Godot 正常匯入或外部隔離副本。已移除舊的批量清空快取工具；
不要刪除 `.godot/` 或自動執行全素材重建。舊版生成腳本可能覆蓋現有圖片，
必須先確認來源與本次製作目標。

美術規格見 `art-direction/README.md`、`ART_AND_COMBAT_REDESIGN_PLAN.md`；
遊戲規則與玩家故事見 `GAME_DESIGN.md`，實作狀態見 `AI_HANDOFF.md`。
