# Factory, city and facility story courts

2026-10-23. Integrated production changes; whole-world, player and release
acceptance remain open. Continue the full ledger in `docs/PRODUCTION_STATUS.md`.

## Observed defects and composition

The three comparable native 1280x720 `captures/late-story-courts/before/`
screenshots showed isolated turbine/archive/vault props with no related building
in view. City and Facility used damp paving as their entire base ground, so a
second road material looked like a patch over a stone carpet. Factory's very
broad crossroad similarly lacked a useful relation to the story object.

This pass reuses existing source PNGs. One unpaired building per route joins the
story scene, with service forks and an irregular nonblocking shared-ground apron.
No additional loose prop scatter, raster generation, engine rewrite or saved-data
format is needed. The original six clue IDs, walkups, reach and rewards remain.

The first wide arrangement fit, but paired 1024x768 views exposed left-edge crops.
Three fixed authored module variants reduce world width and scale their local
physical feet proportionally. They use the same PNG, source rectangle and source
foot as their base modules. These are world dimensions independent of window
size; physics does not change when the viewport changes. Original module
definitions and every other placement retain their existing contracts.

| Route / unpaired placement | Story module / width | World anchor | Local physical footprint |
| --- | --- | --- | --- |
| `old_factory` #4 | `factory_furnace_story`, 390 (base 420) | 3500,2540 | `[-169,-65,338,81.714286]` |
| `ruined_metropolis` #3 | `metropolis_bell_story`, 390 (base 420) | 3480,3205 | `[-169,-57.571429,338,78]` |
| `underground_facility` #3 | `facility_lab_story`, 400 (base 460) | 3105,2960 | `[-178.26087,-60.869565,356.521739,76.521739]` |

The manifest now contains 15 module entries referencing the same ten architecture
PNGs. The native architecture loader reads these registrations without a new
code path and retains its existing 48-pixel saved-player exclusion. That saved
branch was source-reviewed only. A source comparison confirmed the original
module definitions, all existing decorations, earlier ground areas and contextual
yard pairs remain: Factory #0/#2/#6, City #0/#6/#4, Facility #4/#6/#5.

## Ground and circulation

Each route retains its extent and original story landmark anchor/physical bounds:

| Region | World extent | Story walkup | Landmark foot | Main path width before -> now |
| --- | --- | --- | --- | --- |
| Factory | 7168x5632 | 3727.36,2421.76 | turbine 3937.36,2431.76 | 12 -> 7 tiles |
| City | 7424x6144 | 3712,3072 | archive 3937,3092 | 14 -> 8 tiles |
| Facility | 6656x6144 | 3328,2826.24 | vault 3553,2846.24 | 11 -> 6 tiles |

These first-path width changes cover their complete southern spines, not just the
camera area. Each route has eight paths/eight widths after two 3-tile/96-pixel
service branches are added. Ground and existing M map read the same route data:

- Factory frontage: `(3727.36,2630)` -> `(3590,2640)` -> `(3430,2640)`;
  clue fork: `(3727.36,2490)` -> `(3930,2490)`.
- City frontage: `(3712,3300)` -> `(3435,3300)` -> `(3380,3290)`;
  clue fork: `(3712,3150)` -> `(3900,3150)`.
- Facility frontage: `(3328,3055)` -> `(3150,3055)` -> `(3040,3055)`;
  clue fork: `(3328,2915)` -> `(3530,2915)`.

Each new 13-point `kind:rubble`, `blocking:false` apron follows these connections
in `world_v2.json`; it uses the existing broken low-coverage earth/road rendering.
No new apron collision is generated. Existing furnace, rubble and coolant hazard
polygons remain. Source geometry preserves capsule clearance on the center
approach, but neither path walking nor full-width clearance was executed.

City base ground is quiet packed umber earth at repeat512/contrast0.48, with damp
cut slate at320 for its roads. Facility uses quiet cold shale at192/contrast0.28
and damp cut slate at320 for roads. Its cool tint stays. Factory keeps its sources
and selects existing paving continuity0.6 so its work court has a connected spine.
WorldProp root dust automatically samples the same selected regional earth/tint.
These material changes cover the complete respective regions. No shader change,
new per-frame mask work or measured performance improvement is claimed.

## Clue and campaign readability

All three late clues now opt into the existing screen-safe HUD E hint. The source
selection/reach/event callbacks remain, and the original physical landmark feet
are not resized along with their neighboring architecture. Native diagnostic
logs retain actual landmark visual/physical bounds and Player capsule offset
`(0,-27)`, radius18 and height54. The rendered hero stays readable in the main
story views. Peripheral roofs may still fall behind HUD in other approach views.

A separate confirmed hint mismatch was fixed in `GameState.get_journey_hint()`.
With an unfinished active quest inside Guild, it previously told the player to
leave from Village even though the Guild departure gate routes directly to the
contract. A Guild-specific two-line branch now names the Guild gate; Village,
Wasteland, ready-to-deliver and no-active-quest branches retain their previous
behavior. `guild-active-journey-staged` manually assigns the factory contract and
opens J to review this text. It does not execute acceptance or prove progression.
The first four chapter contracts remain freely selectable for legacy/free-roam
compatibility; no speculative prerequisite restriction was added.

## Current evidence and remaining acceptance

Current ordinary paired evidence is owned by
[`captures/late-story-courts/README.md`](captures/late-story-courts/README.md).
It includes late-region story/south/forecourt/M views, current story controls for
Highway/Marsh/Crystal, and the staged Guild J state. Source, recipe, final log and
PNG hashes establish which source was rendered; they are not QA or artistic
acceptance by themselves. The before and draft outputs retain the actual crop
and material problems that led to this change. No original PNG was changed.

Both final ordinary processes exited 0 with sixteen frames each and no observed
error/warning lines. The 32 final PNGs, 105 matching source/mirror inputs and
matching recipe are recorded in the linked snapshot. Parent inspected all sixteen
wide states. Independent review covered all sixteen narrow states and nine wide
story/south/forecourt comparisons. Main story views have complete silhouettes
with left margins, readable hero/clue/hints and grounded feet. City's connection
is clearest; Facility's dark path is subtle; Factory reads more as a broad court
with a long straight material edge than a distinct branch. At the Factory close
forecourt stance the hero covers the turbine hub/shaft; City's equivalent partly
covers its archive face. Southern Factory/Facility roofs pass behind HUD and
forecourt side buildings crop at the camera edge. These remain visible production
limitations, not reasons to fake a better result by changing only the capture.
These are bounded views, not a whole-world acceptance.
Full-route connections, repeated architecture, sparse distant ground, all UI,
32 actual hero facings, 11 actions and complete story/gameplay remain in scope.

No tests/QA suite, input/E, actual quest acceptance/hand-in/reward, collision
walking, saved entry, save/load, comparable performance or export was executed.
Keep the full objective active and the real player save untouched.

繁體中文：這輪保留既有圖，讓熔爐廳、鐘堂、蓄池與各自的劇情裝置同框，並接上
道路和前庭。三個固定尺寸版本同步縮放腳點，修正窄版左側裁切，其餘建築保持
原樣。公會出擊提示也已對應實際出口；畫面審閱不等於完整玩法或存檔驗證。
