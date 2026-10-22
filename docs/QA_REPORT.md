# QA Verification & Rework Audit Report (`docs/QA_REPORT.md`)

- **Project**: 廢土回收商 (`Wasteland Recycler`)
- **Engine**: Godot `4.6.3.stable.official.7d41c59c4`
- **Integrated QA Pipeline Run ID**: `20261021T035004Z-ea851a73`
- **Report Path**: `C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261021T035004Z-ea851a73\qa-report.json`
- **Overall Status**: **PASSED (`23 / 23` Steps Green, Exit Code `0`, `0` Godot Errors)**

---

## 1. Integrated QA Pipeline Summary (`run_qa.py --profile all`)

All 23 verification stages in `scripts/tools/run_qa.py --profile all` passed in an isolated workspace copy without mutating the source checkout:

| # | Step Name | Status | Duration (s) | Key Verification Scope |
|---|-----------|--------|--------------|------------------------|
| 1 | `project-import` | PASS | 3.74 | Headless Godot asset import & resource UID validation (`0` errors) |
| 2 | `startup-check` | PASS | 0.90 | Main scene boot, 5 autoloads (`GameState`, `DataManager`, `SaveManager`, `AudioManager`, `SceneTransition`) |
| 3 | `vertical-slice-validation` | PASS | 1.38 | 310+ assertions in `VerticalSliceVerifier.gd`: contracts, save/load, combat, 6 biomes, 14 weapons, quests |
| 4 | `playtest-flow` | PASS | 1.30 | Full automated loop: Intro -> Village -> Craft/Shop/Mod/Forge/Recycle -> Guild -> 4 Core Routes -> Boss -> Return |
| 5 | `object-pool-smoke` | PASS | 1.33 | Projectile pool capacity ceiling (`200`), recycling, and scene transition cleanup |
| 6 | `combat-regression` | PASS | 1.31 | Melee arc/range, multi-pellet shotgun/acid spread, enemy knockback/stagger, active dodge burst |
| 7 | `world-route-regression` | PASS | 1.56 | Seeded route generation across `scrap_highway`, `toxic_marsh`, `crystal_scar`, `old_factory`, `ruined_metropolis`, `underground_facility` |
| 8 | `ui-modal-regression` | PASS | 1.44 | Equipment (`Tab`), World Map (`M`), Help (`H`), Dialogue/Craft/Shop/Mod/Forge/Recycle modals & weapon forging |
| 9 | `save-migration-regression` | PASS | 0.94 | Legacy v0/v1 save schema migration to v2, `weapon_levels` persistence, SHA-256 tamper rejection |
| 10 | `soak-regression` | PASS | 2.13 | Repeated scene transitions (`Village` <-> `Guild` <-> `Wasteland`), node leak & orphan checks |
| 11 | `performance-baseline` | PASS | 6.80 | Rendered `forward_plus` stress test on `crystal_scar` with 50 enemies + active Waste Titan boss + 200 pooled projectiles |
| 12 | `visual-review-captures` | PASS | 8.59 | Rendered 11 deterministic `1280x720` screenshots via `VisualReviewRunner.gd` |
| 13 | `visual-review-contract` | PASS | 0.13 | Verified all 11 PNG captures exist, match `1280x720` resolution, and contain non-blank variance |
| 14 | `visual-asset-audit` | PASS | 1.07 | `verify_visual_assets.py`: 0 missing paths, 0 flat fallbacks, 8-dir row hashes unique, 0 mojibake markers |
| 15 | `export-template-check` | PASS | 0.01 | Verified Windows Desktop export template binary presence |
| 16 | `windows-export-package` | PASS | 2.66 | Built standalone `WastelandRecycler.exe` + `.pck` package |
| 17 | `packaged-startup-check` | PASS | 0.65 | Booted exported `WastelandRecycler.exe` binary |
| 18 | `packaged-validation` | PASS | 1.24 | Ran `VerticalSliceVerifier.gd` inside exported `.exe` package |
| 19 | `packaged-playtest` | PASS | 1.15 | Ran full `PlaytestRunner.gd` inside exported `.exe` package |
| 20 | `packaged-combat-regression` | PASS | 1.25 | Ran `CombatRegressionRunner.gd` inside exported `.exe` package |
| 21 | `packaged-world-route-regression` | PASS | 1.24 | Ran `WorldRouteRegressionRunner.gd` inside exported `.exe` package |
| 22 | `packaged-ui-modal-regression` | PASS | 1.18 | Ran `UiModalRegressionRunner.gd` inside exported `.exe` package |
| 23 | `packaged-save-migration-regression` | PASS | 0.64 | Ran `SaveMigrationRegressionRunner.gd` inside exported `.exe` package |

---

## 2. Visual Asset & 8-Directional Atlas Audit (`verify_visual_assets.py`)

- **Protagonist 8-Directional Multi-Action Sheet (`assets/sprites/player/r17_wasteland_8dir_actions.png`)**:
  - Dimensions: `8064x1024` (`112x128` per frame, 8 directions x 9 action blocks x 8 frames = `576` unique frames).
  - Selected Design: **Concept B — R-17 Vanguard (Evolved)** (`docs/concepts/protagonist_concept_b_r17_vanguard.png`).
  - Every directional row (`right`, `down_right`, `down`, `down_left`, `left`, `up_left`, `up`, `up_right`) has distinct anatomical perspective (front respirator visor vs. side profile vs. rear hooded cloak & core backpack) and genuine leg-stride alternation in `walk` and `run` across all 8 rows (including `up_left`, `up`, `up_right`).
- **Overhauled 2.5D Pixel-Art World Assets**:
  - **Structures**: `forge`, `craft`, `shop`, `mod_station`, `recycle_machine`, `save_station` (`420x250` RGBA).
  - **Gates & Interactive Props**: `guild_gate`, `wasteland_gate`, `route_gate`, `return_gate`, `ruin_wall`, `scrap_pile`, `barrel_stack`, `dead_tree`, `toxic_pool`, `crystal_node`, `ore_node`, `herb_patch`.
  - **NPCs**: `forge_master`, `shopkeeper`, `scavenger_guide`, `guild_master`, `guild_clerk`, `artisan`, `veteran_hunter` (`220x260` RGBA, 100% transparent corner checks passed).
  - **Enemies & Boss**: `scrap_biter`, `toxic_runner`, `spore_gunner`, `rust_brute`, `rot_wing`, `mech_husk` (`384x96` 4-frame animated strips), `waste_titan` (`140x140` RGBA with clean transparent background), `polluted_enemy_six_types.png` (`672x72` 7-column strip), and `polluted_enemy_showcase_sheet.png` (`1344x768`).
  - **Arsenal & Armor Icons**: 22 distinct weapon/armor/tool icons (`64x64`) + 3 high-DPI armor tier icons (`初階.png`, `中階.png`, `高階.png` at `128x128`).

---

## 3. Rendered Screenshot Verification (`1280x720`)

All 11 rendered visual review screenshots in `C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261021T035004Z-ea851a73\artifacts\visual\` were inspected:

1. `intro.png`: High-contrast Wasteland Tactical Pixel UI modal over animated R-17 camp backdrop.
2. `village.png`: Camp with 6 distinct 2.5D pixel-art industrial stations, survivor NPCs, R-17 Vanguard with weapon overlay, and crisp top/bottom HUD.
3. `guild.png`: Guild bunker interior with distinct `guild_master`, `guild_clerk`, `artisan`, `veteran_hunter` sprites and commission stations.
4. `highway.png`: South Gate `scrap_highway` featuring cracked asphalt road slabs, faded yellow dashed lane markings, and highway ruins.
5. `marsh.png`: East Gate `toxic_marsh` featuring bubbling toxic green pools, wooden boardwalk planks, and spore enemies.
6. `scar.png`: North Gate `crystal_scar` featuring glowing violet/cyan crystal veins and fractured basalt terrain.
7. `factory.png`: West Gate `old_factory` featuring industrial metal grating, yellow/black hazard stripes, and rogue automata.
8. `boss.png`: `Waste Titan` boss rendered cleanly with a 100% transparent background over `crystal_scar` terrain alongside crystal clusters.
9. `equipment.png`: Upgraded Character & Arsenal panel (`Tab`) displaying weapon levels (`Lv.1`), direct forge upgrade buttons (`鍛造近戰` / `鍛造遠程`), and armor tier preview.
10. `map.png`: Tactical Radar World Map (`M`) showing all 6 biome routes, seed hex badge, danger rating, and player beacon.
11. `help.png`: Controls & Gameplay Guide (`H`) documenting movement, melee/ranged combat, active dodge (`Shift`), and weapon forging.

---

## 4. Performance Metrics (`PerformanceRunner.gd`)

- **Test Environment**: Windows `forward_plus` renderer on `Intel(R) Core(TM) Ultra 7 268V`, Godot `4.6.3-stable`.
- **Stress Scenario**: Seeded `crystal_scar` wasteland route with `50` active enemies, `1` active `Waste Titan` boss, `64` props, `24` pickups, and `200` pooled projectiles exercised.
- **Timings**:
  - Scene setup elapsed: `0.673 s` (`672,989 usec`)
  - Physics processing time (`TIME_PHYSICS_PROCESS`): mean `1.58 ms`, p50 `1.72 ms`, p95 `2.13 ms`, max `2.13 ms`
  - Process time (`TIME_PROCESS`): mean `18.45 ms`, p50 `18.73 ms`, p95 `18.87 ms`
  - Frame cadence wait (`physics_frame`): mean `15.96 ms` (~62.6 FPS)
- **Memory & Pooling**:
  - Static memory before sample: `82.83 MB` -> after sample: `83.17 MB` (delta `+337 KB`, peak `89.09 MB`).
  - Projectile pool ceiling strictly enforced at `200 / 200` with `24` immediate instance reuses and zero unbounded allocations.
