# Chapter-site production camera checkpoint

**Earlier snapshot:** the later `../road-and-convoy/` checkpoint changes wagon
silhouettes, prop foot sorting, highway geometry/median placement, event remnants
and map/notice presentation. This set retains the earlier Title/J/completed-art
states but must not be described as covering those later source changes.

Recorded 2026-10-23. **Ordinary isolated Godot art rendering; no tests/QA,
gameplay acceptance or release verification.** This follows the older
`../current-production/` snapshot and the user's rejection of pasted objects.

## Evidence and reproduction

- 27 PNGs at 1280×720: 18 authored context cameras, the original bus story
  camera, relay/isolator pending and staged-complete states, two pending J
  panels, Title and Prologue.
- 15 PNGs under `1024x768/`: one context camera per route, the bus camera and
  all device/J/title/prologue states. This is deliberately fewer context
  cameras than the wide batch; do not claim all 18 have narrow coverage.
- Godot `4.6.3.stable.official.7d41c59c4`, Compatibility/OpenGL 3.3,
  Intel Arc 140V. All six recorded render processes exited 0; their logs have
  no observed script/engine error lines. These are rendering exit codes.
- `source_snapshot.json` records 97 code/scene/data/v4-PNG inputs with matching
  isolated-copy hashes, and 42 output dimensions/hashes. Test scripts/scenes
  and inactive v4 candidates in that identity list were not executed/activated
  merely by being hashed. Other legacy PNGs are outside this identity record.
- Portable recipe: `../ChapterPreview.gd.txt`. Copy it to `ArtPreviewV4.gd`
  attached to a Node scene in an isolated project with a dedicated custom
  user directory. The actual mirror used `R17-Ordinary-Art-Preview-20261023`.
  Never run a capture against the real player save.

Run Godot with `--rendering-method gl_compatibility --audio-driver Dummy
--resolution 1280x720 res://ArtPreviewV4.tscn -- --art-output=<absolute path>`.
Use `1024x768` and `--narrow-selection` for the narrow set. Optional
`--art-view=highway-convoy-story` renders one selected world camera. The wide
convoy yard/intake camera and both bus cameras were recaptured separately;
their logs are retained alongside the main wide/narrow logs.

## Corrections driven by actual rendered output

The first authored layout still had isolated prop clusters and three wagons too
far below the depot. Those candidates were rejected. The current 18 groups
reference specific architecture feet, and large regular roadside wrecks were
replaced by smaller nonblocking wayposts/rubble within the active v4 path.
Authored decorations consume the existing filler budget rather than add an
unbounded second prop population. No performance improvement is claimed.

The next render exposed a hard rectangular rubble apron. Dry rubble now exposes
broken, low-coverage stone through the regional earth with no solid basin rim.
This changes native material sampling; source PNG pixels are preserved. Water,
chasm, furnace and coolant rules and shared collision outlines are retained.

The factory field action moved away from a guarded-site label/hot-pit area.
Both devices use their own registered atlas crops rather than duplicates of
story landmarks. E text anchors to the device; full status labels appear only
within 280 world pixels while map-event markers remain available at distance.
This fixes the clipped distant relay label found in the marsh shelf frame.

Preview-only hero staging was corrected for convoy and intake views. The recipe
had teleported the hero onto a wagon or behind an occluding roof/pillar. Runtime
architecture occlusion and live spawn points were not disabled to hide it.

The parent inspected corrected world/device/UI frames at both sizes. A separate
read-only reviewer inspected the earlier 26 wide views, then all 14 narrow
views and four corrected wide views; the parent inspected both added bus views.
The final inspected corrections show no rectangular apron or clipped distant
device status, and the title/prologue and scrolling J layout remain legible.

## Limits and next production work

This is a local production checkpoint awaiting player feedback. The broad
orthogonal highway paving still needs more contextual breakup, the three wagon
silhouettes repeat, and route-wide density/connections remain unfinished.
Buildings and creatures can naturally cross a camera boundary; in the narrow
city courtyard a creature is partially hidden by the upper-left objective panel.
That is a combat-visibility review item, not evidence of a collision failure.
Do not move live enemies merely to make a staged art frame cleaner.

The recipe manually seeds contract/version/material/kill state, and directly
sets completion flags for completed images. It does not execute the action API,
accept/hand in quests, grant rewards, load a player save or complete the campaign.
Images cannot prove save compatibility, duplicate prevention, the sabotage
spawn effect, traversal, collision, frame time or memory use. These remain
unverified while the user's no-QA instruction is active. Hero 32-view/actions,
all-menu review, full story/progression and release work remain in the main
production ledger.

繁體中文：這批保留實際遊戲鏡頭、來源雜湊與修正理由。已改善道具工作區接地、
設施文字和窄視窗排版；仍不是整張世界或完整玩法的驗收，也沒有執行測試。
