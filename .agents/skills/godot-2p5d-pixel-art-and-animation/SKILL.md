---
name: godot-2p5d-pixel-art-and-animation
description: Build, extract, rig, and validate 2.5D top-down oblique pixel-art characters (8-directional 9-action atlases), fluid melee slash combos, hilt-pivoted weapon overlays, grounded NPC/prop proportions, and seamless 2.5D terrain tilesets in Godot 4.
---

# Godot 2.5D Pixel Art, Animation & Terrain Pipeline

Use this skill whenever creating, fixing, or upgrading 2.5D top-down oblique (`3/4` view) pixel-art sprites, 8-directional character animations, melee slash choreography, weapon overlays, or terrain tilesets in Godot 4.

## 1. Core Proportions & Grounding Contract (`比例與接地規範`)

To prevent characters from looking like they are floating (`飄在上面`) or mismatched in scale (`比例不對`) against the background:

| Asset Category | Canvas Size (px) | Visual Subject Height | Ground Shadow (`Polygon2D` + Baked) | Filter Mode |
| :--- | :--- | :--- | :--- | :--- |
| **Protagonist (`Player`)** | `112 × 128` | `88 – 92 px` | 3-ring elliptical AO (`rx=26, ry=8.5`) at `y = -8` | `TEXTURE_FILTER_NEAREST` |
| **Survivor NPCs (`DialogueNpc`)** | `84 × 98` | `84 – 90 px` | Elliptical shadow (`rx=24, ry=8`) at `y = -4` | `TEXTURE_FILTER_NEAREST` |
| **Standard Enemies (`Enemy`)** | `96 × 72` | `58 – 68 px` | Elliptical shadow (`rx=22, ry=7.5`) at `y = +18` | `TEXTURE_FILTER_NEAREST` |
| **Boss (`WasteTitan`)** | `96 × 72` (`1.9x` scale) | `125 – 135 px` | Elliptical shadow (`rx=42, ry=14`) at `y = +24` | `TEXTURE_FILTER_NEAREST` |
| **Camp Structures / Stations** | `168×132` – `196×150` | `115 – 138 px` | Elliptical shadow (`rx=0.44*w, ry=14`) at `y = -6` | `TEXTURE_FILTER_NEAREST` |
| **Ground Tile Cell** | `32 × 32` (`128×128` macro) | Pebbles `2–3 px`, Slabs `32×32 px` | Seamless edge wrap (`10 px` margin) | `TEXTURE_FILTER_NEAREST` |

## 2. Background Extraction Without Stripping Dark Joints (`防破圖去背法`)

Never use a naive luminance threshold (`max(R,G,B) < 55`) to strip backgrounds from character reference sheets—it will erase dark charcoal neck joints, waist joints, and inner thighs (`主角變得太破了`).

1. **Color-Difference Border Flood-Fill**:
   - Measure the background color signature (e.g., cool slate-blue checkerboard where `B - R >= 4` and `max(R,G,B) < 54`).
   - Protect warm charcoal/metal interior shadows (`R >= B - 3` or `G >= B - 2`).
2. **Anatomical Continuity Sealing**:
   - After flood-fill, run horizontal/vertical bridge passes (`1–3 px` span) and an anatomical spine/neck/pelvis/leg solid-core pass so the character silhouette is **100% opaque with zero internal holes**.
3. **Verify on High-Contrast Green Diagnostic Canvas**:
   - Always render sample frames onto a bright green `(48, 92, 54)` diagnostic strip (`docs/player_split_frame_diagnostic.png`) to visually confirm zero background holes bleed through the neck, torso, or legs.

## 3. 8-Directional Turnaround & Row Order (`八方向列序規範`)

Row index in the master `8064 × 1024` atlas (`9 actions × 8 frames × 8 directions`):
- `row 0` (`right`, `0°`): Pure East side profile facing right.
- `row 1` (`down_right`, `+45°`): 3/4 front-right oblique view.
- `row 2` (`down`, `+90°`): True front view.
- `row 3` (`down_left`, `+135°`): 3/4 front-left oblique view.
- `row 4` (`left`, `180°`): Pure West side profile facing left.
- `row 5` (`up_left`, `-135°`): 3/4 back-left oblique view (backpack visible).
- `row 6` (`up`, `-90°`): True back view (hood & backpack prominent).
- `row 7` (`up_right`, `-45°`): 3/4 back-right oblique view (backpack visible).

## 4. Fluid Melee Slash & Hilt-Pivoted Weapon Overlays (`流暢近戰揮砍設計`)

To make melee combat feel responsive, weighty, and fluid:
1. **Normalize All Melee Weapon Overlays (`96 × 64` RGBA)**:
   - Strip icon drop-shadow pixels (`alpha < 185`) before rotating `-45°` so diagonal weapon icons become crisp horizontal blades pointing **Right (`0°`)** with zero grey shadow streaks.
   - Place the weapon hilt at `x = 18..22, y = 32` and blade tip extending toward `x = 86`.
2. **Hilt Pivot in Godot (`Sprite2D`)**:
   - Set `weapon_sprite.centered = true` and `weapon_sprite.offset = Vector2(26, 0)` so rotation pivots around the **hilt in the player's hand**, not the middle of the blade.
3. **2-Hit Alternating Forehand / Backhand Combo**:
   - Alternate `slash_combo_step` between Forehand (`-108° -> +78°`) and Backhand (`+108° -> -78°`) with cubic ease-out (`1.0 - pow(1.0 - t, 3.0)`), `22 FPS` frame playback across all 8 `slash` frames, a forward body lunge on `sprite.position`, and a synchronized multi-layer crescent energy arc in `AttackFlash.gd`.

## 5. Cache Clearing & Re-Import (`清除 Godot Cache`)

Whenever PNG textures are modified by external Python tools, clear stale `.ctex` cache files and re-import:
```powershell
python .agents/skills/godot-2p5d-pixel-art-and-animation/scripts/clear_godot_import_cache.py --godot "C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"
```
