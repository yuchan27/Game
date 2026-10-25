# World v4 — correct the rejected full-scene composition

Updated 2026-10-23. **In production; full-world visual acceptance remains open.**
The user rejected the v3 convoy screenshot after the parent called it accepted.
Shared colors were insufficient. Keep that rejection authoritative; a successful
render, isolated source approval or matching palette does not prove cohesion.

## Confirmed defects and current corrections

- V3 road stones occupied roughly two-thirds of the hero height. The current
  road candidate is `buried-slate-cobbles-v4-02.png`, a much finer staggered
  paving source. V4-01 was rejected as sparse random rocks, not readable paving.
- Quiet packed umber earth replaces the dense gravel/noise floor. Road coverage
  breaks into broad worn patches instead of continuing as a uniform carpet.
- The new oblique roadwarden shelter has visible roof/side planes, an open
  approach, registered feet and original authored soil/debris at the foundations.
  The old near-frontal depot remains preserved in its original atlas.
- Eight smaller-unit props replace the coarse outlined kit: slate fragments,
  small-course ruined masonry, broken cart, thorn, grass, supplies and waypost.
  Their crop rectangles and source feet are explicit, not inferred from a grid.
- The evacuation bus keeps its story identity but uses an edited, less vivid
  sibling source with sunken wheels/dust. Original source PNG and gameplay IDs
  remain. Native alpha clipping removes very faint source glow; its artificial
  contact polygons are disabled because the source already contains contact art.
- `data/art/world_materials_v3.json` keeps its schema-3 loader contract while
  selecting the v4 quiet earth, fine paving and eight-prop atlas; the bus sibling
  source is selected by `data/art/visual_assets.json`.
  Four story landmarks retain `ancient-salvage-landmarks-v4-01.png` under their
  existing IDs (`marsh_pump`, `factory_turbine`,
  `evacuation_archive`, `memory_vault`); their registered physical feet are
  preserved from the legacy foot-registration data. The later compact crystal
  uses `resonance-outcrop-v4-02.png` with the same registered physical feet.
  The same manifest selects
  `toxic_pool` only for `toxic_marsh` and `crystal_node` only for `crystal_scar`
  from `grounded-hazards-v4-01.png`.
- Regional ground overrides use fine cold silt/shale in Crystal/Factory/Facility;
  Metropolis uses quiet packed earth beneath its
  damp cut-slate roads. `world_v2.json` retains architecture placement/physical
  feet. All six routes reference 16 module entries and eleven architecture PNGs.
  The City civilian dwelling/workshop row uses fixed width600 and three stepped
  solid feet; three earlier story variants retain their proportional feet.
  Original module definitions and story landmark feet remain intact.
  This confirms source integration only.
- Actual placed prop feet and authored architecture rectangles reduce road
  coverage into the earth at their roots. This changes the shared ground itself;
  it does not draw another opaque shadow plate. Only affected chunk masks are
  refreshed once after prop population, never in `_process`.
- WorldProp per-route root dust samples the selected earth/tint/contrast in world coordinates
  within a narrow registered-foot band, without a whole-object fade or PNG repaint.
  Crystal/Factory/Facility earth uses new fine cold silt/shale at512-world-pixel
  repeat and contrasts0.36/0.26/0.28; Metropolis remains512/0.48. Road contrast
  follows earth contrast plus 0.04; broad shoulder wear avoids a sharp texture slash.
- Story-site E prompts now anchor above the actual landmark bounds rather than
  the offset walk-up trigger. Existing trigger/radius, event IDs and rewards remain.
- `world_v2.json` now also supplies 18 authored contextual yards through its
  existing decoration placements. `drainage_rescue` uses the distinct
  `rescue_relay` device (`prop_rescue_relay` registration), and
  `factory_sabotage` uses `alarm_isolator` (`prop_alarm_isolator`), both cropped
  from `field-mechanisms-v4-01.png`. These are source-integrated, not visually
  accepted. The factory action lowers future normal-enemy replenishment capacity
  by six; it leaves existing enemies and the Boss rule unchanged.
- At a 1024x768 window the old 1280-wide logical canvas shrank all HUD text.
  The baseline viewport is now 1024x720 with a 1280x720 initial window; expand
  stretching retains a 1280x720 canvas at that size and a native 1024x768 canvas
  at the narrower window. Existing responsive HUD/title owners remain intact.

The v4 architecture assignments now cover all six routes, including the highway
boundary, gate and viaduct. Full-camera visual acceptance for the complete set of
routes is still open; source assignments and matching palettes do not establish it.

## Runtime ownership and compatibility

`data/art/world_materials_v3.json` intentionally retains version 3 and its existing
loader path while selecting v4 source PNGs. `world_v2.json` still owns architecture
placements and physical feet. New optional module fields are absolute source
`foot`, native `alpha_cutoff` and `authored_ground_contact`; missing fields retain
the old bottom-center/cutout/contact behavior. Existing sources remain available.

WorldBackdrop owns material sampling and chunk masks. WorldBackdrop and Wasteland
share normalized basin outlines; Wasteland passes actual placed feet once after
scene population and builds four marsh-water, two crystal-chasm, three furnace
and three coolant `CollisionPolygon2D` shapes. The latter correction addresses a
hard rust-colored rectangle found in the factory camera. Rectangular fallback
and 48-pixel escape remain. WorldProp owns source presentation and per-route root
dust. The later [hub checkpoint](hub_presentation.md) extends the shared material
ground/contact pipeline to Village/Guild while preserving original fallback art
and legacy decorative collision bounds. Quest IDs, rewards, save wrapping and player source art are not replaced
by this correction. Collision traversal and old-save regression are not verified
in this art pass.

## Source and review evidence

- [Current civilian City street block and quiet cold earth](city_street_block.md)
- [Current 20-frame paired evidence](captures/city-street-block/README.md)
- A new connected dwelling/workshop source replaces unpaired City church#1,
  joins the southern road loop and retains story/contextual-yard positions.
  Fine silt/shale reduces outlined plate repetition in three cold regions.
  Both ordinary processes exited0;107 listed source/mirror inputs and recipe
  match. Whole-frontage views fit at both sizes; bay/main-road views retain
  roof/edge/HUD crops. Warm foundation grass, repeated architecture and sparse
  quarters remain. This is bounded production art, not whole-world acceptance.

- [Earlier Factory/City/Facility story courts](late_story_courts.md)
- [Historical 32-frame paired evidence](captures/late-story-courts/README.md)
- Three unpaired buildings now share service branches and irregular nonblocking
  aprons with their actual chapter clues. Fixed 390/390/400-world-pixel variants
  correct the first narrow crop; material hierarchy separates earth and roads.
  Factory paving continuity is 0.6, Highway 0.7 and Village 0.8; other regions
  retain default 0. Guild's active-contract hint now points to its actual gate.
  Both ordinary processes exited 0; 105 listed source/mirror inputs and recipe
  match. Parent reviewed all wide frames; independent review covered all narrow
  and nine wide frames. Main story views improve; turbine close-view occlusion,
  peripheral HUD/edge crops, broad Factory paving, subtle Facility paths,
  repeated architecture and sparse terrain remain. Whole-world acceptance is open.

- [Earlier marsh/crystal connected courts and registered art](regional_courtyards.md)
- [Historical 18-frame paired regional evidence](captures/regional-courts/README.md)
- Optional marsh water uses a world-space pixel source and the existing bank
  mask; a compact crystal source preserves its story anchor and physical feet.
  Both regional approaches now connect their related architecture and ground.
  Final paired art review is by the parent; independent review covers baseline
  and early draft only. Whole-world and player acceptance remain open. The
  previous coach snapshot below is historical for shared source identity. Current
  Highway/Marsh/Crystal story controls appear in the late-story batch above.

- [Earlier highway coach-stop composition](convoy_courtyard.md)
- [Historical 14-frame paired coach-stop evidence](captures/convoy-court/README.md)
- The coach source now has corrected world scale and physical presentation,
  old-size saved-entry fallback and native occlusion fade. Its shoulder/feeder
  and shelter forecourt share route ground; the main clue uses the existing HUD
  hint row. Paired review found a coherent local approach; whole-world/all-angle
  acceptance remains open. No QA was run.

- [Earlier entrance and connected trade-court composition](entrance_readability.md)
- [Historical 26-frame entrance/readability evidence](captures/gate-entrances/README.md)
- The Guild entrance now has its own slate/oak source; east-quarter branches reach
  actual frontages and the threshold. Two registered wall segments and optional
  Village-only central paving continuity frame the eastern street. Village E context uses the original HUD hint
  row rather than an extra world overlay. Hub M roads read the drawn lane data.
  This is a local composition improvement; the user's whole-world pasted-object
  objection remains open. Earlier camera batches below are historical snapshots.

- [Hub materials, residential frontage and story cistern](hub_presentation.md)
- [Historical hub and representative wilderness cameras](captures/hubs/README.md)

- [Road, convoy, sorting, event and map correction](road_and_convoy.md)
- [Historical road/convoy camera evidence](captures/road-and-convoy/README.md)

- [Terrain sources and rejected candidate](terrain_sources.md)
- [Ground sampling and footprint masks](ground_runtime.md)
- [Optional prop-root binding](prop_contact.md)
- Exact generation prompts: `assets/world_v4/prompts/`
- Original PNG sources: `assets/world_v4/`
- Ordinary capture recipe: `captures/ArtPreview.gd.txt`
- Rejected previous full view: `../world_v3/captures/highway-convoy.png`

Draft outputs under `captures/` intentionally record iteration. The first v4
draft still used the rejected v3 road; later road/contact drafts show the new
paving and prop kit but predate the latest six-route architecture, landmark,
hazard and collision integration. Their logs describe ordinary Godot rendering,
not QA, and do not establish acceptance of the current source. Current ordinary
historical outputs, render logs, source identity and review limitations are recorded in
[`captures/current-production/README.md`](captures/current-production/README.md):
twelve local cameras at each of 1280x720 and 1024x768. Their existence does not
close whole-route composition, traversal or player acceptance, and this snapshot
predates the 18 contextual yards and the new relay/isolator devices. The later
[`captures/chapter-sites/README.md`](captures/chapter-sites/README.md) records
27 wide / 15 narrow ordinary frames, their source identity and local review.
It includes context/device/J/title/prologue and the bus-story camera. Dry rubble
now uses broken low-coverage stone without a solid rim, and distant device status
text is hidden while map markers remain. Broad roads, repeated wagon silhouettes
and whole-route composition still need work; player acceptance remains open.
Source integration and staged completion images do not establish gameplay or
save/load validation, and no QA was run for this batch.

The subsequent road-and-convoy checkpoint adds two wagon silhouettes, grouped
prop-foot sorting, narrower/chamfered highway paths, a shoulder median, grounded
ordinary event remnants, short map labels and wrapped notices. It records 28
ordinary frames with matching source identity. Its Village/Guild views expose
the then-unresolved legacy metal/neon hub style; these are historical diagnostic
frames. The later hub checkpoint replaces that presentation and records current
ordinary camera evidence; full-world/player acceptance remains open.

Use an external project copy and an explicit dedicated custom user directory
for all art renders; pass an absolute `--art-output` path. Never run this recipe
against the real player save. No tests/QA, collision playthrough, save/load,
performance improvement, exported build or release acceptance is claimed here.

繁體中文：這輪先修正「拼貼感」，舊版的審閱結論已被使用者退回。必須以完整
遊戲鏡頭確認尺度、俯視角度、接地、道路與 UI；單張素材好看不代表整張畫面成立。
目前優先完成全場景美術，但尚未通過全世界驗收；再處理剩餘故事與玩法缺口。
完整目標仍未完成。
