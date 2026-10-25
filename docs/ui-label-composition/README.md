# Viewport fit and field-map label composition

Historical snapshot after the [onboarding continuation](../onboarding-journey/README.md).
Its26 PNGs and112-input hashes remain unchanged; later Main/HUD/GameState differ.

2026-10-24, Asia/Taipei. Gemini3.8 Flash medium authored the production changes
and fixture recipe; Codex reviewed, requested corrections and integrated them.
This is ordinary isolated presentation work. No tests/QA suite ran.

## Integrated behavior

- CampaignAction receives transient HUD blocker/Control references through
  `set_hud_presentation()`. Its world-label rectangle and visible HUD rectangles
  are compared in viewport space. Overlapping labels hide while the existing
  action card retains progress. Zero-size/freed controls are ignored. Direct
  death/scene/route/router checks remain local; modal updates also reach the
  labels while scene simulation is paused. The transition branch broadcasts on
  the visible-card edge rather than scanning providers every transition frame.
- WorldMapView retains real marker positions and hover metadata. Label placement
  prioritizes active waypoints/actions, ready actions, exits, bosses and other
  named sites. It uses side margins, reserves named/player marker bounds and
  avoids placed label boxes. Each label tries at most16 positions; all leader
  lines are drawn before backgrounds/text. Waypoints retain their full existing
  action name/count; overlong text is ellipsized at280px with full hover details.
- The radar's former210px child minimum exceeded its138px HUD allocation and
  visibly cropped its right edge. The mini view now uses110x100 minima in both
  its own initialization/mode switch and HUD construction. Native vertical
  expansion fills the full-map panel and removes its oversized empty bottom band.

These changes retain the existing timers, action/wave/interaction logic, marker
groups, inventory, rewards, save ownership and five autoloads. No image assets
were regenerated and no new runtime service was introduced.

## Current evidence

[Source snapshot](source_snapshot.json) records112 matching source/mirror inputs,
three changed product-file hashes, recipe/log/image hashes, CLI decisions/status/
usage as reported, and real-save stat metadata. Resumed CLI usage fields are not
summed. One conflicting effort-parameter invocation failed before inference;
retry retained the same pinned model without that override.

Final renders used Godot `4.6.3.stable.official.7d41c59c4`, Compatibility/Intel
Arc140V. Wide session24095 and narrow session80766 both exited0, each with13
successful frame records and no observed error/warning lines.26 PNGs contain
seven action/modal/transition fixtures and all six native route maps per size.

Independent final review covered all six1280x720 maps, narrow Highway/City/Facility
maps and the narrow clear-escort/radar frame. No visible title/legend/label or
radar clipping blocker was identified in those ten images. Earlier independent
review also covered five action/modal frames before the final radar sizing.
The lead inspected the final radar/clear-label frames and selected map frames;
the final staged logs retain label/card visibility for every frame.

Examples: [narrow radar and clear label](1024x768/escort-clear.png),
[narrow Highway map](1024x768/map-highway.png),
[wide Facility map](1280x720/map-facility.png).

## Evidence boundary

The [recipe](UiLabelCompositionPreview.gd.txt) directly assigns campaign/runtime/
wait state and disables scene simulation. It relocates the escort900 world
pixels from its original site, resets the camera and existing architecture
occlusion, hides the entry notice and directly opens native panels. Its transition
fixture sets `transition_active` directly; it performs no scene travel or save.
An explicit final HUD refresh means that image does not isolate the one-shot
process branch; current source review covers that branch.

No actual movement, waiting-wave recovery, input/E/click/hover, quest hand-in,
choice/reward/settlement, return/death, save/load/migration, collision traversal,
pacing, frame-time, export or QA is established. Real-save metadata remains
1203 bytes/1792682904815624900ns, with its payload unread/unwritten.

Long faint leaders can cross map content; bulk enemy/pickup dots are drawn but
not all reserved as label occluders. Region names are separately drawn; no
blocking overlap appeared in the reviewed maps. Tie ordering is stable within
the live node allocation, not a cross-reload layout guarantee. Full world-art,
all-interface and full campaign acceptance remain open.

The preceding [action/terminal record](../action-readability/README.md) remains
historical with its original22 PNGs and hashes. Do not rewrite old evidence.

繁體中文：這批修正提示被HUD遮住、右上雷達被裁切，以及大地圖底部空白。
六區地圖會優先排目前行動與返村門，路點保留名稱與進度。26張隔離預置畫面
記錄了兩種解析度；這不是實際通關、碰撞、存檔、效能或測試套件的驗收。
