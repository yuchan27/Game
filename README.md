# 廢土回收商 Wasteland Recycler

Godot 4.6.3 製作的 PC 像素風偽 3D 單機 Roguelike 可玩片段。操作原創
回收機器人 R-17，在村莊整備、公會接委託，前往四條廢土路線戰鬥與回收，
返回村莊交付任務、合成、升級並保存進度。

以 Godot 4.6.3 開啟此目錄的 `project.godot` 後執行。先用執行檔的
`--version` 確認版本；命令列可用 `--path <此專案目錄>` 啟動。
目前以 Windows 鍵盤滑鼠為主，沒有啟用手機觸控介面。

## 操作

- WASD 移動；Shift 衝刺並消耗 EP。
- 滑鼠瞄準；左鍵依目前裝備近戰或射擊。
- 1–4 快捷裝備；Q 切換；Tab／I 開關人物裝備面板。
- E 與附近目標互動／推進對話；M 地圖；H 教學。
- Esc 關閉面板／暫停選單；F5 存檔、F9 讀檔。

R-17 使用現有 9 動作 × 8 方向 × 8 幀 atlas；保留目前正式角色圖像。
四路線共用資料驅動場景；回到路線會重新生成遭遇，背包資源目前沒有容量上限。

## 開發與驗證

[繁體中文開發導讀](docs/DEVELOPER_GUIDE.zh-TW.md) 說明環境、文件與驗證方式。
[AGENTS.md](AGENTS.md) 是英文技術規範唯一入口；[WORKFLOW.md](WORKFLOW.md)
定義開發流程；[AI_HANDOFF.md](AI_HANDOFF.md) 保存目前狀態。

```powershell
python -m venv .godot/qa-venv
& .godot/qa-venv/Scripts/python.exe -m pip install -r requirements-qa.txt
# 將 GODOT_BIN 設成已確認的 Godot 4.6.3 console 執行檔完整路徑
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile core
```

`visual` 執行實際繪圖截圖；`performance` 蒐集效能樣本；`all` 執行整合驗證。
QA 在隔離副本／存檔環境執行，輸出目錄由工具顯示；不重建素材、不覆寫玩家存檔。
視覺檢查需要可用的桌面與繪圖驅動；headless 不能驗收畫面。

[專案稽核](docs/PROJECT_AUDIT.md)、[優先路線圖](docs/GAMEPLAY_ROADMAP.md)、
[驗證與發行狀態](docs/RELEASE_READINESS.md)、[人工驗收](docs/PLAYTEST_CHECKLIST.md)
提供證據與尚未完成項目。測試通過不等於已完成發行包或人工全流程驗收。

素材生成腳本是有意修改美術的製作工具，不能當作例行驗證；目前核准的素材不應
自動重建。提交前檢查實際 diff；禁止自動 push。
