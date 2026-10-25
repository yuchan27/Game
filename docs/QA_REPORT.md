# QA report index

Updated: 2026-10-25 (Asia/Taipei).

## Latest integrated checkpoint (2026-10-25)

Godot 4.6.3 isolated `visual` profile `20261025T020943Z-87d60cad` passed
**29/29 QA steps** on source-tree SHA-256
`01b5f899e0f433a7c806eb1b2bcfe38b236fe169dc9c5a25ec316584bf172711`.
Report:
`C:\Users\wuwu6\AppData\Local\Temp\viewport-wide-to-800-20261025-1010\20261025T020943Z-87d60cad\qa-report.json`.
It includes project-data validation (**0 issues**), the two Python suites
(**25/25** and **35/35**), fresh import/startup and the gameplay, collision,
world expansion, directional, atlas and scene entrance regression runners.

VisualReviewRunner passed **77/77 captures, 320/320 runtime checks, 0 failures
and 0 errors**. The separate cold-narrow title profile passed **11/11 captures,
53/53 checks, 0 failures and 0 errors**. Pause and staged death-recovery states
were opened at 1280×720 and live-resized to 800×600; primary actions, focus and
panel bounds passed. I reviewed both original-size captures. This does not prove
a cold-start death transition, natural recovery transaction, minimum supported
window, or true logical reflow; 800×600 remains candidate physical-window
evidence over a 1024×768 content viewport. The profile did not run the separate
performance suite or a Windows export.

The latest isolated documentation profile before the Chapter 4 wording change, `20261025T021833Z-cb858328`, passed
**3/3 steps** after the agent-entrypoint and screen-matrix updates. It reran the
same **25/25** and **35/35** Python suites and found **0 documentation or Skill
frontmatter issues**. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261025T021833Z-cb858328\qa-report.json`.

The subsequent isolated Chapter 2 GUI journey `20261025T025900Z-rerun` passed
**50/50 checks, with zero failures**. It accepted Chapter 2 before Chapter 1,
completed both authored outings with physical E-held actions and extractions,
returned through the Village gate, and handed the contract in at the real Guild
counter. It verified the exact material and +35 XP reward, an isolated
checksummed `SaveManager` reload, no duplicate reward after a second E press,
and the Guild J card's optional-ledger wording without revealing the
undiscovered result. It ended alive in Guild with no active expedition. The
report records the physical purge-air choice; the alternate settle-sample choice
was not tested. Report:
`C:\Users\wuwu6\AppData\Local\Temp\chapter2-journey\20261025T025900Z-rerun\chapter2-journey-report.json`;
source-tree hash `67b7cce96b9c60c31ff8ae1144d530e1b1ba5deb43438a2688dd1314f9b939b7`.
The run used an isolated Temp profile and did not read or write the real player
save. The report's derived `unverified_branches` field conflicts with the
passing required-objective and optional-ledger checks; the current driver now
records that milestone correctly, but this bookkeeping correction was not
rerun.

Chapter 4's factory-contract description has since been clarified to say the
black-box discovery is optional and does not block delivery. That wording edit
and the driver bookkeeping correction have not had a fresh QA run, per the
current no-new-tests instruction. The older failed attempts below remain useful
history only; they are superseded for the Chapter 2 journey checks above.

Older dated entries below are retained as history. Their statements that later
story edits or current-turn QA were unverified are superseded only for checks
covered by the current profiles above; the journey and release gaps remain open.

## Earlier Chapter 2 optional-clue copy and incomplete GUI journey (R5 history)

The Chapter 2 quest description and story step no longer reveal the optional
pump-ledger finding before discovery. Alan's briefing now says the ledger is
optional and that the samples are enough to deliver the contract. The focused
`test_project_data.py` suite passed **34/34**, and
`validate_project_data.py` reported **0 issues** after those copy changes. These
checks do not establish that the chapter is playable end to end.

The isolated GUI journey R5 reached the real Guild contract catalog, accepted
`toxic_sample`, entered `toxic_marsh`, selected the first sample action, and
started its channel. It failed to complete that action after holding E for 4.5
seconds against an authored 4-second duration. At hold start the player stood
109.897 px from the action with a 112 px interaction radius; the run did not
record held-input state, elapsed channel progress or post-hold distance. This is
insufficient to identify whether input was interrupted or the player left the
radius, and is not evidence of a confirmed production gameplay defect. Physical
extraction, Guild hand-in, save reload and duplicate-reward protection remain
unverified for Chapter 2.

The Chapter 6 event follow-up calls its enemy “失控守衛,” consistent with the
facility quest and NPC briefings, instead of using wording that could be
confused with the required “動力核心” item. The later current visual profile
and data-validator run cover this copy change; no Chapter 6 player journey has
been completed.

The Chapter 5 archive choice was narrowed to Alan's own name because the story
does not record independent consent from Liu Qing. Her name and other residents'
names remain restricted; affected districts, water lines and household numbers
remain public. The choice IDs and save shape did not change, but an older
`ch5b_publish_consent` now resolves to Alan-only publication. The later current
visual profile and data-validator run cover this data change; no Chapter 5
player journey has been completed.

Report: `C:\Users\wuwu6\AppData\Local\Temp\chapter2-journey-20261025T010244843Z\artifacts\chapter2_journey_retry5.json`.
At the time of this earlier R5 note, no tests or QA commands were run during
that continuation turn; the latest validation is summarized above.

## Current integrated QA profile (2026-10-25)

Godot 4.6.3 `all` profile `20261025T003334Z-4f3daac4` passed **33/33 steps**
on isolated source snapshot SHA-256
`9a4e788b8184f701bd3458db14c236fafbc7fb2a51e3a4a7cde9441fad8a6ac0`.
The report is
`C:\Users\wuwu6\AppData\Local\Temp\wasteland-release-qa\20261025T003334Z-4f3daac4\qa-report.json`.
It includes both Python suites, docs/Skill frontmatter, project-data and visual
asset validation, fresh import/startup, VerticalSlice, AutomatedPlaytest
(165/165), GameplayRegression (365/365), collision (52/52), world expansion
(192/192), directional presentation (571/571), WorldAtlasRegression (300/300),
and SceneEntranceRegression (12/12).

Rendered VisualReviewRunner passed **75/75 captures, 308/308 runtime checks and
0 errors**. The cold physical 800x600 title launch passed **11/11 captures and
53/53 checks**. The same screenshot run confirms the title now shows the
in-village I/C/J/T/K/G/M/H controls. I inspected its main-title, contract,
Scrap Highway and atlas captures; this is screenshot review of the recorded
states, not a human playtest. The 800x600 window still renders a 1024x768
logical viewport. It remains candidate-size evidence, not a minimum supported
size or true logical reflow claim.

The adaptive atlas regression runs at actual windows 1280x720, 1024x768,
760x900 and 560x900. It verifies that six routes and six markers remain
reachable and operable, narrow layouts stack and scroll, and detail/footer text
fits. The separately run targeted atlas report passed 308/308; the integrated
full profile's atlas report passed 300/300.

The rendered performance sample recorded 240 frame intervals with mean
16.665 ms, p95 16.981 ms and max 18.070 ms; engine process time averaged
16.609 ms (p95 17.067 ms) and physics averaged 1.311 ms (p95 1.897 ms). The
sample used 50 enemies, one boss, 89 props and 24 pickups. Projectile allocation
stayed bounded at 200, and a reuse smoke test reused 24 instances without
allocating more. This is a one-host baseline, not a measured improvement,
CPU-utilization result or guaranteed frame rate. No Windows export was run.

Non-failing diagnostics include Godot skipping a nested preview `project.godot`
and the vertical-slice asset checker loading four PNGs directly for dimensions,
which Godot warns is not export-safe. The Python suite also intentionally
exercises invalid viewport arguments; its expected argparse diagnostic appears
in stderr while the suite exits successfully. No Godot parse/runtime errors
were reported.

## Current-source core rerun after story-copy follow-up (2026-10-25)

After the Chapter 3/4 free-order completion, return and preparation copy change
and its project-data regression, current-source Godot 4.6.3 `core` QA run
`20261025T004029Z-89e26719` passed **24/24 steps**. Source-tree SHA-256:
`13f0eba46cd922e1c77516d711470997ca92653b6f747384f5e2fc10511aa895`.
Report:
`C:\Users\wuwu6\AppData\Local\Temp\wasteland-story-current-qa\20261025T004029Z-89e26719\qa-report.json`.

The core profile passed both Python suites, project-data/asset checks, Godot
version and fresh import, headless startup, VerticalSlice, AutomatedPlaytest,
GameplayRegression, CollisionRegression, WorldExpansion, directional
presentation, WorldAtlas and SceneEntrance checks. It confirms current-source
integration after the text change; the 33/33 full `all` profile above remains
the preceding snapshot for visual capture and performance evidence. The
Chapter 3/4 change is copy-only and does not claim a new full visual run.

## Documentation-only follow-up (2026-10-25)

The documentation-only profile `20261025T005240Z-3b452e7b` passed **3/3
steps** after the handoff reconciliation: both Python suites and documentation /
Skill frontmatter. Its source-tree SHA-256 is
`26becd309c73d0f9de2bd0d5859bae9accd6a5ba92b601dc308cbab84b85a895`; report:
`C:\Users\wuwu6\AppData\Local\Temp\wasteland-docs-qa\20261025T005240Z-3b452e7b\qa-report.json`.

## Complete first-contract journey (2026-10-25)

The isolated Godot 4.6.3 GUI journey
`FirstChapterCurrentCopy-20261025T002852Z-40e59065` passed **109/109 checks**
with 818 injected keyboard events and nine successful SceneRouter transitions.
It used the physical Guild board and gates, completed both authored Scrap
Highway outings, extracted through each real return gate, opened the live J
contract copy, and then delivered at the Guild reward counter. The selected
second-outing option was `ch1b_covered_long`; the exposed-short alternative was
not exercised.

At hand-in the saved progress was outing 2/2, kills 6/5 and banked scrap 57/12.
The actual hand-in consumed 12 scrap and awarded ammo +16, mutant core +1,
scrap +20, alloy plate +3, broken coil +2 and XP +35 (scrap net +8). A
subsequent `SaveManager.load_game(false, false)` succeeded with a valid
checksum; completion, inventory and XP matched, and reload did not change the
saved payload hash. Pressing E at the reward counter a second time changed
neither inventory, XP, completion nor save hash. The character ended alive in
Guild with 84 HP. No death-loss branch was deliberately triggered.

The live first-outing debrief distinguishes the temporary test circuit from
long-term supply, locates the formal coupling outside and says rationing
continues. The second debrief says the coupling was retrieved but does not
claim village water changed before delivery. The J panel states the 5-kill and
12-scrap goals are chapter totals that can accumulate across both outings.
This proves one automated chapter journey, not human play, both route choices,
later chapters, old-save compatibility or campaign pacing.

- Journey report:
  `C:\Users\wuwu6\AppData\Local\Temp\FirstChapterCurrentCopy-20261025T002852Z-40e59065\journey-report.json`
- Runtime log: `C:\Users\wuwu6\AppData\Local\Temp\FirstChapterCurrentCopy-20261025T002852Z-40e59065\journey.log`
- Report source-tree SHA-256: `dc2f32c0118b020691e37e3f247a33cfa779604ecfca358c343e223c98179b9f`.
- Driver SHA-256: `8d94fdffbe68c567395a80c32a64f7a9228339434b968bc77a3c90407dae3350`.

## Earlier comprehensive visual profile (2026-10-24)

The latest passing comprehensive isolated Godot 4.6.3 `visual` run is
`20261024T215336Z-b2508ce7`.
All **29/29 launcher steps passed**. The full visual review started at
800x600 and passed **75/75 captures, 307/307 runtime checks, 0
failures/errors**. Its cold 800x600 process passed **11/11 captures, 45/45
runtime checks, 0 failures/errors**. Reports:

- `C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\qa-report.json`
- `C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\artifacts\visual\visual_review_report.json`
- `C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\artifacts\visual\cold_narrow\visual_review_report.json`

Command used:

```powershell
python scripts/tools/run_qa.py --profile visual --visual-resolution 800x600 --godot 'C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --output 'C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa'
```

The run also passed Python unit suites (**23/23** `scripts/tools`, **33/33**
`scripts/tests`), project-data/reference validation, visual-asset integrity,
fresh import, headless startup, vertical-slice validation, AutomatedPlaytestRunner
(**165/165**), GameplayRegressionRunner (**365/365**), CollisionRegressionRunner
(**52/52**), WorldExpansionRunner (**192/192**), DirectionalPresentationRegression
(**571/571**), WorldAtlasRegression (**82/82**) and SceneEntranceRegression
(**12/12**).

Four responsive states were exercised through the existing runner: the
existing-save new-journey confirmation opened at **480×115 logical pixels**
(asserted at no more than 160px), kept focus on its Cancel action, and fit the
800x600 window after a live resize; the locked terminal reflowed from two
columns to one and returned to two after resizing back to 1280x720. Both full
resolution captures were opened and visually reviewed. The terminal's cards now
use content height and top alignment. In the same Wasteland HUD, the in-field
radar remained visible and within viewport bounds at 1280x720 and 800x600, and
did not overlap the status or quest panels at 800x600. Its new capture,
`field_minimap_resize_800x600.png`, was opened at full resolution. With the
full-screen map open in the same Wasteland scene, resizing 1280x720 → 800x600
kept the map panel and map view visible and within viewport bounds at both
sizes. Its `full_map_resize_800x600.png` capture was also reviewed at full
resolution. The 800x600
output is still a candidate profile; this run does not declare it the minimum
supported size or prove a 1024x768 logical viewport can reflow to a smaller
logical size. Map click/zoom/navigation and live marker interaction remain
unverified.

Two non-failing warnings remain in runner logs: the fresh import skips a nested
`project.godot` in the isolated firearm preview directory; VerticalSliceVerifier
loads four PNGs directly only to inspect their dimensions and Godot warns that
this method is not export-safe. The run recorded no Godot errors. No performance
profile, Windows export or release-readiness claim is included.

## Follow-up full QA attempt (2026-10-24)

Run `20261024T221031Z-4eef6dca` completed the 29-step QA sequence; its main
visual review passed **75/75 captures and 307/307 runtime checks**, but the cold
800x600 phase reported tutorial synthetic-mouse close/reopen errors. Reports:

- `C:\Users\wuwu6\AppData\Local\Temp\first-game-tutorial-interaction-qa\20261024T221031Z-4eef6dca\qa-report.json`
- `C:\Users\wuwu6\AppData\Local\Temp\first-game-tutorial-interaction-qa\20261024T221031Z-4eef6dca\artifacts\visual\cold_narrow\visual_review_report.json`

The runner had updated hover state at the close button, but the test did not
observe a Button input signal; the failed checks then cascaded into reopen/Esc
assertions. This did not establish a product UI defect. Afterward, the unreliable
mouse assertion was replaced by a labeled keyboard activation check and the
focused cold run below passed. The full QA profile has not been rerun after that
runner edit, so `20261024T215336Z-b2508ce7` remains the latest passing
comprehensive profile.

## Targeted cold tutorial interaction slice (2026-10-25)

A focused `VisualReviewRunner` cold-narrow launch passed **11/11 captures,
53/53 runtime checks, and 0 errors** on Godot 4.6.3. It ran in an isolated
Temp project mirror with the current `HUD.gd` and `VisualReviewRunner.gd`; report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-tutorial-interaction-qa\diagnostic-mouse-click-02\visual-attempt19-keyboard-close-clean\visual_review_report.json`.

Tutorial checks cover H open, initial close-button focus, a Tab move that stays
inside the panel, wheel scrolling from 0 to 62 of 518, Enter activation of the
close button, release of the reading pause, H reopen, and Esc close. The close
activation assertion is keyboard input. It does not establish OS mouse-click
delivery; synthetic input changed the reported hover target but did not produce
a Button input signal. No product UI defect was established from that test.
This targeted run does not replace a full QA run after the visual-runner edits.

## Bounded persistent-root scene-flow proof (2026-10-25)

An independent Godot 4.6.3 windowed run passed **25/25 harness checks**, used
**100 injected Godot key events**, and observed **three successful normal SceneRouter
replacements**: title → Village → Guild → Village. It verified that the test
coordinator attached under `SceneTree.root` survives each `current_scene`
replacement and that authored gate interactions work after WASD movement sent
through `Input.parse_input_event`. A unique Temp user-data directory was
validated before checking the save path. `save_game.json` was written under
that isolated profile; the real player-profile save was not accessed.

- Runner: `scripts/tests/FirstChapterJourneyBoot.tscn`,
  `FirstChapterJourneyLauncher.gd`, `FirstChapterJourneyDriver.gd`
- Report: `C:\Users\wuwu6\AppData\Local\Temp\first-chapter-journey\20261024T215201Z-27d16a1d\journey-report-attempt4.json`
- Runtime log: `C:\Users\wuwu6\AppData\Local\Temp\first-chapter-journey\20261024T215201Z-27d16a1d\godot-journey-attempt4.log`

This run stops in Village. It does not accept or complete a guild contract,
enter Wasteland, perform an outing action, extract, settle, hand in, or validate
the chapter outcome. It makes no visual quality claim.

## Previous integrated 800x600 visual profile (2026-10-24)

This earlier isolated Godot 4.6.3 `visual` QA profile is run
`20261024T205213Z-af013aa7`. It passed **29/29 launcher steps** against an
isolated project mirror. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated\20261024T205213Z-af013aa7\qa-report.json`.
Command used:

```powershell
python scripts/tools/run_qa.py --profile visual --godot 'C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe' --visual-resolution 800x600 --timeout 600 --output 'C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated'
```

The run includes Python unit suites, project-data/reference validation, visual
asset integrity, fresh headless import and startup, vertical-slice validation,
automated gameplay (**165/165**), gameplay regressions, collision regressions
(**52/52**), world expansion (**192/192**), direction/atlas/scene-entry
regressions, and rendered review.

The rendered review ran at an 800x600 output size and passed **71/71 captures,
290/290 runtime checks, and 0 failures/errors**. The cold 800x600 launch passed
**11/11 captures, 45/45 runtime checks, and 0 failures/errors**. Reports are at
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated\20261024T205213Z-af013aa7\artifacts\visual\visual_review_report.json`
and
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated\20261024T205213Z-af013aa7\artifacts\visual\cold_narrow\visual_review_report.json`.
The QA runner used an isolated user-data directory; the real player save was
not used.

Current-source input evidence confirms that J opens with focus on the fixed
`ModalTab_contract` tab and scroll position zero, including cold open and
re-open; mouse wheel reaches `0→69` (maximum 84) and PageDown reaches `0→84`.
The active task, next action, required progress, optional clues and delivery
state appear before the long catalogue. The Scrap Highway story-site bus is
fully visible beside its walk-up and remains clear of the authored road. The
title path handles existing-save cancel/reopen/confirm, completes the prologue,
and enters Village through SceneRouter.

The output window is 800x600 while the logical content viewport remains
1024x768 under canvas stretch. This does not establish 800x600 logical reflow or
a minimum supported size. Full modal focus traversal, all route journeys,
performance profile, Windows export, and release readiness remain open. The
visual asset checker reports reused frames in authored player clips; these
results do not support a smooth-60-FPS motion claim. Screenshots for the task,
title and story-site checks are in the run's `artifacts/visual/` folder.

## New direct first-outing traversal (2026-10-25)

Godot `4.6.3.stable.official.7d41c59c4` ran
`res://scenes/tests/AutomatedPlaytestRunner.tscn` directly against the current
worktree. `AutomatedPlaytestRunner` passed **165/165 checks** with no failures.
Report: `C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-first-walk\20261025T111000Z-physical-first-outing-final\automated_playtest_report.json`.

The check accepts the Guild contract, creates the Scrap Highway scene from the
runner, and uses Player movement input from the authored wasteland spawn to the
first escort. It follows the authored escort waypoints, completes the escort,
starts and completes the hold-E bypass repair, then walks the northbound authored
road to the physical far-side extraction gate. E selects and activates the gate;
the test observes the `to_village` interaction signal, confirms extraction
settlement, first-outing advancement and retained route objective.

This is a bounded traversal check, not an uninterrupted game journey. The test
creates Wasteland directly after Guild acceptance instead of walking to a Village
route gate. It disables enemies and pauses the Wasteland population process only
during path traversal. It suppresses SceneRouter's scene replacement while
observing the real gate signal, then calls the settlement API. The later Guild
delivery uses a completed-outing fixture. The runner separately exercises melee
and ranged combat, ammo use and save/load, but those checks are not part of the
live traversal. Village return, an unstaged hand-in, surviving combat along the
route, and other route walks remain unverified.

The first physical walk exposed `StoryProp_highway_bus_0` blocking the central
Scrap Highway road. The story-site walk-up was moved west while the landmark
collider stayed clear of the authored road. The integrated visual profile above
reran the corrected collision sampler (**52/52**) and world expansion checks
(**192/192**); the bus is also fully visible in the 800x600 story-site capture.
A prior `core` run (`20261024T184858Z-940b175c`) failed the older field playtest
before these traversal changes; it is historical and superseded for the covered
checks by the latest integrated profile.

## Actual first-contract outing and routed return (2026-10-25)

The newer Godot `4.6.3-stable` persistent-root windowed journey
`journey-b1dff2c503ca45038c5fc1c7f2d5e7e6` passed **64/64 checks** in 72.484
seconds. It dispatched **268 injected `InputEventKey` events** from a persistent
root driver, covering title → Village → Guild, real board acceptance of
`clear_scrap_route`, travel through the Guild expedition gate, the first authored
Wasteland outing, and return through the physical extraction gate. The escort
and bypass relay actions were completed. The northbound road walk had enemies
active; the run recorded six Space attack events and three combat responses
during the escort's nearby-enemy wait. All **six actual SceneRouter transitions**
succeeded, including Wasteland → Village. The returned state contained a first-
outing debrief and retained the active quest. It ended at 96/120 HP without a
pending death transition.

The quest is correctly not complete: first-outing progress is **1/2**, the
original kill objective is **2/5**, the inventory has **40/12 required scrap**,
and the optional evacuation ledger remains undiscovered. No hand-in was
attempted. This is evidence for one bounded injected-key journey, not human
playtesting, full combat balance, the second outing, optional-clue branches,
once-only Guild reward delivery, other route journeys or a completed campaign.

The run used a fresh profile and save under
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\journey-b1dff2c503ca45038c5fc1c7f2d5e7e6\userdata\`; the real player save was not read or written.
The report is
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\journey-b1dff2c503ca45038c5fc1c7f2d5e7e6\journey-report.json`.
The runtime log is in the same run folder as `godot-journey.log`. The report's
source-tree SHA-256 is
`850e538ddf50c39f33ec3b45822b97d299bd4e423b94e4f9c4a20cec11383cb0`.
After this run, the two Chapter 1 return-summary strings in
`data/maps/quests.json` were revised to clarify the sealed water sample,
unchanged rationing and the coupling's limited repair role. Those player-facing
copy edits are not part of the reported source hash and were not included in the
64-check run.

The earlier `core` profile
(`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261024T232806Z-d48d59c9\qa-report.json`)
passed **24/24 launcher steps**, including fresh import, headless startup,
vertical-slice and current gameplay/collision/world/directional/atlas/entrance
regressions. It predates the final journey-runner assertion correction and is
not the same source snapshot as the 64-check journey. Neither profile is a full
release verification.

Earlier attempts `20261024T143654Z-cf2e754c`, `20261024T150744Z-847ebd42`,
`20261024T151823Z-26f949ce`, and `20261024T173308Z-07a49f56` exposed test-side
physics/focus assumptions, a duplicate resize-signal connection, a stale dynamic
container-name lookup and a cold-capture manifest-order issue. The 10/24 visual
profile remains passing evidence for its recorded source snapshot; the 10/25
direct traversal result above is newer and narrower.

Historical results remain available: an earlier Gemini GUI core run reported
[24/24 steps passed](qa/gui_core_20261024.md), and the earlier31/31 `all` baseline
is in [qa/redesign_baseline.md](qa/redesign_baseline.md). Neither supersedes the
current run or serves as a release pass.

Current commands, report path, counts and release limitations are maintained in
[RELEASE_READINESS.md](RELEASE_READINESS.md). Narrative acceptance and asset
provenance are in [STORY_AND_SCENES.md](STORY_AND_SCENES.md).

The old report described specialized runners and Windows export steps that are
not in the current `run_qa.py`. Its cited run belongs to an earlier dirty tree,
so those claims cannot establish readiness of the current source snapshot. The
latest integrated profile is current evidence for the project files copied into
its isolated mirror at run time; it does not establish readiness after later
source changes or replace the open manual gameplay/release checks.

The current launcher reuses ValidationRunner, AutomatedPlaytestRunner,
GameplayRegressionRunner, CollisionRegressionRunner, VisualReviewRunner and
PerformanceRunner across its profiles. This `visual` profile ran the Python/data
checks, fresh import/startup, core gameplay regressions, scene checks and rendered
captures; it did not run the separate `performance` profile or a standalone
Windows export. No measured performance claim or full manual playthrough follows.

The clean starting revision `4ab05f0` passed 16/16 isolated core steps in
`20261022T092303Z-bb45e37d`; this is historical baseline only. Do not reuse
historical timing/animation claims as fresh evidence or replace valid assertions
merely to obtain a passing result.
