# City street frontage and quiet cold earth

2026-10-23. Integrated art production; whole-world/player acceptance remains open.
Current ordinary evidence is in [captures/city-street-block/](captures/city-street-block/README.md).
The full objective remains in [the production ledger](../../PRODUCTION_STATUS.md).

## Observed problem and implementation

Before this change, City had nine church-family placements among thirteen
architecture placements. Two actual southern camera views showed broad empty
earth, a detached church at the edge and no nearby civilian street frontage.
The matched Factory/Facility/Crystal views also exposed conspicuous diagonal
outlined plates in the 192-world-pixel cold-shale repeat. These are observed
composition/material problems, not a performance diagnosis.

Two new original PNGs were produced with built-in image_gen and copied unchanged
into the project. Exact prompts and source references are in
`assets/world_v4/prompts/ash-street-workshop-v4-01.txt` and
`cold-silt-shale-v4-02.txt`. Original church and fractured-shale files remain.
No raster editing, engine rewrite, save-format change or new dependency is used.

The new `metropolis_street_workshop` joins a dwelling and a lower salvage
workshop into one broken street frontage. Its central recess contains workshop
contents; it is not a new traversable interior, gate or interaction. Unpaired
City placement #1 moves from `(4602.88,4608)` to `(4200,4740)`, normalized
`(0.56573276,0.77148438)`. Story placement #3 and contextual-yard pairings
#0/#4/#6 remain. Sixteen module entries now reference eleven architecture PNGs.

## Source, scale and collision contract

`assets/world_v4/architecture/ash-street-workshop-v4-01.png` is 1536x1024 RGBA.
The manually inspected source rectangle is `[19,90,1499,871]`, absolute source
foot `[768,855]`, alpha cutoff0.45 and fixed world width600. Native nearest
sampling and existing foot-based sorting/alpha occlusion remain. The source's
very faint outer alpha is clipped natively; no PNG pixels were changed.

Three overlapping stepped physical feet follow the diagonal front foundations.
They are derived from the following source rectangles with ratio600/1499 and
translated by source foot. They form a solid building base, with no false alley:

| Source rectangle x,y,w,h | Local physical foot x,y,w,h (world pixels) |
| --- | --- |
| 85,650,510,150 | -273.382255,-82.054703,204.136091,60.040027 |
| 575,730,430,140 | -77.251501,-50.033356,172.114743,56.037358 |
| 990,800,430,125 | 88.859239,-22.014676,172.114743,50.033356 |

The first draft used width620 with corresponding feet. Its highest chimney had
very little wide-frame margin. The final fixed width600 improves top/right
space in the frontage view at both sizes without changing camera zoom or using
viewport-dependent physics. Drafts remain recorded. The player-centered bay and
main-road views still naturally crop roofs/side structures; this is not an
all-angle/full-sprite fit guarantee.

The existing saved-player exclusion skips architecture if the initial player
point is inside any foot grown48. A saved point at the close art stance
`(4090,4775)` would trigger it. The recipe moves there only after population;
it does not prove saved entry. The other staged bay stance `(4200,4820)` is
outside the grown feet by source geometry. No saved branch or walking ran.

## Street and shared ground

City's existing eight paths remain; a ninth 3-tile/96-world-pixel frontage joins
`(3712,4840)` -> `(4250,4840)` -> `(4480,4840)` -> `(4480,5038.08)`.
It meets the main spine and existing southern loop. One irregular 12-point
`kind:rubble`, `blocking:false` shared apron is appended in `world_v2.json`.
It adds no collision. Original story/event locations, existing blockers,
earlier paths/widths, decorations, rewards and other route data stay.

The frontage road's north edge is about24 world pixels below the deepest
building foot. Source geometry leaves the center approach clear; neither
full-width movement nor scene-wide hazard clearance was executed. The thin
earth setback between masonry debris and slate paving is intentional.

Crystal, Factory and Facility select new `cold-silt-shale-v4-02.png`, RGB
1254x1254, whole-source crop and world repeat512. Existing tints, contrasts
0.36/0.26/0.28, road sources/scales and paving continuity remain. The new source
uses fine silt with sparse small slate chips instead of large outlined plates.
WorldProp root dust automatically samples the new regional earth. Architecture
still uses its authored foundation art and native cutout material; no horizontal
wash was applied to its walls. The old source remains available as preserved
art, with provenance moved out of the active-source list.

## Evidence and remaining work

Matched ordinary before/after views support a local improvement to civilian
street identity and cold-ground macro-pattern. Source/recipe/log/frame identity
and exact review coverage live in the capture README. Rendering, provenance and
matching color do not prove whole-world artistic acceptance.

Both final processes exited0, recording ten frames each without observed error/
warning lines. The parent inspected all20 final PNGs. Independent final row review
covered the three street views at both sizes: the whole-frontage fits roofs/feet
without HUD overlap, while bay/main-road views retain the described crops. A
separate matched three-wide-view draft comparison supports reduced plate patterns.

Bright sharp rubble remains the new row's strongest focal contrast. Cold
Facility foundations still have warm ochre grass/clods in their authored PNG;
ground replacement does not erase those. Remaining sparse quarters, repeated
architecture, road hierarchy, actual traversal, 32 hero facings, 11 actions,
all UI and complete story/gameplay stay in scope. No tests/QA, gameplay input,
quest action/reward, save/load, comparable performance or export was executed.

繁體中文：都心南街新增相連的民居與工坊，接上主幹道及既有南側迴路；三區冷色
地面改用細碎灰土，降低大片斜紋。尺寸與階梯狀碰撞腳點固定，不隨視窗縮放。
這是局部場景製作，尚未代表整張世界、走位、存檔或完整玩法已驗收。
