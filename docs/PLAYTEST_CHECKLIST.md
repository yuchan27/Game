# 廢土回收商 PC Playtest Checklist

## 自動驗證

```powershell
# 從專案根目錄，以已確認的 Godot 4.6.3 執行；詳見 README 環境設定
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile core
```

素材生成／PixelAssetBaker 會修改素材，不能當作例行測試。QA 應使用隔離副本與存檔。

最新完整隔離 `visual` profile 為 `20261025T020943Z-87d60cad`，共 29/29 launcher 步驟、
77 張截圖／320 項畫面檢查；另有 800x600 候選視窗冷啟動 11/11 張截圖、53/53 項畫面檢查。
它沒有驗證真正支援的最小尺寸、Windows 匯出或效能改善。詳細來源與限制見 `docs/QA_REPORT.md`。

2026-10-25 直接執行 `AutomatedPlaytestRunner` 通過 165/165：接受公會委託後，測試器建立
`scrap_highway` 場景，從正式地圖出生點步行到護送對象，沿路走到中繼站完成修理，再按道路
走到實體返村閘並以 E 啟動結算。這次通過也包含目前 J 委託頁的鍵盤捲動與詳情展開。
測試期間敵人被隔離、世界補怪處理暫停；閘門真實互動訊號有觸發，但 SceneRouter 被刻意設為
不替換測試場景，隨後由測試器呼叫結算 API；後續 Guild 交付使用完成進度 fixture。這不是
完整玩家旅程或完整 QA profile。未驗證真正從村莊走到出口、返村場景切換、未佈置的交付、
沿途活體戰鬥或完整主線。報告位置見 `docs/QA_REPORT.md`。自動結果不取代下方人工驗收。

2026-10-25 Chapter 2 GUI journey `20261025T025900Z-rerun` passed 50/50 checks:
two authored outings, physical actions and extractions, Village/Guild return,
required-objective and optional-ledger readiness without disclosing the result,
exact reward, isolated checksummed save reload, and duplicate-reward prevention.
It selected the purge-air choice; the settle-sample choice remains untested. This
automated journey is not human pacing or six-chapter campaign acceptance. The
current driver-metadata correction and Chapter 4 optional-clue copy edit are not
included in that run.


## 主角動畫驗收

本次使用八方向、三組身體關鍵姿勢及 60 Hz 動作更新；不宣稱每方向有 60 張手繪圖。
詳細技術規則見 `PLAYER_MOTION.md`。

- [ ] 連續移動、急轉、斜向行走和持槍側移，步伐不會因轉向而重新開始。
- [ ] 移動射擊時滑鼠能持續瞄準；槍口、子彈與後座力位置一致。
- [ ] 近戰先起手再命中；提早按下一擊能銜接；受傷、閃避、死亡與開介面不會留下延遲傷害。
- [ ] 換刀、重武器、槍械的動作和手部對位清楚；八方向沒有倒置或不必要鏡像。
- [ ] G 世界紀行與 M 道路／區域名稱可讀，1024×768 下不裁切；進場動畫可跳過且恢復操作。
- [ ] 據點三名守衛清除後才能領獎，重讀存檔不重複領取；死亡期間不能拾取回血。

- 目前騎士優先使用 `assets/sprites/player/anim30/<loadout>/<action>.png`；核對實際 SpriteFrames 的八方向與 30 幀動作。舊 `frames/`、8 幀 atlas 與診斷圖是相容參考，不能代替目前執行畫面。
- 確認 R-17 沒有被切掉、沒有額外手臂、左右方向沒有反，揮砍時身高一致。
- `A` 移動時角色朝左，`D` 移動時角色朝右。
- 近戰與射擊動作應沿用目前角色圖像；若未啟用武器 overlay，不應出現浮空肢體或額外武器。
- 射擊方向、彈丸起點與滑鼠瞄準一致；以實際啟用的動作圖集驗收。

## 武器與掉落驗收

- 快捷列中的近戰、遠程、工具、彈藥 icon 都要是高細節風格，不可出現簡化積木圖。
- 怪物死亡後可掉落資源；部分怪物有低機率掉落武器或工具。
- Boss 擊敗後可掉落高階裝備。
- 撿到武器後按 `I` 開啟人物裝備面板，確認背包中有對應 icon，裝備後左鍵動作會改變。

## 戰鬥驗收

- 裝備近戰武器時，滑鼠左鍵只做近戰揮砍。
- 裝備遠程武器時，滑鼠左鍵射擊並消耗彈藥。
- 怪物受擊有傷害數字、血條、擊退或受擊閃光。
- 玩家受擊有畫面震動、受傷音效與 HP 變化。
- 玩家死亡時播放死亡表現，再回到修復艙或村莊流程，不可直接無提示重置。

## UI 驗收

- 按 `I` 開啟人物裝備面板時，小地圖、快捷提示與快捷列不可互相重疊；面板開啟時 `Tab` 應瀏覽焦點。
- `M` 可開關地圖，地圖顯示玩家、NPC、敵人、掉落物、建築與出口位置。
- NPC 只有靠近時顯示 `E` 互動提示；離開 NPC 範圍時對話框要自動關閉。
- 對話框固定在下方安全區，包含 NPC 頭像、名稱、職業、文字與按鍵提示。

## 場景驗收

- 村莊中央、六個出口、公會、鍛造、補給、維修、升級區位置清楚。
- 六區要有不同道路與色彩：廢鐵公路、毒沼排水區、紫晶裂隙、舊工廠、崩塌都心區、地底研究設施。地面不應用搶眼的大圖案掩蓋角色與線索。
- 建築與大型障礙物有底部碰撞，玩家不能穿過。
- Y-sort 正常，玩家靠近建築、晶體、樹、廢車時能形成前後遮擋層次。

## 手動視覺 Review

```powershell
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile visual
```

檢查 QA 輸出目錄 `artifacts/visual/` 內的 PNG：

- 村莊畫面。
- 六個廢土路線及 `story_site_*.png` 調查場景。
- Boss 區。
- 人物裝備面板。
- NPC 對話框。
- 戰鬥與掉落物。
- 小地圖與全螢幕地圖。

## 主線人工遊玩驗收（需實際遊玩後記錄結果）

- 新存檔依 J 的推薦完成六份核心主線；記錄每段旅行時間與不清楚的提示。
- 每區用 M 找事件標記，步行到線索前按 E；大型地標完整可見、調查點可達，附近物件不封住接近空間。
- K 手記未發現的線索只顯示提示；發現後可回看，重新啟動／讀檔仍保留。
- 閱讀線索與手記時戰鬥暫停，Esc 關閉、切換頁面及離開場景後可正常繼續。
- 都心／設施線索在前置任務未完成時不揭露結局，解鎖提示清楚。
- 舊工廠與設施 Boss 隨對應委託出現；確認彈藥、移動空間及招式預警合理。
- 終章獎勵只領一次；村莊出現淨水回流，艾達、艾倫、老陳的回應符合進度。
- 鍛造武器後存檔、完全退出、再讀檔，等級保留。舊存檔可載入。

自動測試和截圖可驗證狀態／版面；上述人工流程的節奏、情緒與平衡仍需玩家實際確認。
