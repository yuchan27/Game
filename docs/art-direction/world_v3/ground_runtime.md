# Shared ground material runtime

Checkpoint: 2026-10-23. Runtime owner: `scripts/systems/WorldBackdrop.gd`.
The current pass is art production. Tests/QA suites and performance measurement
were not run by this implementation worker. Parent-owned isolated art captures
must establish the final visual acceptance separately.

## Activation and fallback

`data/art/world_materials_v3.json` must have `version: 3`, explicit top-level
`enabled: true`, and both `ground.earth` and `ground.road` entries. Each entry
contains `path`, `world_size` (default 512 world pixels), and `source_rect`
(`[x, y, width, height]`, default the complete loaded PNG). Source rectangles
must be positive and inside their textures. The existing RuntimeAssetLoader
caches PNG textures and supports native files as well as imported resources.

Missing/disabled configuration, malformed material entries or unavailable PNGs
retain the previous wasteland surface renderer. An unreviewed generation can
therefore remain `enabled: false`. No activation claim follows from this source
integration alone. Village and guild retain their existing renderer.

## Drawing contract

Each existing 16-by-16-tile backdrop chunk draws one opaque rectangle with a
native Godot CanvasItem shader. At the current 32-pixel tile size it covers
512 world pixels. Earth and cobble use absolute world coordinates and the same
pixel origin in every chunk, rather than restarting or randomly cropping at
tile boundaries. Their configured 512-world-pixel repeat does not imply a
32-pixel tile checker. Both textures use nearest filtering. Output coordinates
snap to two world pixels so material transitions share the intended pixel scale.

The shader retains the source pixel structure and compresses earth/road contrast
toward a common warm charcoal (`0.16, 0.145, 0.125`): earth retains 68% and road
72% of its original variation. A broad, low-contrast grain field multiplies the
blended surface by 0.97–1.03, giving roughly 218-world-pixel patches without
blurring or resampling either PNG. This bounded adjustment follows parent review
of the first full-resource captures, where terrain competed with the hero/props;
the parent subsequently inspected the updated isolated render and accepted this
bounded material integration across six representative routes.
Regional multipliers stay subtle:
marsh olive, crystal violet, factory warm brown, city cool slate, facility cyan;
highway retains the common palette. Regional architecture/landmarks remain the
stronger source of identity.

Road masks use the actual `DataRegistry` exploration polylines and `path_widths`,
plus the existing seven-by-five-tile elliptical exploration-point clearings.
Segment distance is sampled once during chunk construction; earth/cobble blend
over a worn shoulder instead of painting rectangular kerbs. A deterministic
24-world-pixel grain field perturbs the margin, evaluated at the same snapped
world coordinates on both sides of every chunk boundary.

Each full-size chunk has a 66-by-66 RGBA mask: 64 interior samples at eight world
pixels per sample, plus one sample of padding on each side. This is a per-chunk
mask, not a 64-pixel full-map mask. Linear mask interpolation supplies continuous
coverage while the source material remains crisp. Shared absolute sampling and
padding avoid restarting the mask at seams. Partial edge chunks size their masks
to their actual dimensions. Chunk bounds prefilter relevant road segments and
ground areas before rasterization.

Static mask caching keys route ID, map size, tile size, actual road/area geometry,
chunk origin and extent; revisiting unchanged route geometry reuses textures.
The shader and PNGs are shared; per-chunk materials keep origin/mask uniforms.
There is no `_process` image work, per-frame CPU rasterization, full-map bitmap,
new dependency or generic terrain framework. This describes implementation, not
a measured frame-rate or loading-time guarantee.

## Basins, drawing order and preserved behavior

Ground areas still come from `data/art/world_v2.json`. Water, chasm, furnace,
rubble and coolant use their existing authored rectangles and kind IDs. A worn
earth/cobble stone apron follows their physical rectangular envelope; only the
inner lip rounds its corners by 12 world pixels. Irregular material transitions
and textured dark interiors replace the old 32-pixel rim bars, chasm grid lines
and uniform furnace rectangles. These are visual masks: no collision owner,
physics bounds, route paths, quests, save IDs or persistent format is changed.
Small corner rounding must still be checked for readable collision boundaries
in the final ordinary art review; broad organic shoreline changes would require
a coordinated collision change and are outside this bounded material pass.

The active material path returns from `_draw_chunk` before the legacy tile
renderer. This matters because the old renderer draws textures immediately and
flushes its queued rectangles, lines and circles afterward: legacy kerbs and
basin rectangles would otherwise cover a new material surface. The complete new
surface remains below the existing scene props, architecture, characters and
gameplay overlays, retaining the current scene draw order.

## Parent production review and remaining scope

The parent rendered and inspected the six representative route views plus highway
arrival after the final shader/source synchronization. The final ordinary render
exited 0 without observed logged errors. Source identities and capture hashes are
recorded in `captures/source_snapshot.json`; this is bounded art evidence, not a
QA, collision-traversal or performance result. Complete-route repetition, density
and encounter composition remain open beyond these views.

For subsequent complete-route composition, continue inspecting:
highway arrival and a road fork; marsh shoreline/causeway; crystal chasm edge;
factory furnace apron; city street/architecture feet; facility coolant boundary.
Inspect at gameplay scale for seams, source repetition, pixel density, overly
soft shoulders, collision-envelope readability and contact with scene props.
The implementation worker performed source inspection only; the ordinary render
and bounded visual disposition above were performed separately by the parent.
No QA pass, performance result or complete-map approval is implied.
