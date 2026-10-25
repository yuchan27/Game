# World v3 shared material production

Checkpoint: 2026-10-23. Production source batch ready and parent-approved for integration. The shared slate,
umber earth, weathered oak and dark iron material family addresses the current
floor/prop mismatch. This is a material kit, not a scene wallpaper. Existing
world v2 PNGs and original R-17 art are preserved.

## Ready status

| Asset | State | Intended runtime use |
| --- | --- | --- |
| `assets/world_v3/ground/slate-earth-v3-01.png` | Original generated PNG copied, native viewed; parent approved palette for integration trial | 512 world-pixel repeatable earth/verge surface |
| `assets/world_v3/ground/broken-royal-road-v3-01.png` | Original generated PNG copied, native viewed; parent approved material/style for integration | 512 world-pixel repeatable worn slate/earth royal road |
| `assets/world_v3/props/medieval-debris-v3-01.png` | Original generated PNG copied, native viewed, actual alpha crops recorded; parent approved material/style for integration | Eight small modules sharing the ground palette |

The activation contract is `data/art/world_materials_v3.json`. `enabled`
is true after the parent inspected all three source images. Ground texture native
detail is moderately busy: actual 512-world-pixel presentation must be reviewed
before a finished floor-cohesion claim. Seamless repetition is a generation
request; no mathematical seam certification is claimed.

## Source and provenance

Built-in `image_gen` produced the PNGs. No paid API/key fallback, Python painting,
pixel repaint or extracted commercial-game art was used. Each generated original
is copied unchanged into `assets/world_v3/`; the generation service's source copy
also remains preserved. Exact prompts are in `assets/world_v3/prompts/`.

References inspected before generation:

- `assets/sprites/player/redesign_v2/source/r17_blade_contact_a_v007.png`: approved hero identity, pixel-cluster and scale reference.
- `assets/world_v2/kits/highway-architecture-v2-01.png`: existing game scale/perspective reference; industrial material identity is intentionally not copied.
- The new earth PNG was the material reference for the road; both new ground PNGs and R-17 informed the prop atlas.

Requested dimensions were 1024-square for both grounds; actual generated original
dimensions are 1254-square. The manifest records actual source dimensions rather
than guessing a requested size. The prop atlas is 1536x1024 RGBA, with 1,115,038
fully transparent pixels and maximum alpha 254. Its eight largest connected
components were inspected at alpha >=192; explicit disjoint crop bounds include
the actual alpha >=96 object/debris pixels within manually reviewed regions.
The diffuse fringe can be discarded at runtime with alpha cutoff 0.5. Pixels
were read for metadata only; no source pixel editing or image resampling occurred.
Runtime filtering and world scale belong to the integration owners; PNG source
bytes remain unchanged.

| Module key | Crop (source x,y,w,h) | Absolute source foot | World width |
| --- | --- | --- | --- |
| `rubble_a` | 18,292,364,212 | 200,477 | 112 |
| `rubble_b` | 400,352,295,144 | 548,474 | 88 |
| `wall_stub` | 714,188,367,327 | 902,479 | 168 |
| `wagon` | 1081,223,435,286 | 1300,477 | 184 |
| `thorn` | 52,649,280,269 | 191,883 | 78 |
| `dry_grass` | 396,759,272,153 | 531,883 | 60 |
| `supply` | 725,664,415,261 | 946,891 | 108 |
| `waypost` | 1184,588,299,340 | 1334,887 | 66 |

Physical footprints are conservative authored estimates, not collision-playtest
evidence. Thorn and grass have no blocking footprints. Manifest SHA-256 records
identify each unchanged source PNG; source prompts are saved with each asset name.

Parent approved the shared slate/umber/oak/iron source material language and
pixel style, then inspected the combined ordinary scenes across six route themes
plus highway arrival. The bounded common-material integration is accepted;
`captures/source_snapshot.json` records the final matching sources and outputs.
This does not establish complete-map composition, collision or campaign-wide QA.

## Portable continuation

1. Inspect source PNGs with a native image viewer. Confirm palette, silhouettes,
   oblique top visibility and genuine alpha in the prop atlas.
2. Use explicit source rectangles and absolute source-pixel feet from the manifest.
   Do not derive crop rectangles from a uniform 4-by-2 grid: generated spacing is
   not a binding contract. Physical footprints are world pixels relative to feet.
3. Integrate shared earth/road materials across all six routes with restrained
   regional color variation, preserving route geometry and existing game IDs.
4. Inspect an isolated ordinary gameplay art capture with the current 96-pixel
   hero. This is production art review; gameplay/QA suites remain deferred.

This asset owner does not modify Player, WorldBackdrop or Wasteland source,
run tests/QA, remove files, commit or push. Parent owns runtime activation,
combined world composition, final captures and the main handoff.
