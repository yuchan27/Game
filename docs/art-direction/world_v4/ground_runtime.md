# World v4 ground runtime

Historical source checkpoint: 2026-10-23. Runtime owner:
`scripts/systems/WorldBackdrop.gd`. This note preserves the original source
integration and reasoning. Later hub and entrance work supersedes its camera
status. For current runtime/art ownership, see [the v4 art index](README.md) and
[City street/cold ground](city_street_block.md). The earlier regional/coach snapshots
[retains its earlier contract](convoy_courtyard.md). The earlier
[hub presentation](hub_presentation.md) and
[entrance/readability checkpoint](entrance_readability.md) retain historical
contracts. Documented historical entrance camera evidence is the
[26-frame gate/entrance capture set](captures/gate-entrances/README.md).
The earlier coach-stop batch records 14 ordinary frames; highway
`regions.scrap_highway.paving_continuity` now selects 0.7 through the same shader
setting. Factory now selects 0.6; other Wasteland regions retain default 0,
and Village remains 0.8.
Project-wide completion and deferred QA are tracked in
[`../../PRODUCTION_STATUS.md`](../../PRODUCTION_STATUS.md) and
[`../../RELEASE_READINESS.md`](../../RELEASE_READINESS.md).

## Material sampling

The active loader still reads data/art/world_materials_v3.json. Its schema is
unchanged: an enabled version-3 manifest supplies the earth and road PNG paths,
source rectangles and world sizes. The shader samples both sources with nearest
filtering and snaps world coordinates to one world pixel, aligning their detail
with the character and prop pixel scale. WorldBackdrop.gd does not modify the
source images.

If the manifest, regions or source textures are unavailable, the existing
wasteland surface renderer remains the fallback. A later hub checkpoint applied
this sampler to Village/Guild with separate world-pixel lane/plaza data; it does
not load Wasteland route geometry. Original hub floors remain fallbacks. The
subsequent entrance/readability pass is the current owner for Village street
composition and its camera review; the earlier hub capture set is historical.

## Roads, basins and architecture feet

The per-chunk RGBA mask keeps the existing channels: red stores route-road
coverage, green stores authored basin coverage, and blue stores basin kind. Alpha
stores the architecture-foot apron. Road geometry still comes from the active
route paths and exploration points; basin rectangles still come from
data/art/world_v2.json.

For the apron, each placement in world_v2.json is converted from normalized
world position, then each rectangle in that module's footprints is translated
to world coordinates. Each rectangle produces its own field, so the spaces
between separate supports retain the authored walkway openings. The field fades
road coverage toward earth over a locally varying shoulder no wider than 24
world pixels. It changes the earth/road mix only; it adds no black strip, fake
shadow overlay, collision or other physics.

The mask remains sampled every eight world pixels with linear interpolation and
one padded sample around each chunk. Its static cache identity includes the
route, map and tile sizes, road geometry, basin geometry, architecture-foot
geometry, chunk origin and chunk extent. The shader and source textures remain
shared across chunks, with per-chunk origin and mask parameters.

## Review boundary

Parent integration also registers actual placed prop feet once after population.
WorldBackdrop refreshes masks only for chunks intersecting those feet; unrelated
chunks keep their material/mask. Nonblocking props use a narrow visual root,
blocking props supply their existing physical bounds. A broad wear field breaks
up paving coverage, so road stones do not continue as a clean carpet under wheels
and foundations. There is no per-frame mask work or added collision. Native
frame/loading time and memory behavior have not been measured.

The earlier rejected v3 composition is recorded at
[world_v3/captures/highway-convoy.png](../world_v3/captures/highway-convoy.png).
Its large repeated cobbles and architecture-to-ground contact are the reason for
matching ground detail to the character scale and deriving the apron from
registered physical feet instead of adding a generic shadow bar. At this note's
checkpoint, the parent was revising the ground and architecture source art under
the existing manifest contract.

At this checkpoint, this implementation was reviewed from source only; no Godot
render, QA suite or performance measurement was run for this change. Later
ordinary renders are documented in the linked entrance checkpoint and capture
README. Those captures provide bounded camera/art evidence only: they do not
establish whole-world art acceptance, gameplay/collision acceptance, QA or
performance. Follow the current status and release-readiness documents for the
user's QA deferral and remaining acceptance work.

## Regional camera correction

Optional region `earth_contrast` is finite numeric 0..1, default0.68; road contrast
follows earth+0.04 (capped1). Earlier Crystal/Factory used0.36/0.26 at192-world-pixel
earth tiling at the late-story checkpoint. The subsequent City street pass selects
new fine cold silt/shale for Crystal/Factory/Facility at512 repeat and unchanged
contrasts0.36/0.26/0.28. City uses quiet packed earth at512/0.48; City/Facility
select damp cut-slate roads at320. WorldProp root dust samples
the same selected earth, tint and contrast. Native broad shoulder wear softens
road transitions. These later regional data choices supersede the original
City/Facility whole-surface paving; original sources are preserved.

The later Village hub layout sets `paving_continuity` to 0.8 to retain a readable
central paving core while the shoulders weather into earth. The shader/runtime
default is 0.0. Village selects 0.8 and the later highway region selects 0.7;
Factory later selects 0.6; Guild and the other Wasteland regions keep
the previous broken-paving behavior. This is a visual material setting, not a
walkability or collision guarantee. Its current source and review are in
[`entrance_readability.md`](entrance_readability.md) and
[`captures/gate-entrances/README.md`](captures/gate-entrances/README.md).

## Later regional water adapter

The earlier regional-courts pass added optional `regions.toxic_marsh.water` with
PNG `path`, `source_rect` and finite `world_size`. A valid source is sampled
nearest in world coordinates only for water-kind basins; the shader keeps the
existing basin/rim mask and uses broken muted silt at the bank. Missing/invalid
optional art retains the earlier flat-water fallback without disabling ground.
Active `stagnant-silt-water-v4-02.png` repeats over 416 world pixels; v4-01 is a
preserved rejected denser draft. No new terrain collision, TIME animation or
per-frame mask generation. This fallback is source-reviewed, not executed.
At that checkpoint Crystal contrast became0.36 at192 repeat; Factory stayed0.26.
The subsequent City street pass replaces their selected source/repeat as above.
Current paired art evidence and remaining acceptance: [City street/cold ground](city_street_block.md)
and [captures](captures/city-street-block/README.md); the earlier regional set
retains the water adapter's initial evidence. No gameplay, performance or QA claim.
