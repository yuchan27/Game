---
name: godot-2p5d-pixel-art-and-animation
description: Produce coherent oblique pixel-art characters, held weapons, directional motion and environment modules while preserving explicit scale, grip, sole and collision contracts.
---

# Godot pixel-art production

Trigger: requested character, weapon, animation, terrain or modular architecture work.
Inputs: approved identity references, target gameplay scale, required actions/facings,
source asset paths and integration owner. Output: versioned art, source provenance,
explicit crop/anchor metadata and reviewed in-game presentation.

## Workflow

1. Read the actual active loader and approved art direction before production.
   Project adapters are `docs/ART_AND_COMBAT_REDESIGN_PLAN.md`,
   `docs/PLAYER_MOTION.md`, `data/art/visual_assets.json` and any active v2 manifest.
   Existing legacy atlas dimensions are fallback contracts, not universal limits.
2. Design body, hands and weapon together at gameplay size. Match pixel density,
   perspective, lighting and handedness. Preserve R-17's gold-cross helmet,
   blue-gray armor and crimson cape. Do not attach unrelated inventory icons.
3. Use the host's image-generation skill/tool for raster generation or edits when
   it is available and authorized. If unavailable, keep the original source PNGs
   and record the needed art/specification as pending; do not silently substitute
   procedural output. Record prompt/provenance for generated work. Reject clipped
   limbs, colored halos, false mirrored facings and duplicate poses presented as
   new motion.
4. Register actual crop rectangles, soles, grips and muzzle positions. Generated
   sheets may have nonuniform spacing; never infer a grid without inspection.
5. Integrate one reviewed batch through the current Godot owner. Use native
   nearest filtering and explicit foot collisions. Architectural openings must
   have matching clear traversal gaps. Keep decorative height distinct from floors.
6. Inspect normal isolated production previews/contact sheets at actual gameplay
   size. Run regression suites only when authorized by current task instructions.
   Update the production manifest and bounded handoff with actual limitations.

## Acceptance and failure handling

Approval requires visible silhouette/grip consistency and useful motion poses.
A 60 Hz simulation is not proof of sixty authored frames or guaranteed 60 FPS.
Eight genuine views cannot be reported as thirty-two. If generation clips or
adds halos, produce a corrected version before activating it; never reconstruct
missing anatomy with a crop. A coarse rig may be a technical reference but does
not replace approved character art merely because its angles are measurable.

Use normal Godot reimport or an isolated project for updated sources. Do not
purge the user's import cache, overwrite approved art or touch real player saves.
