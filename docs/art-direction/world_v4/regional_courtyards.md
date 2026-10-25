# Marsh service court and crystal excavation bay

2026-10-23. Integrated art-production checkpoint; full-world, gameplay and release
acceptance remain open. The user's rejection of pasted objects remains authoritative.

## What the actual cameras showed

The comparable `captures/regional-courts/draft-before-gl/` views use the native
camera and HUD at 1280x720. The marsh house was stranded at lower left, its small
valve separated by a broad paving pad; water was a flat teal polygon. The crystal
stood alone on a broad dark plane. The first narrow revision also showed the tall
crystal peak behind the quest panel and a nearby wall cut off at the right edge.
These are observed composition defects, not inferred performance or gameplay bugs.

The correction keeps useful existing art and gives each encounter a connected
approach, a related structure and ground at their feet. It does not scatter more
independent objects across the whole map or change the camera to hide clipping.

## Toxic Marsh

The route remains 6656x5888. The story walkup `(3061.76,3002.88)`, valve anchor
`(3241.76,3012.88)`, `story_marsh_ledger`, 112-pixel E reach and registered feet
remain. The neighboring `marsh_pumphouse` placement #3 moves from `(0.412,0.539)`
to `(0.425,0.535)` = `(2828.8,3150.08)`. Its PNG, crop, width 420 and local
footprint `[-166,-63,328,80]` are unchanged. Existing 48-pixel saved-position
exclusion still governs architecture loading; this saved-entry branch was not run.

The first main path narrows from eight to six tiles (256 to 192 world pixels)
along its complete length. Two three-tile/96-pixel service branches join the
southern lane to the house frontage and valve forecourt:

- `(3061.76,3235)` -> `(2915,3235)` -> `(2785,3235)`.
- `(3061.76,3120)` -> `(3140,3060)` -> `(3220,3045)`.

An irregular nonblocking rubble area joins these feet and approaches through the
existing shared-earth renderer. One nonblocking `rubble_b` at `(3010,3190)` breaks
the house root edge. Eight paths have eight widths. No water polygon or physical
foot size was changed, and no water collision was removed to make the image fit.

Optional `regions.toxic_marsh.water` in `world_materials_v3.json` selects
`stagnant-silt-water-v4-02.png`, crop `[0,0,1254,1254]`, repeat size 416 world
pixels. `WorldBackdrop` validates that optional source, rectangle and finite
world size, then samples it with nearest filtering in world coordinates only for
water-kind basins. A muted broken silt bank uses the existing basin/rim mask.
Missing/invalid optional art leaves the earlier flat basin rendering available
without disabling earth/road. The four blocking water outlines and their physical
collision construction are unchanged. No TIME animation, per-frame mask rebuild
or extra terrain node was introduced; no performance comparison was made.

The first generated water source was too earth-like, especially at a 224-pixel
repeat. Independent wide-frame review rejected its moss-like density. V4-02 is
an edited sibling with fewer grit marks, quieter dark liquid masses and sparse
horizontal glints. V4-01 remains preserved and inactive. The final parent review
finds liquid separation clearer; angular banks and whole-route variety still
need broader player/visual acceptance.

## Crystal Scar

The route remains 6912x5888. The story walkup `(3456,3650.56)`, landmark foot
`(3276,3660.56)`, `story_crystal_echo`, reach and physical footprint
`[-51.18505859375,-45.296630859375,118.145500183105,35.4496078491211]` remain.
The first full southern path narrows from ten to seven tiles (320 to 224 pixels).
A three-tile branch loops south/west from the unchanged walkup through
`(3456,3785)`, `(3320,3785)` and `(3200,3740)`. Seven paths have seven widths.

Unpaired `crystal_buttress` placement #10 moves from `(0.36,0.41)` to world
`(3690,3650)`. Its source and four stepped physical feet retain their exact sizes.
Placement #3 remains `(0.62,0.59)` with its original East crossing survey spur;
the first draft moved #3 and was corrected to preserve that contextual pairing.
The existing saved-position exclusion remains. The two chasm outlines remain.

An irregular nonblocking rubble floor and three nonblocking pieces of road scatter
join the excavation bay: `rubble_a` `(3390,3720)`, `rubble_b` `(3610,3770)` and
`crystal_node` `(3280,3790)`. They intentionally overlap parts of the paving and
add no collider. Earth contrast is 0.36 at the existing 192-pixel repeat;
Factory remains 0.26. This is regional presentation, not measured optimization.

`resonance-outcrop-v4-02.png` is a newly authored compact sibling preserving the
purple shale/bronze recording-ring identity. Its shorter continuous mineral fan
fits below the narrow quest panel at the actual story view and samples more
finely beside the existing wall. Registration in the existing prop adapter:

| Field | Value |
| --- | --- |
| Source | 1303x1207 RGBA, original bytes retained |
| Crop | `[68,105,1162,1001]` |
| Source foot | `[645,1030]` |
| World width | `216.139999389648`, unchanged |
| Saturation / exposure | 0.86 / 0.88 |
| Native sampling scale | 0.186007; preceding crop was 0.617543 |
| Current visible bounds | `(3168.674,3488.504)`, size `(216.14,186.1929)` |
| Physical bounds | `(3224.815,3615.263)`, size `(118.1455,35.44961)`, unchanged |

The five-landmark atlas is preserved and still supplies the other four landmarks.
Both new art families have exact built-in generation prompts/provenance under
`assets/world_v4/prompts/`; no Python raster editing or original-image overwrite
was used. Missing optional prop sources retain the existing legacy fallback.

## Readability, evidence and limits

Both routes opt into the existing `story_site.hud_prompt` mode. The existing
bottom hint row names the selected clue; no second overlay panel was added.
Wasteland selection, callbacks, rewards and save formats remain unchanged. M
hides that hint through the existing modal rule. Runtime diagnostics record the
Player capsule at offset `(0,-27)`, radius 18, height 54; its feet must not be
treated as a centered circle when reviewing source clearance.

[`captures/regional-courts/README.md`](captures/regional-courts/README.md) records
18 final ordinary frames, nine per supported size, with two Godot 4.6.3 exits 0,
no observed error/warning lines, 105 matching source/mirror inputs and matching
recipe hashes. Earlier drafts and the fixed inferred-type parse failure remain
recorded; they are not the current source. The preceding coach-stop snapshot is
historical for shared data/shader identity, though its focused art notes remain
useful. A current coach story control is included in this batch.

Parent review inspected the final paired views. Both actual story views have
legible E hints, a visible hero and a connected encounter; the compact crystal's
peak clears the narrow quest panel. Other approach cameras naturally crop or put
peripheral architecture under HUD; the south crystal approach still exposes a
large quiet plane. Repeated walls, distant sparse terrain and whole-route/world
composition remain open. Independent agents reviewed the baseline and first
draft; follow-up independent review became unavailable due to workspace credits.
Final revisions were reviewed by the parent, not independently accepted.

These are staged art states, with no input/E actions, collision walking, active
quest progression, reward, saved entry, save/load, performance or QA execution.
Source-reviewed compatibility is not executed compatibility evidence. No release
acceptance, guaranteed 60 FPS or full-goal completion is claimed.

繁體中文：這輪把泵屋、閥門、道路與水岸整理成維修場，把紫晶改成較低而寬的
礦脈並連到殘壁與採掘區。素材直接接入既有地表與物件系統，舊圖、調查位置、
碰撞尺寸與存檔規格保留。兩種尺寸的主要調查畫面已有改善；其他角度仍可能被
UI 遮住，整張世界、角色動作、完整劇情玩法與 QA 仍未完成。
