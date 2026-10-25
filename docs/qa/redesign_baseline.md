# Redesign baseline repair evidence

Updated: 2026-10-23 (Asia/Taipei). This verifies the existing prototype's QA
baseline. It does not approve the current character proportions, map art or the
proposed 32-facing redesign.

## Scope and root cause

The prior full run `20261022T155341Z-019421f6` passed 29/31 launcher gates and
failed `exploration_crystal_walkup_is_reachable`. The defect was synchronization
in the rendered test, not an obstructed crystal-site placement.

The isolated diagnostic is at
`C:\Users\wuwu6\AppData\Local\Temp\first-game-crystal-diagnostic\20261022T160922Z-ea26b567`.
Its original two-tick test failed on the scrap route instead of crystal. Logs
recorded the player Node2D at the authored approach while its PhysicsServer2D
body remained at the entrance on the first physics signal. On the second signal
the body transform was current, but `Area2D.get_overlapping_bodies()` was still
empty. A subsequent physics tick populated the overlap and fired the normal
interaction signal. Render waits sometimes included that additional tick,
explaining why the failing route varied.

For example, the scrap player was at `(1576.96, 3488.64)` while its physics body
was still `(3584, 5076)`; at the second signal both positions matched but
`can_interact()` remained false. The three-tick diagnostic showed real overlap
and `can_interact() == true` on both routes and exited 0.

Only `scripts/tests/VisualReviewRunner.gd` changed for this repair: frozen actors
now wait at most eight physics ticks, exiting as soon as the actual Area2D
overlaps the player and normal `can_interact()` is true. The original assertion
and guard/reward checks remain. No interaction flag is forced, no assertion is
skipped, and no Wasteland placement, collision, reward or save behavior changed.

## Fresh verification

Engine: `4.6.3.stable.official.7d41c59c4`. Git HEAD:
`4ab05f086f720273fc78db34d50d423997deb301`, branch
`codex/story-and-scene-pass`, with the existing dirty work preserved.

From `C:\Code\Game\first-game`:

```powershell
& 'C:\Code\Game\first-game\.godot\qa-venv\Scripts\python.exe' -u 'C:\Code\Game\first-game\scripts\tools\run_qa.py' --godot 'C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --profile all
```

Run `20261022T161407Z-60fafde1` completed at `2026-10-22T16:17:06Z`, exit 0:
**31/31 launcher gates passed**, with zero recorded Godot errors. Report root:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261022T161407Z-60fafde1`.
The tested source tree SHA-256, before the launcher's user-directory patch, is
`a77d0b9fbf981ec5f502ce8d0f0c6c4f61171f4c2805e98012c31dbaec4a7bb3`.

| Check | Fresh result |
| --- | --- |
| Python tests, documentation, data, assets, import and startup | All passed |
| Vertical slice | 394 pass markers |
| Automated playtest | 53 checks, zero failures |
| Gameplay / collision | 156 / 52 checks, passed |
| World expansion | 192 checks, zero failures |
| Directional / world atlas / scene entrance | 571 / 82 / 12 checks, passed |
| Rendered visual review | 46 captures and 120 runtime checks, zero failures |
| Rendered performance | 18 functional checks, passed |

The separate corrected rendered run also exited 0 with 46 captures, 120 runtime
checks and no Godot errors; see the diagnostic root's `bounded-sync-report.json`
and `visual-bounded/visual_review_report.json`. The unrepaired diagnostic's exit
1 and emitted assertion error remain in `diagnostic-report.json`; the passing
three-tick experiment is in `third-tick-report.json`.

Directly inspected both full-run `artifacts/visual/exploration_scrap.png` and
`exploration_crystal.png` at 1280x720. The player stands on the authored clear
approach, the E prompt is visible, and the contested site/guards are present.
Existing name/status/long E-prompt text is crowded and overlaps near the reward;
this is an open UI polish limitation. Generating all 46 captures is not a claim
that every image received a new manual review.

The vertical-slice verifier emitted four raw image-file loading/export warnings
from `_expect_png_size`; they are preserved in its stderr. Standalone export and
a human campaign walkthrough remain unverified by this run.

## Rendered timing sample

The pending `frame_post_draw` instrumentation was executed, with 90 warmup frames
and a 240-frame sample on Windows, Forward Plus, Intel Core Ultra 7 268V:

| Distribution | Mean | p95 | Maximum |
| --- | ---: | ---: | ---: |
| Actual post-draw intervals (240 intervals) | 16.664 ms | 17.310 ms | 26.092 ms |
| Godot process monitor | 19.977 ms | 31.649 ms | 31.649 ms |
| Godot physics monitor | 3.863 ms | 5.210 ms | 5.210 ms |

Workload: crystal route, 50 enemies including one boss, 106 props, 24 pickups,
peak 10 active projectiles; the subsequent pool test exercised its 200 cap and
24 reused instances. The character agent deferred Godot/FFmpeg work for the
performance phase. Two process snapshots at `16:17:05Z` and `16:17:06Z` show only
this QA runner's Godot GUI/console pair and no FFmpeg; other desktop/background
load was not controlled. See `performance-workload-snapshots.json` and
`artifacts/performance_report.json` in the full-run root. A short sample and
functional green checks do not establish sustained 60 FPS or a speed improvement.

## Real-save preservation evidence

The mirrored project explicitly uses
`FirstGame-QA-20261022T161407Z-60fafde1` as its custom user directory; writing
tests therefore run outside the real player's directory.

An additional isolated `WorldExpansionRunner.tscn` writing regression exited 0
with no Godot errors from `16:19:00Z` to `16:19:11Z`. Immediately before and after,
the real file
`C:\Users\wuwu6\AppData\Roaming\Godot\app_userdata\FirstGame\save_game.json`
had the same SHA-256
`1914931bbefd1d9596edf3243527c027f132ca78f18119a0a4c20da1cac4b2d0`, length
1203 bytes and unchanged modification timestamp (`2026-10-22T15:28:24.8156249Z`).
See `real-save-verification.json`, which includes the exact follow-up command,
both snapshots and logs. This explicit hash pair covers the follow-up, not the
earlier full run or the entire day; no pre-full-run hash was captured here.

No save was restored, no original asset was overwritten, and no commit or push
was performed. Wasteland and WorldExpansion implementation ownership is released
without source changes from this task. Further redesign production requires its
own rendered review and integrated verification.
