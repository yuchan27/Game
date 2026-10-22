# Asset Inventory & Quality Audit (`ASSET_INVENTORY.md`)

> **產生時間**：Phase 0 完整資產盤點
> **負責角色**：Supporting Developer / QA (`qa-engineer` / **Gemini 4 Argon**)

本文件完整盤點 `C:\Code\Game\first-game` 目前所有美術、音訊與視覺定義資產，並標註尺寸、透明度、品質狀態及本次 Rework 的處置方式（**Keep / Fix / Regenerate / Expand**）。

---

## 1. 主角資產 (`assets/sprites/player/` & `docs/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 動畫規格 | 現況品質審核与問題診斷 | 處置方案 |
|---|---|---|---|---|---|
| `docs/recycler_player_multiaction_8dir_preview.png` | `8064x1024` | RGBA | 8 方向 × 9 動作 × 8 影格（單格 `112x128`） | **部分嚴重瑕疵**：<br>1. `down_right`, `down`, `down_left`, `left`, `right` 方向有動作。<br>2. **`up_left`, `up`, `up_right` (列 5, 6, 7) 在 `walk`, `shoot`, `draw_sword`, `slash`, `swap_tool`, `interact` 完全靜止（8 格完全相同）！**<br>3. `hit` 動作在多個方向存在粉紅/紅色半透明矩形背景污染。 | **Regenerate & Fix (P0)**：設計 3 組概念後，重建完整 8 方向真動態 Atlas，補齊背面/斜背面所有肢體與武器動作，清除 `hit` 背景污染。 |
| `assets/sprites/player/recycler_player_8dir.png` | `896x1024` | RGBA | 8 方向 × 8 影格（單格 `112x128`） | 舊版單一動作綁定圖，與 `preview` 存在背面靜止問題。 | **Regenerate (P0)**：與主 Atlas 同步更新為高品質 8 方向基礎移動/待機圖集。 |
| `assets/sprites/player/actions/player_*.png` (9 張) | 各 `896x1024` | RGBA | `idle`, `walk`, `run`, `shoot`, `draw_sword`, `slash`, `swap_tool`, `interact`, `hit` | 由主 Atlas 切割之分動作圖集，同樣繼承背面 3 方向靜止與 `hit` 色塊問題。 | **Regenerate (P0)**：由重製後之乾淨主 Atlas 重新切割輸出，並擴充閃避/死亡/技能表現。 |
| `docs/art_direction_reference_r17_full_body.png` | `1024x1024` | RGB | 概念參考圖 | 角色 R-17 全身概念參考（綠斗篷、護目鏡、機械臂、回收背包）。 | **Keep (Reference)**：作為既有設定基底，並於 Phase 2 延伸產生 3 組升級概念比較圖。 |

---

## 2. 敵人與污染獸資產 (`assets/sprites/enemies/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 規格 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|---|---|
| `polluted_enemy_six_types.png` | `1344x768` | RGBA | 6 種敵人總覽 | **切割瑕疵**：頂部邊緣殘留上一排淺灰/白色背景與陰影碎片（高度約 18px），且部分邊緣有半透明白暈。 | **Fix & Regenerate (P0)**：清除頂部殘留碎片與白暈，強化 6 種污染獸與 Boss 的像素細節與發光核心對比。 |
| `enemy_1.png` ~ `enemy_5.png`, `boss.png` | 各 `384x96` | RGBA | 4 影格 × `96x96` | 單一水平方向 4 影格，尺寸偏小且缺乏攻擊/受擊張力與方向感。 | **Regenerate & Upgrade (P0)**：重製為高辨識度、無雜訊、具備呼吸/移動/攻擊動態的精緻廢土變異生物圖集。 |

---

## 3. 據點建築與環境推進物件 (`assets/sprites/structures/` & `assets/sprites/props/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|---|
| `structures/forge.png` | `560x420` | RGBA | **嚴重污染**：<br>1. 頂部殘留一整排淺色地板切片與破洞。<br>2. 右下角被 `add_unique_badge` 畫上不透明深灰+橘色方塊！ | **Regenerate / Clean (P0)**：徹底移除右下角人為方塊與頂部殘留切片，重繪精緻廢土鍛造爐像素建築。 |
| `structures/craft.png`, `shop.png`, `mod_station.png`, `recycle_machine.png`, `save_station.png` | `460x360` ~ `560x420` | RGBA | **嚴重污染**：全部在右下角被畫上不透明純色方塊 (`add_unique_badge`)，且原本只是將同一張底圖套用整張染色濾鏡！ | **Regenerate (P0)**：為每座功能建築設計真正獨立的像素結構外觀（工作台機械臂、黑市攤位遮雨棚、改裝精密儀器、回收粉碎機、基地通訊天線塔），移除所有純色補丁。 |
| `structures/guild_gate.png`, `wasteland_gate.png`, `route_gate.png`, `return_gate.png` | `420x250` ~ `520x320` | RGBA | 同樣帶有右下角人為純色方塊，且彼此僅為染色差異。 | **Regenerate (P0)**：重製各具辨識度的公會拱門、廢土裝甲閘門、路線路障與撤離信標。 |
| `props/expanded/{highway_overpass_pillar,marsh_vat_cluster,scar_monolith_cluster,factory_gantry_arch}.png` | `220x160` ~ `256x176` | RGBA | Codex 新增之 4 張地標物件，乾淨無方塊污染。 | **Keep & Polish (P1)**：保留並擴充更多 Biome 專屬掩體、危險池、廢棄車輛與研究設施物件。 |
| `props/{ruin_wall,scrap_pile,barrel_stack,dead_tree,toxic_pool,crystal_node,ore_node,herb_patch}.png` | `120x96` ~ `380x280` | RGBA | 全部帶有右下角 `add_unique_badge` 純色方塊！ | **Regenerate (P0)**：全面清除方塊污染並重製高品質廢土掩體與可採集資源點（礦脈、晶簇、藥草、廢鐵堆）。 |

---

## 4. NPC 角色資產 (`assets/sprites/npcs/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|---|
| `forge_master.png`, `shopkeeper.png`, ` scavenger_guide.png`, `guild_master.png`, `guild_clerk.png`, `artisan.png`, `veteran_hunter.png` | 各 `220x260` | RGBA | **嚴重污染**：全部是同一張剪影底圖套色，且右下角皆有不透明純色方塊 (`add_unique_badge`)，邊緣帶有白暈！ | **Regenerate (P0)**：為 7 位 NPC 各自繪製獨立的廢土像素造型（鐵匠圍裙與大錘、黑市商人斗篷與貨架、嚮導望遠鏡、公會長官大衣、接待員終端機、工匠機械義眼、老獵人重甲），完全透明去背。 |

---

## 5. 地圖與地面貼圖 (`assets/sprites/tiles/` & `assets/sprites/ui/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|---|
| `tiles/village_ground_variants_2p5d.png` | `512x128` | RGBA | **嚴重污染**：第 2 格中央有一個突兀的純白實心方塊，第 3 格有兩個灰白圓點。 | **Regenerate (P0)**：重製乾淨、可無縫拼接的 2.5D 據點石板/廢土泥地/道路邊界 Tile 圖集。 |
| `tiles/wasteland_ground_variants_2p5d.png` | `512x128` | RGBA | **嚴重污染**：同樣被畫上純白方塊與圓點，且缺乏各 Biome 專屬地表材質。 | **Regenerate & Expand (P0)**：重製並擴充 6 大 Biome 專屬地表材質與危險地形貼圖。 |
| `tiles/yuchan_wasteland_tiles.png` | `384x256` | RGBA | 舊版 Tile 圖集，目前被 `VillageTileMap.gd` 繞過未使用。 | **Upgrade (P1)**：更新為乾淨的標準地面圖塊並整合進場景渲染。 |
| `ui/world_map_2p5d.png` | `1536x1024` | RGB | 2.5D 廢土世界地圖底圖，整體氣氛佳，可用於世界路線選擇。 | **Keep & Enhance UI Overlay (P1)**：保留底圖並重構其上的路線節點、Biome 預覽與危險度 UI。 |

---

## 6. 武器、護甲與物品圖示 (`assets/sprites/items/` & `assets/sprites/weapons/`)

| 檔案路徑 | 尺寸 (px) | Alpha 通道 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|---|
| `items/armor/{初階,中階,高階}.png` | 各 `1024x1024` | RGB (白底) | **風格嚴重不符**：白底寫實 3D 渲染圖，依賴執行期 `RuntimeAssetLoader` 暴力去白底，邊緣殘留鋸齒且與像素風衝突。 | **Regenerate (P0)**：重製為 `64x64` / `128x128` 透明背景的精緻廢土像素風護甲圖示，並保留原檔名相容性。 |
| `items/melee/melee_tier_{1,2,3}.png`<br>`items/ranged/ranged_tier_{1,2,3}.png`<br>`items/tool/tool_tier_{1,2,3}.png` | 各 `64x64` | RGBA | 基礎像素圖示可用，但種類過少（僅 3 階），缺乏刀、砍刀、劍、斧、錘、長矛、鏈鋸、左輪、霰彈、狙擊、十字弓、能量槍等差異化圖示與手持 Sprite。 | **Expand & Upgrade (P1)**：重繪高細節圖示並擴充全系列近戰/遠程武器圖示與角色手持掛載 Sprite (`assets/sprites/weapons/`)。 |
| `items/mod/`, `items/consumable/`, `items/material/` | 各 `64x64` | RGBA | 基礎像素圖示正常，部分右下角有微小標記點。 | **Polish (P1)**：清理邊角雜點並強化高光與材質層次。 |

---

## 7. 特效與音訊資產 (`assets/sprites/effects/` & `assets/audio/`)

| 檔案路徑 | 類型 / 規格 | 現況品質審核與問題診斷 | 處置方案 |
|---|---|---|---|
| `effects/{slash_arc,muzzle_flash,scan_pulse,hit_spark,blood_burst,death_burst}.png` | `64x64` ~ `128x128` RGBA | 基礎幾何程序化特效，缺乏不同武器屬性（動能、火焰、腐蝕、電漿、晶簇）與多影格粒子細節。 | **Upgrade & Expand (P1)**：重製高品質像素風刀光弧線、槍口火光、彈殼、衝擊波、閃避殘影與環境危害粒子。 |
| `audio/bgm_{camp,Guild,wasteland,boss}.{ogg,mp3}` | BGM 音軌 (4 首) | 已修正 `.mp3` 副檔名，正常載入播放。 | **Keep (P0)**：保留並搭配環境音層次。 |
| `audio/sfx_*.{wav,mp3}` | SFX 音效 (15 個檔案) | 涵蓋基礎按鈕、拾取、合成、受擊、死亡與基礎攻擊，但缺乏不同武器專屬射擊/揮砍聲、裝填聲、閃避聲與不同材質腳步聲。 | **Expand (P2)**：擴充多武器音效、裝填、閃避、暴擊、升級音效與程序化多聲道混音控制。 |
