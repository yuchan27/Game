---
name: godot-visual-review
description: Inspect Godot pixel art, animation contracts and rendered UI screenshots for alignment, clipping, readability and consistency without regenerating approved assets.
---

# Godot visual review

Trigger: sprite/atlas, UI/map layout or art-reference changes. Inputs: manifests,
original art, changed scenes, target PC resolutions and renderer. Output: inspected
screenshots, structural validation, actionable defects and visual limitations.

1. Read manifest and runtime texture selection. Establish actual art, dimensions,
   direction order and frame counts; do not assume old atlases or enabled overlays.
2. Run `python scripts/tools/verify_visual_assets.py` with Pillow. Blank/invalid
   images and bad references fail; frame reuse/color heuristics require visual judgment.
3. Run `python scripts/tools/run_qa.py --godot <engine> --profile visual` after
   reading `--help`. A headless/no-image result cannot establish visual correctness.
4. Open real PNGs: title/intro, HUD, inventory, dialogue/tutorial, full map,
   pause/death, all routes and Boss. Review 1280×720 and a smaller PC window for
   Traditional Chinese wrapping, spacing, contrast, map bounds and overlay conflicts.
5. Inspect R-17 side/back/action frames and foot anchors. Preserve authored bytes;
   rebuild or enable weapon overlays only for an explicit art requirement.

Validation: expected captures contain rendered content and the inspected images
are identified. Failure: retain failing image/log, repair the smallest code/data
cause and recapture. Never overwrite art to satisfy an obsolete style heuristic.
