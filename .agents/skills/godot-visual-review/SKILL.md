---
name: godot-visual-review
description: Inspect Godot 2.5D pixel art, directional animation, terrain cohesion, entity proportions, and rendered UI across viewport profiles derived from the current project.
---

# Godot Visual Review Skill

Trigger: sprite/atlas updates, melee slash/weapon overlay changes, terrain tileset updates, or UI layout adjustments.
Inputs: current project root and engine, `project.godot`, `docs/SCREEN_STATE_MATRIX.md`, relevant art manifests, changed scenes, and rendered screenshots.
Output: structural verification, the runner's current required rendered PNG captures, and direct visual inspection evidence.

## Workflow
1. **Derive Profiles and Isolate**:
   - Read viewport, window, stretch, renderer, and platform settings from `project.godot`; compare them with the current screen matrix. Keep logical design size, configured launch window, smallest supported cold launch, and live resize as separate profiles. If the smallest supported window is undeclared, record it as unresolved rather than assuming a historical capture proves support.
   - Run the QA launcher in its isolated mirror so screenshots reflect current source and PNG bytes. Do not bulk-delete `.godot/imported/` or touch player saves.
2. **Structural Asset Validation**:
   - Run `python scripts/tools/verify_visual_assets.py` and `validate_project_data.py` to check hashes, dimensions, alpha, explicit crop/foot metadata, legacy frames, overlays and references. The active knight uses three authored body keys per direction plus native 60 Hz motion; old strips remain for death/fallback. See `docs/PLAYER_MOTION.md`. A legacy atlas pass alone does not prove the active animation's quality.
3. **Rendered Screenshot Capture (`VisualReviewRunner.gd`)**:
   - Execute with a real GUI renderer (never `--headless`):
     `python scripts/tools/run_qa.py --godot <discovered-engine> --profile visual`
   - In the launcher's isolated project mirror, run `DirectionalPresentationRegression.tscn` with a real renderer and `--qa-output <external-output>` for directional and motion contact sheets.
4. **Direct Visual Inspection Checklist**:
   - **Protagonist (`player_walk.png`, `player_slash.png`, `player_shoot.png`, `docs/player_split_frame_diagnostic.png`)**:
     - Verify zero transparent holes in neck, chest, waist, or legs.
     - Verify `right` and `left` are true side profiles, `up` is true back view, and `slash` displays a crisp horizontal/angled blade pivoted from the hand with a dynamic slash arc.
   - **Ground & Proportions (`village_hud.png`, `guild_hud.png`, `route_*.png`)**:
     - Verify ground tiles have fine-grained dark wasteland soil/asphalt scale (no giant orange bricks or random `1x1` square cutouts).
   - Verify player and NPC silhouettes against the active art manifests, frame crops, sole/grip anchors, and collision shapes. Check enemies and structures for consistent scale, grounded contact shadows, and readable depth. Do not reuse a fixed pixel height when the active contract has changed.
   - **UI Modals**: inspect the modal captures listed by the current `REQUIRED_CAPTURES` manifest; names such as `inventory.png` and `dialogue.png` are examples from this project and may change.
   - Verify zero text clipping, high contrast, opaque modal backdrops (`alpha >= 0.99` where specified), and full viewport enclosure at every current project viewport profile. Review first open and live resize separately; a resized capture does not prove a cold narrow launch.
   - **Story scenes and journal (`story_site_*.png`, `story_journal*.png`, `story_discovery.png`, `story_ending.png`)**:
     - Inspect every route's evidence composition from the actual interaction position, complete landmark visibility, clear approaches, unknown-entry spoiler suppression, and readable consequence text. Confirm reading/closing the journal or evidence releases only its own pause.

## Acceptance and failure handling

Require current rendered files, zero capture/runtime errors and direct inspection
of the changed interfaces and poses. Obtain the required capture list from the
current runner and reconcile it with the screen matrix; do not rely on a stale
capture count. Document source fingerprint, actual output and content viewport
dimensions, startup/resize path, and remaining quality limits. Headless output,
missing captures or duplicate standing frames cannot establish visual animation
quality. Fix framing/anchor defects and recapture; keep original PNG bytes and
explain concept art versus implemented terrain. For another project, derive its
profiles, capture runner and asset contracts instead of copying this adapter.
