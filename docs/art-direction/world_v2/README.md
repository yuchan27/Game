# World v2 production checkpoint

This is the preserved architecture/composition record. Current shared ground and
small-prop production is [world v3](../world_v3/README.md), which still uses this
kit's architecture positions and collision feet. The captures here are the
earlier material baseline; see v3 for current combined scene images.

Updated 2026-10-23. The parent approved both atlas material/silhouette directions
and the bounded, integrated highway + marsh runtime art batch. The parent also
reviewed the four regional architecture captures and accepted their distinct
silhouettes, materials and hero scale. This is approval of representative
architecture compositions, not a finished campaign-wide level-design pass.
Original generated PNG bytes are preserved.

## What is in the game

`scripts/systems/WorldBackdrop.gd` renders authored route widths, chipped kerbs,
gravel shoulders, centre markings and seeded varied road wear. The representative
highway driving lane is 320 world pixels wide. Marsh crossings use cross-plank
surfaces with raised edge shadows and visible flooded-bank boundaries.
`scenes/levels/wasteland/Wasteland.gd` consumes `data/art/world_v2.json` directly
to place reusable, bottom-anchored architecture, explicit physical footprints and
basins. It also reserves their bounds during scatter/spawn placement. Span
collision covers the piers only; the central gap remains open. An old saved
player position inside a newly authored footprint suppresses that placement.
Large foreground modules fade only near the player, using the existing 0.2 s
world refresh. An alpha cutoff removes diffuse generated fringes at runtime;
it does not repaint or replace the PNG source.

| Route | Integrated spatial treatment | State at this checkpoint |
| --- | --- | --- |
| Scrap highway | Toll canopy, broken flyover supports, depots and medians; main spine, west convoy loop, east camp loop, service shortcut and return lane; clustered cover beside the bus | [1280x720 combined hero/world capture](captures/highway-convoy.png). Parent approved the bounded composition. |
| Toxic marsh | Pumphouses, raised crossings, winding causeway, flooded basins and a clear story landing | [1280x720 combined capture](captures/toxic-marsh-architecture.png). Parent approved the bounded composition. |
| Crystal scar | Basalt/crystal buttresses, narrow crossings, bent canyon route and chasms | [Integrated ordinary runtime capture](captures/crystal-scar-architecture.png); parent accepted the representative architecture composition. |
| Old factory | Twin-chimney furnace halls, cross corridors and furnace pits | [Integrated ordinary runtime capture](captures/old-factory-architecture.png); parent accepted the representative architecture composition. |
| Ruined metropolis | Gothic bell towers, boulevard/plaza loops and rubble blocks | [Integrated ordinary runtime capture](captures/ruined-metropolis-architecture.png); parent accepted the representative architecture composition. |
| Underground facility | Cyan coolant laboratories, connected outer ring and coolant basins | [Integrated ordinary runtime capture](captures/underground-facility-architecture.png); parent accepted the representative architecture composition. |

The seven PNGs in `assets/world_v2/concepts/` are **reference boards only**.
No board is loaded as a world wallpaper or used as a collision substitute. The
actual runtime assets are `assets/world_v2/kits/highway-architecture-v2-01.png`
and `assets/world_v2/kits/region-architecture-v2-01.png`, plus preserved legacy
props/landmarks. Module source rectangles, world sizes, foot anchors, names and
footprints live in `data/art/world_v2.json`. Story/event identifiers, discovery
keys, evidence coordinates, quest prerequisites and save formats are unchanged.

## Provenance

- Built-in `image_gen` generated both production atlases; no paid API, image
  repaint, procedural replacement sprite or external art dependency was used.
- Prompts are saved in `prompts/highway-architecture-v2-01.txt` and
  `prompts/region-architecture-v2-01.txt`.
- Highway original: 1254x1254 RGBA. The requested grid was not exact. Explicit
  disjoint rectangles were derived from solid-alpha component inspection; two
  edge slivers are intentionally excluded to avoid the adjacent sprite.
- Regional original: 1536x1024 RGBA. Six separate solid-alpha component bounds
  are recorded explicitly; nonzero-alpha halos are not treated as geometry.
- Retained legacy landmarks include the highway bus, marsh pump, crystal spire,
  factory turbine, evacuation archive and memory vault.
- PNG SHA-256 values and rendering/review metadata are recorded in the standalone
  `data/art/world_v2.json` manifest. Captured-source SHA-256 values are in
  [captures/source_snapshot.json](captures/source_snapshot.json).

## Navigation blueprints

These small native SVGs are generated from the **actual current runtime JSON**,
including roads/widths, story reserve, three existing guarded-discovery anchors,
return gate, ground basins, architecture visual envelopes and authored feet.
Orange cover points identify the additional highway/marsh cover clusters.
They are diagrams, not replacement game art or proof of collision traversal.

- [Scrap highway](scrap_highway-blueprint.svg)
- [Toxic marsh](toxic_marsh-blueprint.svg)
- [Crystal scar](crystal_scar-blueprint.svg)
- [Old factory](old_factory-blueprint.svg)
- [Ruined metropolis](ruined_metropolis-blueprint.svg)
- [Underground facility](underground_facility-blueprint.svg)

Regenerate with `python docs/art-direction/world_v2/generate_blueprints.py`
from this repository. The script uses the Python standard library only.

## Review and continuation

The installed engine was verified as Godot
`4.6.3.stable.official.7d41c59c4`. No test runner or automated test was executed,
following the latest user instruction. Ordinary screenshots use an external
project mirror with a unique `application/config/custom_user_dir_name`; real
player `user://save_game.json` must remain untouched. Headless import alone is
not visual evidence. The final ordinary GUI preview exited **0**, with no runtime
errors observed in [captures/render.log](captures/render.log). All seven current
captures use the new slim R-17 and integrated blade, the current world modules,
1280x720 viewport and 1.15 camera zoom. Only transient notices were hidden; the
actual HUD remains visible. The parent reviewed highway and marsh together,
then all four regional architecture captures. No claim is made
for collision traversal, quest execution, save/load regression, performance,
1024x768, 1920-wide framing, other weapon families or release readiness.

`captures/ArtPreview.gd.txt` records the portable ordinary capture recipe. Copy
it as a scene script **inside an isolated project mirror**, configure a unique
custom user directory, and pass `-- --art-output=<absolute output directory>`.
The recipe refuses to run without the custom-user-directory setting. Do not
launch a writing scene against the real player profile to reproduce screenshots.

Next: extend the accepted floor and encounter treatment along each complete
route, then inspect additional actual gameplay camera positions. Do not
present a single facade per route as a finished campaign-wide art pass. Resume
gameplay/physics QA only when the user's no-tests instruction changes. Preserve
all other dirty work. No commit, push or deletion was performed by this art pass.
