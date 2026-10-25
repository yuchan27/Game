# Coherent medieval wasteland environment production

**Superseded visual disposition:** the user rejected the full convoy composition
as still pasted together. The parent's earlier acceptance below is historical,
not the current acceptance gate. Continue from [world v4](../world_v4/README.md).

Updated 2026-10-23 (Asia/Taipei). User requested a unified 2.5D pixel medieval
wasteland: background and objects must read as one world. No tests/QA suites in
this production pass; ordinary isolated scene renders are art review only.

## Confirmed cause and implemented direction

Previous runtime ground used a tinted 64px grayscale FastNoise texture and
geometric tile details. Detailed v2 architecture, global legacy props, resource
nodes and wide smooth shadows had separate material/scale conventions. Earlier
facade-only approval did not establish complete scene cohesion. Current work
replaces that ground/prop combination through the existing owners.

- One unchanged earth PNG and one unchanged worn royal-road PNG share charcoal
  slate, umber soil and sparse neutral highlights. They repeat in world space at
  512px, with nearest sampling and two-world-pixel output clusters.
- Eight matching atlas modules use slate, oak and iron: rubble A/B, broken wall,
  wagon, thorn, dry grass, supplies and waypost. Explicit crops/feet replace guessed
  tile-grid slicing. The manifest uses native alpha cutoff 0.5; no pixel repaint.
- One shared Godot shader and cached padded chunk masks blend existing authored
  roads into the earth. Terrain contrast is restrained to keep R-17 readable.
  Basins retain their existing physical envelopes with worn material lips.
- Wasteland props have explicit route context. Common objects and harvest-node
  visuals use the same kit; IDs, drops and interaction owners stay unchanged.
  Village/Guild are outside this adapter. Unique story landmarks retain their
  original assets and collision feet as ancient machinery/relics in this world.
- Nonblocking roadside/facade clusters replace uniform decorative scatter.
  Existing protected approaches, return space and physical foot reservations
  remain. Building contact uses small soil/debris patches, not a full black bar.

The primary files are `scripts/systems/WorldBackdrop.gd`,
`scripts/components/WorldProp.gd`, `scenes/levels/wasteland/Wasteland.gd` and
`data/art/world_materials_v3.json`. `data/art/world_v2.json` still supplies the
existing architecture placement/physical footprints. Do not replace it with a
concept wallpaper or silently change quest/save IDs.

## Sources and reusable handoff

- [Generated PNGs, source hashes, prompts and actual crops](assets.md).
- [Ground material/shader implementation and limitations](ground_runtime.md).
- [Scene/prop adapter and composition implementation](scene_runtime.md).
- [Representative scene outputs](captures/).
- Preserved earlier same-location views: `../world_v2/captures/`.

The three exact prompts are under `assets/world_v3/prompts/`; source PNGs remain
unchanged under `assets/world_v3/`. The portable manifest has `res://` paths.
The capture recipe is `captures/ArtPreview.gd.txt`; run only in an external
project copy with a dedicated custom user directory and explicit absolute output.

## Reference research and evidence limits

GGG describes environment concept work as a coordinated set of tiles, asset
sheets and moods, with consistent texture/value/color/shape. This supports a
shared material family, rather than independent illustrations.
Source: [GGG environment-art role](https://www.pathofexile.com/forum/view-thread/2769628).

The PoE forum creator Neoxiri's [Silverstain Hideouts](https://www.pathofexile.com/forum/view-thread/3289488)
was directly viewed in a normal browser. It is a player-authored composition,
not a GGG implementation specification. Observable lessons: repeated material
families at several scales, vegetation/debris overlapping structure bases,
foreground framing, restrained ground values and localized light pools. Applying
those lessons here is our art-direction decision; the game's internal rendering
algorithms were not inspected.

[Bandai Namco's Elden Ring overview](https://en.bandainamcoent.eu/elden-ring/elden-ring)
and [official gameplay preview](https://www.bandainamcoent.com/news/elden-ring-gameplay-preview)
describe connected landscapes/dungeons and exploration. Their text was available;
detailed official image fetches failed, and the interactive pages presented age
verification that was not completed. Do not claim direct Elden Ring screenshot
or engine analysis from this research.

REA 6.4.0 was available, but the local Steam library inventory did not contain
PoE/Elden Ring and there was no selected game artifact/runtime. The automatic
approval review rejected launching a dedicated remote-debugging browser session,
reporting `blocked by policy`. That operation was not retried. Ordinary public
browser/web reading supplied the available references. No commercial game assets
were extracted or copied; all runtime PNGs in this pass are original generations.

## Current review boundary

The three source PNGs passed the parent's shared-material review and the v3
manifest is enabled. The first ordinary scene render exposed an invalid metadata
cache identifier containing a decimal point; the identifier was corrected to an
integer alpha suffix. Its error log is retained externally, not counted as a
clean render. A subsequent full-resource render exited 0 without observed logged
errors. Its images exposed overly busy terrain and long dark facade strips;
terrain contrast was compressed and those strips replaced by short soil/contact
patches and real atlas rubble at the base corners. The parent inspected the six
updated route views and accepted this bounded common-material integration.
The final ordinary render exited 0, produced seven captures (six routes plus
highway arrival), and logged no observed `ERROR:` or `SCRIPT ERROR:` entries.
All 16 recorded runtime/data/PNG inputs were byte-identical between this working
directory and the isolated render copy. Final capture/source fingerprints are
stored in `captures/source_snapshot.json`; `captures/render.log` is the final log.

| Route | Preserved earlier material view | Current combined scene |
| --- | --- | --- |
| Highway | [Before](../world_v2/captures/highway-convoy.png) | [After](captures/highway-convoy.png) |
| Marsh | [Before](../world_v2/captures/toxic-marsh-architecture.png) | [After](captures/toxic-marsh-architecture.png) |
| Crystal | [Before](../world_v2/captures/crystal-scar-architecture.png) | [After](captures/crystal-scar-architecture.png) |
| Factory | [Before](../world_v2/captures/old-factory-architecture.png) | [After](captures/old-factory-architecture.png) |
| City | [Before](../world_v2/captures/ruined-metropolis-architecture.png) | [After](captures/ruined-metropolis-architecture.png) |
| Facility | [Before](../world_v2/captures/underground-facility-architecture.png) | [After](captures/underground-facility-architecture.png) |

No automated tests, QA runners, collision traversal, save/load checks, performance
measurements or release acceptance are claimed. Original art, gameplay IDs and
uncommitted work are preserved. No commit or push.

Continue by extending complete-route composition, region-specific material accents and encounter
spacing with the same art language. Whole-map/campaign-wide completion is open.
