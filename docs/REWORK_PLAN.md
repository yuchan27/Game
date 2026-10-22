# GAME — Wasteland Roguelike AAA-Quality Rework Plan (`REWORK_PLAN.md`)

## 0. 專案接管與基線盤點摘要 (Executive Summary)

本文件為 **《廢土回收商 (Wasteland Recycler)》**（Godot 4.6.3 專案，位於 `C:\Code\Game\first-game`）之全面重製與品質升級計畫。
在修改任何程式碼與美術資產前，已完成既有專案、Git 工作樹、自動化測試與所有美術資產的完整盤點，完全保留 Codex 在 `codex/modernize-wasteland` 分支上的未提交修改（包含音訊副檔名修正、新增碰撞/玩法回歸測試與 4 張擴充地標物件圖）。

---

## 1. 多模型協作架構與平台實際調度記錄 (Multi-Model Agent Architecture)

### 1.1 平台能力檢查結果
經檢查目前 Antigravity 執行環境之工具定義 (`invoke_subagent` / `define_subagent`)：
- **支援功能**：
  - 支援建立自訂角色 Subagent (`define_subagent`：`art-director`、`lead-developer`、`qa-engineer`) 以及內建 Subagent (`self`、`research`、`image-generator`)。
  - 支援多個 Subagent 並行執行與背景非同步通知。
  - 支援透過共享工作區 (`inherit` workspace) 與訊息傳遞 (`send_message`) 共享任務成果。
  - 支援透過 `image-generator` 實際生成圖片檔案，並搭配 Python (`.godot/qa-venv`, Pillow 11.x) 進行像素化後處理、去背、色盤對齊與 Atlas 組裝。
  - 支援讀取並遵循 `.agents/skills/` 下之所有既有 Skills (`godot-development`, `godot-safe-refactor`, `godot-testing`, `godot-visual-review`)。
- **模型指定限制與誠實揭露**：
  - `invoke_subagent` 的 `Model` 參數僅支援枚舉值 `['inherit', 'flash_lite', 'flash', 'pro']`，不接受外部模型字串（如 `Claude Opus 5.5`、`Claude Sonnet 5.5`、`Gemini 3.8`）。
  - 依據最高指令第 1.1 節規範（「如果無法直接指定模型，不得假裝已使用指定模型。請改採獨立 Agent Session 或目前平台實際支援的模型切換機制，並記錄每項工作的實際執行模型」），本專案透過角色化 Subagent 分工與主控 Orchestrator 協作執行，並於下表誠實記錄每項角色與工作的**實際執行模型**：

| 規劃角色 | 職責範圍 | 調度機制 / Subagent | 實際執行模型 (Actual Model) |
|---|---|---|---|
| **Game Director / Chief Architect** | 核心架構決策、Phase 0~8 任務拆解、跨系統整合、最終品質驗收 | 主控 Agent Session | **Gemini 4 Argon** (`inherit`) |
| **Art Director / UI/UX Director** | 制定 `ART_BIBLE.md`、`ANIMATION_SPEC.md`、`BIOME_DESIGN.md`、`UI_DESIGN_SYSTEM.md`；主角 3 組概念設計、8 方向動畫規範、美術風格審查 | `art-director` Subagent + `image-generator` Subagent + 主控審核 | **Gemini 4 Argon** (`pro` / `inherit`) + **image-generator** |
| **Lead Developer** | 整合美術資產、8 方向動畫與武器掛載、近戰/遠程武器系統、Biome 程序化生成與危害機制、UI/UX 重構、戰鬥物理與打擊感、音效與特效 | `lead-developer` Subagent + 主控開發整合 | **Gemini 4 Argon** (`pro` / `inherit`) |
| **Supporting Developer / QA** | 掃描資產清單 (`ASSET_INVENTORY.md`)、檢查圖片尺寸/Alpha/雜訊、執行 `validate_project_data.py` / `verify_visual_assets.py` / `run_qa.py`、產出 `QA_REPORT.md` | `qa-engineer` Subagent + 背景測試任務 | **Gemini 4 Argon** (`flash` / `inherit`) |

---

## 2. Phase 0 — 既有專案與技術債分析 (Baseline & Technical Debt Analysis)

### 2.1 Git 與工作樹狀態
- **目前分支**：`codex/modernize-wasteland`（基底 Commit：`a788d45`）
- **未提交修改（完整保留，不重置、不覆蓋）**：
  - 音訊修正：`assets/audio/bgm_boss.mp3`、`assets/audio/bgm_camp.mp3`、`assets/audio/sfx_player_death.mp3`（修正原本 `.wav` 實為 MP3 格式的問題）及 `AudioManager.gd` 路徑更新。
  - 測試與工具擴充：`CollisionRegressionRunner.gd`、`GameplayRegressionRunner.gd`、`run_qa.py`、`validate_project_data.py`。
  - 擴充地標素材：`assets/sprites/props/expanded/{highway_overpass_pillar,marsh_vat_cluster,scar_monolith_cluster,factory_gantry_arch}.png`。

### 2.2 既有架構概覽
- **引擎版本**：Godot `4.6.3.stable.official.7d41c59c4`（渲染器：`gl_compatibility`，視窗 `1280x720`，`canvas_items` 縮放）。
- **五大 Autoload 單例**：
  1. `GameState` (`scripts/autoload/GameState.gd`)：玩家生命、體力、資源、背包、裝備、武器冷卻、任務、世界地圖與難度狀態。
  2. `DataRegistry` (`scripts/autoload/DataRegistry.gd`)：載入 `data/` 下之裝備、配方、敵人、廢土路線、生成參數、任務與視覺資產清單。
  3. `AudioManager` (`scripts/autoload/AudioManager.gd`)：管理 BGM 與 SFX 播放、合成備援音效 (`AudioStreamWAV`) 與節流冷卻。
  4. `SaveManager` (`scripts/autoload/SaveManager.gd`)：JSON 存讀檔與測試隔離路徑支援。
  5. `SceneRouter` (`scripts/autoload/SceneRouter.gd`)：場景切換與開場故事面板。
- **核心場景**：
  - `Main.tscn` (`Main.gd`)：頂層容器、載入畫面、開場故事、死亡畫面、暫停選單、設定面板與世界地圖 (`WorldMapView.gd`)。
  - `Village.tscn` (`Village.gd`)：據點安全區、6 座功能建築、3 位對話 NPC、前往冒險者公會與廢土路線閘門。
  - `Guild.tscn` (`Guild.gd`)：冒險者公會室內場景、委託布告欄、4 位公會 NPC。
  - `Wasteland.tscn` (`Wasteland.gd` + `LevelGenerator.gd` + `WorldBackdrop.gd`)：野外探索與戰鬥場景、程序化物件與敵人生成、Boss 戰與撤離點。
  - `Player.tscn` (`Player.gd`)：8 方向動畫播放、移動、近戰/遠程攻擊、採集/回收、閃避/技能、互動。
  - `HUD.tscn` (`HUD.gd`)：生命/體力、快捷欄、準星、小地圖、裝備與背包面板、合成/鍛造/商店/改裝/回收面板、對話框與教學面板。

### 2.3 現存核心問題與技術債（必須解決）
1. **美術資產嚴重瑕疵 (P0)**：
   - **人為色塊污染 (`add_unique_badge`)**：`generate_formal_visual_assets.py` 為了通過 SHA-256 唯一性檢查，在所有據點建築 (`forge.png`、`craft.png` 等) 與 NPC (`forge_master.png` 等) 右下角直接畫上不透明純色方塊！
   - **去背殘留與切割錯誤**：`extract_reference_sheet_assets.py` 切割出的 `forge.png` 頂部殘留上一排地板切片與白邊孔洞；`polluted_enemy_six_types.png` 頂部亦殘留背景碎片。
   - **地面貼圖損毀**：`village_ground_variants_2p5d.png` 與 `wasteland_ground_variants_2p5d.png` 被畫上白色方塊與圓點，且 `VillageTileMap.gd` 繞過了正式貼圖改用純色方塊拼接。
   - **裝備圖示風格割裂**：`assets/sprites/items/armor/{初階,中階,高階}.png` 為 1024×1024 白底寫實 3D 渲染圖，與像素風完全不符。
2. **主角 Sprite Sheet 與動畫問題 (P0)**：
   - 現有 `recycler_player_multiaction_8dir_preview.png` (`8064x1024`) 的後向三列（`up_left`, `up`, `up_right`，即 `NW, N, NE`）在 `walk`、`shoot`、`draw_sword`、`slash`、`swap_tool`、`interact` 動作中**完全靜止無動作變化**（所有影格與第 0 格相同）！
   - `hit` 動作在多個方向的影格中出現整塊粉紅/紅色半透明方塊背景污染。
   - `Player.gd` 中將 `weapon_sprite.visible = false` 強制關閉，且將 `AttackFlash` 限制為僅 `scan_pulse` 顯示，導致切換不同武器時角色外觀與揮砍弧光毫無變化。
3. **野外地圖與 Biome 相似度過高 (P1)**：
   - `WorldBackdrop.gd` 對所有路線皆使用相同的正弦波單一路径與純色方塊，缺乏真實地形輪廓、掩體拓撲、環境危害（毒沼、輻射區、高溫蒸汽/感電區、晶簇脈衝）、Boss 專屬競技場結構與 Seed 重現機制。
4. **戰鬥深度、武器多樣性與手感不足 (P1)**：
   - 武器種類僅有基礎 3 階近戰/遠程/採集，缺乏不同近戰武器類型（刀、砍刀、劍、斧、錘、長矛、鏈鋸）與遠程武器類型（手槍、左輪、衝鋒槍、步槍、霰彈槍、狙擊槍、十字弓、能量武器、爆裂物）的差異化攻速、範圍、擊退、彈道、裝填與等級成長。
   - 缺乏主動閃避翻滾 (Dodge / Roll with i-frames)、受擊硬直保護、精確的 Hitbox / Hurtbox 分離、武器後座力、彈殼拋射與多層次打擊特效。
5. **UI/UX 與 Roguelike 局內成長體驗 (P1)**：
   - 缺乏統一的廢土像素 UI 設計系統（金屬鏽蝕邊框、清楚的狀態指示、武器 HUD 彈藥/裝填顯示、Roguelike 局內升級三選一面板、清楚的傷害指示與勝利結算畫面）。

---

## 3. 執行順序與階段規劃 (Execution Phases)

### Phase 0 — 專案盤點與基線建立 (已完成)
- 產出 `docs/REWORK_PLAN.md`（本文件）與 `docs/ASSET_INVENTORY.md`。
- 執行基線自動化測試套件 (`run_qa.py --profile all`) 並記錄初始狀態。

### Phase 1 — Art Bible 與美術資產全面重製 (P0)
- 建立 `docs/ART_BIBLE.md`：定義廢土像素風規範（Pixel Density、左上 45° 主光源、色盤規範、Sprite 尺寸、材質、UI 視覺語言）。
- 修復並重製所有受損資產：
  - 移除建築與 NPC 的人為純色方塊與白邊殘留，重新生成高品質像素風據點建築、NPC、敵人與地面 Tile。
  - 重製護甲、武器、模組、消耗品與材料的像素風圖示（統一透明背景、清晰輪廓）。
  - 擴充各 Biome 專屬環境地標、掩體與危險區域貼圖。

### Phase 2 — 主角全面重設與 8 方向多動作 Sprite 系統 (P0)
- 產出 3 組主角概念設計（Concept A：重裝廢土工程師、Concept B：機動荒原遊俠 R-17 進化版、Concept C：生化淨化獵人），經比較後選出最佳方案並記錄於 `docs/ART_BIBLE.md` 與 `docs/ANIMATION_SPEC.md`。
- 重建完整 8 方向 (`E, SE, S, SW, W, NW, N, NE`) × 多動作主角 Sprite Atlas (`8064x1024` 正式版 + 擴充狀態支援)：
  - 確保每一個方向（特別是原本靜止的 `NW, N, NE`）皆具備真實的肢體擺動、步伐位移、持武透視與背包/披風層次，絕不單純水平翻轉敷衍。
  - 清除所有 `hit` 影格的背景色塊污染。
- 啟用並升級獨立武器掛載層 (`WeaponOverlay`) 與方向性揮砍/射擊特效層，支援不同武器外觀與等級視覺變化。

### Phase 3 — 地圖與 Biome 全面重設 (P1)
- 建立 `docs/BIOME_DESIGN.md`，規劃並實作 6 大差異化廢土生態域（保留既有 4 條主線路線 ID 以相容存檔與任務，並擴充 2 條高階路線或深度子區域機制）：
  1. **廢鐵幹道 (`scrap_highway` — Ashen Wasteland / Ruined Highway)**：灰燼荒原、高架橋斷柱、廢棄車隊掩體、塵暴視野變化。
  2. **毒霧沼澤 (`toxic_marsh` — Toxic Marsh)**：腐蝕毒池（持續緩速與中毒危害）、變異菌叢、木棧道與反應槽。
  3. **晶簇裂谷 (`crystal_scar` — Radiation Crystal Desert)**：輻射沙丘、高能晶簇脈衝帶（定時能量爆發）、礦道裂隙。
  4. **舊工業區 (`old_factory` — Abandoned Industrial Zone)**：重工管線、高溫蒸汽噴口、感電地板、工廠龍門架與熔爐 Boss 競技場。
  5. **崩塌都會 (`ruined_metropolis` — Ruined Metropolis)**：都市廢墟、倒塌高樓殘骸、十字路口伏擊區。
  6. **地下研究設施 (`underground_facility` — Underground Facility)**：封閉實驗室通道、培養艙群、高危保安防禦塔與終極污染核心。
- 重構 `LevelGenerator.gd`、`WorldBackdrop.gd` 與 `Wasteland.gd`：
  - 引入 **Seed-based Generation**（支援固定 Seed 重現與隨機種子顯示）。
  - 加入房間/區域拓撲（起點安全緩衝區、探索資源區、掩體交戰區、環境危險區、Boss Arena 與撤離點），確保路徑連通不卡死。

### Phase 4 — UI/UX 全面重構 (P1)
- 建立 `docs/UI_DESIGN_SYSTEM.md`。
- 升級 `Main.gd`、`HUD.gd` 與 `WorldMapView.gd`：
  - 廢土像素風主題樣式（高對比資訊層級、Hover/Pressed/Disabled/Selected 狀態、按鈕音效回饋）。
  - 強化戰鬥 HUD：生命值、護盾/減傷、體力/閃避冷卻、武器 HUD（目前武器圖示、等級、彈藥/熱量、裝填進度條）、小地圖（顯示地形、敵人、Boss、撤離點與 Seed）、低血量危險警示與受擊方向指示。
  - 新增 **Roguelike 局內戰術升級選擇面板 (Tactical Upgrade Selection)**：擊敗菁英/清理波次或累積廢土經驗時可三選一強化。
  - 完善死亡結算畫面与新增 **勝利撤離結算畫面 (Victory Screen)**。
  - 嚴格保留所有既有測試契約要求的 Node Groups (`hotbar_slot`, `minimap_panel`, `tutorial_panel`, `equipment_panel`, `dialogue_panel`, `gameplay_input_blocker`)。

### Phase 5 — 武器多樣性與等級設計 (P1)
- 擴充 `data/items/equipment.json` 與 `data/items/recipes.json`：
  - **近戰武器家族**：戰術短刀 (Knife)、廢土砍刀 (Machete)、高頻戰劍 (Sword)、破甲戰斧 (Axe)、重型震地錘 (Hammer)、高壓長矛 (Spear)、動力鏈鋸 (Chainsaw)。
  - **遠程武器家族**：廢鐵手槍 (Pistol)、大口徑左輪 (Revolver)、連發衝鋒槍 (SMG)、制式突擊步槍 (Assault Rifle)、雙管霰彈槍 (Shotgun)、電磁狙擊槍 (Sniper Rifle)、穿甲十字弓 (Crossbow)、電漿脈衝槍 (Energy Weapon)、榴彈發射器 (Explosive Weapon)。
- 實作武器等級系統 (`Lv.1 ~ Lv.5`)：
  - 支援在鍛造台/改裝台強化武器等級，提升基礎傷害、攻速/暴擊、解鎖被動詞條，並改變武器色澤/发光特效與揮砍/彈道視覺。

### Phase 6 — 戰鬥動作、碰撞、物理與打擊感 (P1)
- 重構 `Player.gd`、`Enemy.gd`、`Projectile.gd` 與 `AttackFlash.gd`：
  - **閃避翻滾 (Dodge / Roll)**：`Space` / `Shift` 觸發方向性翻滾衝刺、無敵幀 (i-frames)、殘影特效與體力消耗。
  - **精確攻擊三階段**：Anticipation（前搖預備）→ Active Frames（揮砍弧光/彈道判定）→ Recovery（後搖收招）。
  - **遠程射擊細節**：槍口火光 (Muzzle Flash)、彈道軌跡 (Bullet Trail)、拋殼特效 (Shell Ejection)、後座力微震與裝填動作 (Reload)。
  - **Hitbox / Hurtbox 與物理碰撞**：分離環境碰撞 (`collision_layer/mask`) 與傷害判定，擊退位移具備牆體安全碰撞檢測（絕不把敵人或玩家推入牆內）。
  - **打擊回饋**：Hit-stop（命中頓幀）、Camera Shake（分級鏡頭震動）、敵人受擊閃白 (Hit Flash)、暴擊放大傷害跳字与死屍擊飛消散特效。

### Phase 7 — 音效與特效系統強化 (P2)
- 升級 `AudioManager.gd`：
  - 為不同地面材質腳步聲、各類近戰揮砍、各類槍械射擊、裝填、受擊、閃避、UI 互動與環境氛圍提供差異化音效（結合外部音訊與高品質程序化波形合成器，並實作 Polyphony 上限與 Pitch 隨機微調防爆音）。

### Phase 8 — 全面測試、視覺檢查與效能驗收 (P0 Gate)
- 執行 `validate_project_data.py`、`verify_visual_assets.py` 與 `run_qa.py --profile all`。
- 逐一檢視所有自動化擷取之視覺審查截圖（涵蓋據點、公會、各 Biome、戰鬥、閃避、UI 面板、死亡/勝利畫面、不同解析度）。
- 撰寫 `docs/QA_REPORT.md`，並更新 `docs/RELEASE_READINESS.md` 與 `AI_HANDOFF.md`。
