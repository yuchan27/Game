# SRS Traceability 對照表

| SRS / 設計需求 | 目前實作對照 |
| --- | --- |
| Godot 4.x 2D Roguelike vertical slice | `project.godot` 使用 Godot 4.6.3，流程包含標題、村莊、公會、四方向廢土、戰鬥、掉落、任務、裝備、地圖與存檔。 |
| 像素風偽 3D / 2.5D | `WorldBackdrop.gd`、Y-sort、建築 / props PNG、底部碰撞與道路地形色彩提供偽 3D 層次。 |
| 主角為回收機器人 | `recycler_player_multiaction_8dir_preview.png` 由 `docs/art_direction_reference_r17_full_body.png` 建立全身原創 R-17，不再使用人類角色疊機器人外殼。 |
| 主角 8 方向 | `Player.gd` 與 player atlas 使用 8 方向 row：右、右下、下、左下、左、左上、上、右上。 |
| 主角多動作 | Atlas 支援 `idle`、`walk`、`shoot`、`draw_sword`、`slash`、`swap_tool`、`interact`、`hit`、`dead`，單格 `112x128`、每動作 8 幀、總尺寸 `8064x1024`。 |
| PC 操作 | `GameState._ensure_input_actions()` 設定 WASD、滑鼠左鍵、右鍵、空白鍵、Tab/I、H、M、F5/F9、1-4、Q。 |
| 左鍵依裝備決定動作 | `GameState.active_attack_mode()` 與 `Player._primary_attack_pressed()` 依目前快捷裝備切換近戰或射擊。 |
| 滑鼠瞄準射擊 | `Player._aim_direction()` 讀取滑鼠方向，遠程武器播放射擊動畫並建立 projectile。 |
| 村莊整備 | `Village.gd` 建立鍛造、合成、商店、改裝、回收、存檔、醫療、公會與四方向廢土出口。 |
| 冒險公會 | `Guild.gd` 建立委託板、櫃員、路線斥候、獎勵櫃台與回村 / 出村流程。 |
| 四張廢土地圖 | `data/maps/wasteland_routes.json` 與 `Wasteland.gd` 依 route id 生成南門廢鐵公路、西門毒沼排水區、北門紫晶裂隙、東門舊工廠外圍。 |
| 地圖道路與地標 | `WorldBackdrop.gd` 依 tile theme 產生荒土、破柏油、毒泥、晶體與工廠地形；`Wasteland.gd` 放置路障、晶體、毒池、車骸、信號塔與出口。 |
| NPC 指引 | `data/maps/npcs.json` 提供鍛造師、補給商、維修機、倖存者、公會櫃員、路線斥候的繁中對話。 |
| NPC 一次性獎勵 | `GameState.talk_to_npc()` 使用 `talked_npcs` 記錄已對話 NPC，第一次給獎勵，之後不重複。 |
| 正式對話框 | `HUD.gd` 顯示 NPC 頭像、名稱、職業、對話內容與 E / Esc 提示；`DialogueNpc.gd` 在玩家離開時關閉對話。 |
| 人物裝備面板 | `HUD.gd` 的 `InventoryPanel` 顯示 R-17 預覽、裝備槽、目前左鍵動作、屬性加成與背包格。 |
| 小地圖 / 全屏地圖 | `WorldMapView.gd` 掃描 `map_player`、`map_npc`、`map_station`、`map_gate`、`map_pickup`、`map_enemy`、`map_boss`、`map_prop`、`map_event`，支援小地圖與全屏地圖。 |
| 裝備與資源資料驅動 | `equipment.json`、`recipes.json`、`InventorySystem.gd`、`GameState.gd` 管理武器、護甲、工具、資源、合成與裝備。 |
| 獨立正式素材 | `data/art/visual_assets.json` 統一宣告 player、NPC、structures、items、props、enemies、Boss 的正式 PNG 與 minimap marker。 |
| 掉落物樣式 | `Pickup.gd` 使用 `icon_asset_id` 載入對應 icon，使用現有 64px 圖示與碰撞回收，保持靜態掉落表現。 |
| 敵人與 Boss | `enemies.json` 定義近戰、快速、遠程、重型、飛行、混合型與 Boss；`Enemy.gd` 提供 AI、受擊、血條、傷害數字、死亡與掉落。 |
| 戰鬥回饋 | `DamagePopup.gd`、`EnemyHealthBar.gd`、`HitEffect.gd` 與 `Enemy.gd` 顯示傷害、血條、污染液 / 火花與死亡淡出。 |
| 任務 | `quests.json` 提供擊殺、收集、路線探索與 Boss / 精英相關獎勵。 |
| 存檔 / 讀檔 | `SaveManager.gd` 使用 `user://save_game.json`，保存 Base64 payload + SHA-256 checksum，包含場景、路線、背包、裝備、NPC 獎勵與任務進度。 |
| 開場導入 | `Main.gd` 在新遊戲播放 R-17 甦醒與污染清理背景導入。 |
| 場景切換安全 | `SceneRouter.gd` 使用 deferred scene change，避免 physics callback 內直接移除 CollisionObject。 |
| 自動驗證 | `ValidationRunner.tscn`、`AutomatedPlaytestRunner.tscn`、`VisualReviewRunner.tscn` 與 `verify_visual_assets.py` 驗證資料、素材、流程與視覺截圖。 |

## 尚未完全覆蓋的需求

- NPC、敵人與 Boss 還需要更完整的逐格攻擊 / 工作 / 階段動畫。
- 音樂與音效仍需正式混音與授權檢查。
- 上架前需要更多路線事件、Boss 招式、關卡節點與人工美術精修。
