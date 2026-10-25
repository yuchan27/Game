# Highway coach stop: proportion, circulation and ground contact

2026-10-23. Integrated ordinary art-production checkpoint. Whole-world, gameplay
and release acceptance remain open. The user's rejection of isolated props over
an unrelated floor remains the governing requirement.

## Evidence-led composition

The preceding control showed a coach about 191x127 world pixels beside a roughly
100-pixel hero, separated from the shelter by broad unstructured ground. Both
source images already share an oblique view, muted stone/umber materials and
soft upper-left light. Independent review recommended correcting scale and
circulation while preserving them. No new raster source was generated.

`visual_assets.json` gives `prop_highway_bus` a 348x232 target instead of
208x139. Ordinary runtime diagnostics record:

| Registration | Final value |
| --- | --- |
| Coach world anchor | (3404,3235.6), unchanged |
| Visible bounds | (3243.92,3023.08), size (320.16,212.52) |
| Collision bounds | (3257.041,3152.987), size (296.7552,60.87286) |
| Source sampling scale | 0.212308; previously 0.126897 |
| Story walk-up | (3584,3225.6), normalized (0.5,0.6), unchanged |
| Interaction | `event:scrap_highway:story_scrap_manifest`, radius 112 |

The small shelter remains at (3824.128,3360), width 400 and source scale
400/1536 = 0.260417. Coach sampling is now closer, not identical. Camera zoom
and architecture position were not changed to hide a crop. Player capsule
radius is 18/height 54; 112 is E reach. Source geometry leaves the east approach
available; no walking or collision-angle verification was executed.

Original coach source: `assets/world_v4/landmarks/evacuation-bus-v4-01.png`,
1536x1024, SHA-256
`10a3c6405ae3c51747605a4b87db505781cf1f273e5151e1d8d45ddfea5e073c`.
Shelter: `assets/world_v4/architecture/roadwarden-shelter-v4-01.png`.
Source PNG bytes remain unchanged.

## Connected shoulder and forecourt

The trunk remains 8 tiles/256 pixels wide. After (0.44,0.606), the west feeder
now passes through (0.47,0.615) and (0.5,0.613), then returns to the fixed
walk-up (0.5,0.6). Its centerline passes below the larger vehicle. A sixth path
with matching 3-tile/96-pixel width joins (0.5,0.635), (0.5335,0.635) and the
shelter opening (0.5335,0.625), between the registered supports. Ground and M map
both consume these existing route paths.

`world_v2.json.routes.scrap_highway` adds an irregular nonblocking `rubble`
area in world bounds approximately (3260,3220,740,235). Its outline follows the
shoulder/forecourt; the existing dry-ground shader exposes sparse stone through
shared earth. A short wall at (3935,3390) frames the eastern pier; nonblocking
rubble at (3935,3430) breaks its root edge. The wall uses the existing
`scrap_wall` to `wall_stub` material-kit alias with legacy fallback. New cover
uses the existing saved-position exclusion. The wall adds its registered small
blocker; the rubble and ground area add no collision.

Region `scrap_highway.paving_continuity` is 0.7, retaining a central road spine
with worn shoulders. This is highway-wide presentation, not a local decal.
Other Wasteland regions retain default 0 and Village retains 0.8. Masks remain
population-time work; no new per-frame mask generation or measured speed claim.

## Readability and old-entry compatibility

The first scale draft hid R-17 behind the coach. Optional bus metadata
`fade_when_occluding` now registers its sprite/bounds in the existing parallel
architecture-occlusion arrays, cached alpha BitMap and 0.2-second updater.
Opaque-source probes select alpha 0.32 when it obscures the hero and 1.0 at the
clear story approach. Final ordinary logs/images record both. Collision remains
solid independently of opacity.

There is no general saved-player escape helper in this source. Optional
`saved_position_fallback_size: [208,139]` keeps the old coach size for a saved
entry whose player lies in the larger bounds grown by 48 pixels. The first
instance is removed before occlusion registration; its replacement retains
source, anchor, ID and blocking role. Other entries use the larger size. There
is no save-format change. Independent source review found the sequencing
consistent; this saved-entry branch/save-load compatibility was not executed.

At 1024x768 the original world E label fell behind the quest panel. Optional
highway `story_site.hud_prompt` now names the selected clue in the existing HUD
hint row. E selection/reach, event callback and rewards remain unchanged. Other
story sites retain their current prompt mode. Normal modal visibility hides the
row behind M. The short wall/rubble were moved inward after narrow review.

## Evidence and remaining acceptance

[`captures/convoy-court/README.md`](captures/convoy-court/README.md) records
14 ordinary frames, seven per supported size, 102 matching source inputs and
two final render exits 0 with no observed script/engine errors. Sixteen physics
frames settle the existing occlusion cadence; native camera/zoom/HUD remain.
No input, E action, quest/reward, saved entry, walking or QA was executed.

Parent and independent paired review found the story approach reads as one
coach stop. Reinspection confirmed the narrow E hint and inward wall fixes.
This is bounded local evidence. The old northwest view shows intentional coach
fade; other approach/forecourt views crop peripheral parts or put them behind
HUD. No all-angle, full-route/world or player acceptance is established. Distant
flat ground, isolated props elsewhere, repeated entrances and other regional
composition remain, alongside the full production ledger.

繁體中文：保留原巴士與驛站圖，修正比例，讓路肩、主路與前庭接在一起。角色被
車體遮住時沿用既有淡化機制，名冊提示改到底部提示列。主要調查鏡頭已有完整
停靠站的關係；其他視角、全路線和全世界仍待整理。舊存檔尺寸回退只有來源審閱，
沒有實際讀檔、移動、調查或 QA 驗證。
