# Road, convoy, map and grouped-foot checkpoint

Historical source snapshot: the later `../hubs/` batch changes shared material
helpers and hub presentation. These images do not represent that newer source.

2026-10-23. **Ordinary isolated art/UI rendering, not tests/QA or release acceptance.**
This follows `../chapter-sites/`; that older batch does not cover this source.

- 14 current frames per size: six representative wasteland contexts, original
  bus-story camera, two highway corners, fullscreen M map, two pending field
  devices, Village and Guild. Wide is 1280×720; `1024x768/` has the narrow set.
- Godot 4.6.3 (`7d41c59c4`), Compatibility/OpenGL 3.3 on Intel Arc 140V.
  Both final batch processes exited 0 with no observed script/engine errors.
- `source_snapshot.json`: 98 runtime/scene/data/v4-PNG inputs match the isolated
  mirror, 28 current PNG dimensions/hashes and one separate historical comparison.
  Inactive candidates and test-script hashes are identity only, not activation
  or execution. Legacy PNGs are outside this hash record. Two Python source
  hashes are recorded separately and were not executed as tests/validation.
- Dedicated userdata was `R17-Ordinary-Art-Preview-20261023`; real saves were not
  loaded. Pending quest/material/kill state was manually seeded for art review.

Portable recipe: `../RoadAndConvoyPreview.gd.txt`, copied to an isolated Node
scene as `ArtPreviewV4.gd`. Use `--rendering-method gl_compatibility
--audio-driver Dummy --resolution 1280x720 res://ArtPreviewV4.tscn --
--art-output=<absolute directory>`, or `1024x768`. Both sizes render the same
14 views. `--art-view=highway-convoy-yard` selects one wasteland camera and skips
hub cameras; the bus camera also saves the fullscreen route map.

## What the frames establish

`before-foot-sort.png` is an intermediate comparison, **outside current source
equivalence**: it already uses the new wagon atlas but still sorts each sprite
by its canvas top. The current convoy view shows its canopy and near wall in
the intended foot order. See `../../road_and_convoy.md` for crop/foot contracts,
source hash, the native Godot sorting rule and unchanged physical footprints.

The west-turn frame shows the median moved to the shoulder; the map frames show
connected route endpoints and readable essential labels instead of overlapping
resource names. A reviewer found duplicate region/site names in the first map
revision; the final source suppresses nearby duplicate region names. The parent
inspected corrected wide/narrow map frames after this final change.

The parent inspected representative current world, field and hub frames at
both sizes. A separate read-only reviewer inspected the preceding same-runtime
batch before the duplicate-region-label correction. It confirmed the distinct
convoy silhouettes, visible shoulder relocation, grounded regional props and
readable device prompts, and identified the region-label issue then corrected.
Ordinary event remnants now use the active world kit in place of floating
inventory icons. HUD notices wrap and sit below objective/minimap panels.
Loose item pickups retain their own icons at a maximum 28 world pixels, with
one-pixel bobbing and unchanged pickup reach. They are deliberately small loot
glyphs; do not confuse them with the newly grounded event props.

## Remaining production scope

Village and Guild visibly retain legacy metallic floors and neon equipment:
this is a confirmed remaining P1 style mismatch and the next art priority.
These hub frames document that gap; they are not approved hub redesigns.
The highway remains a recognizable loop/spine network; its small centreline
bends are subtle and whole-route environmental composition is unfinished.

No traversal, physical clearance, hover interaction, quest action, save/load,
reward, frame-time, memory, exported build or release behavior was verified.
The validator and two existing regression contracts were updated to match the
new geometry/foot-sort rules but were **not run**. Keep the full objective active;
hero facings/actions, hub art, full UI/story/progression and later QA remain.

繁體中文：本批改善重複車體、錯誤遮擋、道路被殘牆橫跨、地圖文字和長通知。
保留修改前畫面作比較；村莊與公會的風格落差仍明確列為下一項工作，未執行測試。
