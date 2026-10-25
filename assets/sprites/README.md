# Runtime sprite sources

Read the active code and manifests before editing or removing sprites. The
canonical project rules are in `AGENTS.md`; approved direction and provenance are
in `docs/art-direction/README.md` and `docs/ART_AND_COMBAT_REDESIGN_PLAN.md`.

- `data/art/visual_assets.json`: existing world, enemy, UI and directional art.
- `data/art/player_animation_manifest.json`: preserved legacy animation contract.
- `player/redesign_v2/`: current character production; only assets explicitly
  activated by Player configuration are runtime-approved.
- `../world_v2/`: world concept references and modular architecture production.
  A concept board is not automatically a traversable level or active backdrop.
- `player/anim30/`, `player/actions/`, `player/frames/` and legacy sheets remain
  fallback/source material while the active loader still references them.

R-17 retains blue-gray armor, gold-cross helmet and crimson cape. Do not use the
older white-robot reference as the current identity. Keep source PNGs unchanged,
add versioned outputs, and register scale, crops, sole/grip anchors and collision
footprints before activation. Inventory icons are not interchangeable with held
weapon frames.

Generation tools are deliberate production commands that can overwrite art;
never run an old full-asset rebuild as routine cleanup. Ordinary Godot reimport
or an isolated production preview is sufficient to inspect new sources.
See `docs/ASSET_CLEANUP_REPORT.md` for the current removal inventory and backup.
