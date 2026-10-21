# 廢土回收商 PC Playtest Checklist

## 自動驗證

```powershell
# 從專案根目錄，以已確認的 Godot 4.6.3 執行；詳見 README 環境設定
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile core
```

素材生成／PixelAssetBaker 會修改素材，不能當作例行測試。QA 應使用隔離副本與存檔。


## 主角拆分幀驗收

- 確認 `assets/sprites/player/frames/` 內每個動作都有 `dir_0` 到 `dir_7`，每個方向都有 `frame_0.png` 到 `frame_7.png`。
- 查看 `docs/player_split_frame_diagnostic.png`，確認 R-17 沒有被切掉、沒有額外手臂、左右方向沒有反。
- `A` 移動時角色朝左，`D` 移動時角色朝右。
- 近戰與射擊動作應沿用目前角色圖像；若未啟用武器 overlay，不應出現浮空肢體或額外武器。
- 射擊方向、彈丸起點與滑鼠瞄準一致；以實際啟用的動作圖集驗收。

## 武器與掉落驗收

- 快捷列中的近戰、遠程、工具、彈藥 icon 都要是高細節風格，不可出現簡化積木圖。
- 怪物死亡後可掉落資源；部分怪物有低機率掉落武器或工具。
- Boss 擊敗後可掉落高階裝備。
- 撿到武器後打開 `Tab` 人物裝備面板，確認背包中有對應 icon，裝備後左鍵動作會改變。

## 戰鬥驗收

- 裝備近戰武器時，滑鼠左鍵只做近戰揮砍。
- 裝備遠程武器時，滑鼠左鍵射擊並消耗彈藥。
- 怪物受擊有傷害數字、血條、擊退或受擊閃光。
- 玩家受擊有畫面震動、受傷音效與 HP 變化。
- 玩家死亡時播放死亡表現，再回到修復艙或村莊流程，不可直接無提示重置。

## UI 驗收

- `Tab / I` 開啟人物裝備面板時，小地圖、快捷提示與快捷列不可互相重疊。
- `M` 可開關地圖，地圖顯示玩家、NPC、敵人、掉落物、建築與出口位置。
- NPC 只有靠近時顯示 `E` 互動提示；離開 NPC 範圍時對話框要自動關閉。
- 對話框固定在下方安全區，包含 NPC 頭像、名稱、職業、文字與按鍵提示。

## 場景驗收

- 村莊中央、四方向出口、公會、鍛造、補給、維修、升級區位置清楚。
- 四張廢土路線要有不同道路語言與色彩：廢鐵公路、毒沼排水區、紫晶裂隙、舊工廠外圍。
- 建築與大型障礙物有底部碰撞，玩家不能穿過。
- Y-sort 正常，玩家靠近建築、晶體、樹、廢車時能形成前後遮擋層次。

## 手動視覺 Review

```powershell
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile visual
```

檢查 QA 輸出目錄中的 `visual_review_*.png`：

- 村莊畫面。
- 四個廢土路線。
- Boss 區。
- 人物裝備面板。
- NPC 對話框。
- 戰鬥與掉落物。
- 小地圖與全螢幕地圖。
