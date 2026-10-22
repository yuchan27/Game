---
name: godot-visual-review
description: Inspect Godot 2.5D pixel art, 8-directional animations, melee weapon overlays, ground tile cohesion, entity proportions, and rendered UI screenshots across 1280x720 and 1024x768 viewports.
---

# Godot Visual Review Skill

Trigger: sprite/atlas updates, melee slash/weapon overlay changes, terrain tileset updates, or UI layout adjustments.
Inputs: `data/art/visual_assets.json`, `data/art/player_animation_manifest.json`, changed scenes, and rendered screenshots.
Output: structural verification pass, 29 rendered PNG captures, and direct visual inspection sign-off.

## Workflow
1. **Clear Cache & Re-Import First**:
   - Delete stale `.godot/imported/*` files and run `Godot --headless --path <root> --import` so screenshots reflect the latest PNG bytes on disk.
2. **Structural Asset Validation**:
   - Run `python scripts/tools/verify_visual_assets.py` to verify SHA-256 hashes, dimensions, transparent backgrounds, 576 split player frames, weapon overlays, audio durations, and zero UTF-8 mojibake.
3. **Rendered Screenshot Capture (`VisualReviewRunner.gd`)**:
   - Execute with a real GUI renderer (never `--headless`):
     `Godot_v4.6.3-stable_win64_console.exe --path <root> res://scenes/tests/VisualReviewRunner.tscn -- --qa-output <output_dir>`
4. **Direct Visual Inspection Checklist**:
   - **Protagonist (`player_walk.png`, `player_slash.png`, `player_shoot.png`, `docs/player_split_frame_diagnostic.png`)**:
     - Verify zero transparent holes in neck, chest, waist, or legs.
     - Verify `right` and `left` are true side profiles, `up` is true back view, and `slash` displays a crisp horizontal/angled blade pivoted from the hand with a dynamic slash arc.
   - **Ground & Proportions (`village_hud.png`, `guild_hud.png`, `route_*.png`)**:
     - Verify ground tiles have fine-grained dark wasteland soil/asphalt scale (no giant orange bricks or random `1x1` square cutouts).
     - Verify Player (`90px`), NPCs (`88px`), Enemies, and Structures have grounded contact shadows and cohesive proportions.
   - **UI Modals (`inventory.png`, `tutorial.png`, `dialogue.png`, `*_1024x768.png`)**:
     - Verify zero text clipping, high contrast, opaque modal backdrops (`alpha >= 0.99`), and full viewport enclosure at both `1280×720` and `1024×768`.
