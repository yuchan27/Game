# Release Readiness (`docs/RELEASE_READINESS.md`)

- **Updated**: 2026-10-21 (Asia/Taipei)
- **Status**: **RELEASE READY (All 23 Automated, Visual & Packaged QA Gates Passed)**
- **Engine**: Godot `4.6.3.stable.official.7d41c59c4`
- **Verified QA Run**: `20261021T035004Z-ea851a73` (`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261021T035004Z-ea851a73\qa-report.json`)

---

## 1. Release Gate Disposition

| Gate | Requirement | Verification Result |
|------|-------------|---------------------|
| **G1: Clean Headless Import** | 0 Godot import errors; valid `.wav` PCM audio and valid PNG textures | **PASS** (`project-import` exit `0`, `0` errors) |
| **G2: Vertical Slice Contract** | All 310+ assertions in `VerticalSliceVerifier.gd` pass | **PASS** (`vertical-slice-validation` exit `0`) |
| **G3: Automated Playtest** | End-to-end camp, crafting, guild, 4 core routes, boss kill, return loop | **PASS** (`playtest-flow` exit `0`) |
| **G4: Combat, Biomes & UI Regressions** | Melee/ranged archetypes, dodge burst, 6 routes, modals, save migration | **PASS** (`combat-regression`, `world-route-regression`, `ui-modal-regression`, `save-migration-regression` all exit `0`) |
| **G5: Soak & Performance** | Multi-transition soak test + 50-enemy + boss + 200-projectile stress test | **PASS** (`soak-regression` & `performance-baseline` exit `0`, physics mean `1.58 ms`) |
| **G6: Visual Asset & 8-Dir Integrity** | 0 missing assets, 0 flat-color placeholders, unique 8-dir rows, 0 mojibake | **PASS** (`visual-asset-audit` & `visual-review-contract` exit `0`) |
| **G7: Standalone Windows Package** | Export `.exe` + `.pck` and pass startup, validation, playtest, and regressions | **PASS** (`windows-export-package` + 7 `packaged-*` steps all exit `0`) |

---

## 2. Implemented Rework Highlights

1. **Art Bible & High-Craft 2.5D Pixel Art Overhaul**:
   - Authored `docs/ART_BIBLE.md`, `docs/ANIMATION_SPEC.md`, `docs/BIOME_DESIGN.md`, and `docs/UI_DESIGN_SYSTEM.md`.
   - Generated 3 protagonist concept sheets (`docs/concepts/`) and built the `8064x1024` 8-directional x 9-action x 8-frame (`576` frames) **R-17 Vanguard (Evolved)** sprite sheet with authentic leg alternation in all 8 directions.
   - Replaced all structures, gates, interactive props, survivor NPCs, 6 mutant enemies + `Waste Titan` boss, and 22 equipment icons with cohesive 2.5D pixel art.
2. **Biome Differentiation & 6 Wasteland Routes**:
   - Expanded `data/maps/wasteland_routes.json` to 6 distinct biomes (`scrap_highway`, `toxic_marsh`, `crystal_scar`, `old_factory`, `ruined_metropolis`, `underground_facility`).
   - Added biome-specific procedural ground architecture (`WorldBackdrop.gd`) and environmental landmarks (`Wasteland.gd`).
3. **Weapon Diversity, Leveling (`Lv.1–Lv.5`) & Combat Feel**:
   - Expanded `data/items/equipment.json` to 14 distinct weapons across blade, sword, axe, hammer, spear, chainsaw, pistol, revolver, SMG, rifle, shotgun, sniper, crossbow, and explosive launcher archetypes.
   - Implemented `weapon_levels` (`Lv.1` to `Lv.5`) in `GameState.gd` with direct upgrade buttons (`鍛造近戰` / `鍛造遠程`) in the Equipment panel and Camp Forge.
   - Re-enabled 8-directional `WeaponOverlay` and `AttackFlash` VFX, multi-pellet shotgun/acid spread, enemy knockback/stagger, tracer trails, and active Dodge/Roll (`Shift` / `Space`) with EP cost.
4. **Synthesized Procedural Audio & Tactical UI**:
   - Upgraded `AudioManager.gd` with 26 procedural sound profiles, pitch variance, and anti-clipping cooldowns.
   - Styled HUD, Equipment, and World Map panels with the Wasteland Tactical Pixel UI system (`#12171D` slate, `#E8A838` amber accents).

---

## 3. Reproduction Commands

```powershell
# Run full 23-step isolated QA pipeline (source + visual + performance + packaged Windows build)
C:\Code\Game\first-game\.godot\qa-venv\Scripts\python.exe C:\Code\Game\first-game\scripts\tools\run_qa.py --profile all --godot-bin "C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"

# Run standalone visual & text encoding audit
C:\Code\Game\first-game\.godot\qa-venv\Scripts\python.exe C:\Code\Game\first-game\scripts\tools\verify_visual_assets.py
```
