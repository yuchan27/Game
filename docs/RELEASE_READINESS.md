# Release readiness and evidence boundary

Updated: 2026-10-25 (Asia/Taipei).

## Current state

The latest isolated Godot 4.6.3 `visual` QA run
`20261025T020943Z-87d60cad` passed **29/29 steps** on source-tree SHA-256
`01b5f899e0f433a7c806eb1b2bcfe38b236fe169dc9c5a25ec316584bf172711`. It
includes current story/data validation, asset checks, fresh import/startup,
gameplay and world regression runners, plus **77/77 visual captures and
320/320 runtime checks**. The separate cold-narrow launch passed **11/11
captures and 53/53 checks**. Pause and staged death-recovery panels remained in
bounds with a reachable, focused primary action during an after-start
1280×720→800×600 resize. Both original-size captures were reviewed. Current
counts, artifact paths and limits are in [QA_REPORT.md](QA_REPORT.md) and
[SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md).

The latest documentation/Skill profile before the Chapter 4 wording change,
`20261025T021833Z-cb858328`, passed **3/3 steps**: Python suites **25/25** and
**35/35**, plus zero documentation or Skill-frontmatter issues. That report
does not validate the subsequent Chapter 4 wording and driver-bookkeeping edits.

The isolated first-contract journey
`FirstChapterCurrentCopy-20261025T002852Z-40e59065` passed **109/109 checks**.
It completed both Scrap Highway outings, the original chapter-total objectives,
physical extraction, Guild hand-in, a checksummed data-only save reload and a
second hand-in attempt without duplicate reward. It used the covered-long route;
the exposed-short alternative, death loss, old-save behavior and human play
remain unverified. Chapter 2 has its own 50/50 journey below; Chapters 3–6 remain
unverified. The real player save was untouched.

The latest Chapter 2 isolated GUI journey `20261025T025900Z-rerun` passed
**50/50 checks with zero failures**, including both outings, physical extraction,
Village/Guild travel, required-objective readiness, optional-ledger readiness
and non-revelation, exact Guild rewards, isolated checksummed save reload and
duplicate-reward prevention. It selected the purge-air choice; the settle-sample
alternative remains untested. Report:
`C:\Users\wuwu6\AppData\Local\Temp\chapter2-journey\20261025T025900Z-rerun\chapter2-journey-report.json`;
source-tree hash `67b7cce96b9c60c31ff8ae1144d530e1b1ba5deb43438a2688dd1314f9b939b7`.
Its derived `unverified_branches` field conflicts with passing checks; the
report-driver bookkeeping has been corrected in the current tree but not
rerun. Chapter 4 optional-black-box copy was also clarified after the latest
journey and has not been revalidated.

After the Chapter 3/4 free-order story-copy and regression change, current-source
Godot 4.6.3 `core` QA `20261025T004029Z-89e26719` passed **24/24 steps**. This
confirms the edited source integrates with the core project checks; the complete
visual/performance profile above is the preceding source snapshot and was not
rerun after this copy-only edit. Exact hash and report path are in
[QA_REPORT.md](QA_REPORT.md).

This is a passing development checkpoint, **not a release pass**. The user
prioritizes story/gameplay before broad art revision. The complete campaign,
Chapter 3–6 journeys, water-stage presentation across chapters,
supported-size contract, Windows export, save/IO faults, alternative routes,
human pacing and artwork acceptance remain open. The earlier all-profile
performance sample is a one-host baseline; the current visual run did not
compare performance and no optimization or guaranteed frame rate is claimed.

## Previous visual profile and earlier journey (historical)

The latest passing full isolated source snapshot is Godot 4.6.3 `visual` QA run
`20261024T215336Z-b2508ce7`: **29/29 launcher steps**, Python suites **23/23**
and **33/33**, AutomatedPlaytestRunner **165/165**, GameplayRegressionRunner
**365/365**, collision **52/52**, world expansion **192/192**, directional
presentation **571/571**, atlas **82/82**, scene entrance **12/12**, and visual
review **75/75 captures with 307/307 runtime checks**. The separate cold 800x600
launch passed **11/11 captures and 45/45 checks**. The review includes an
existing-save confirmation resize, locked-terminal one-column reflow, in-field
minimap resize, and full-map resize while open; their new frames were inspected
at full resolution.
The field minimap stayed visible at 1280x720 and 800x600 and remained clear of
the status/quest panels. Full report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\qa-report.json`.

A newer Godot 4.6.3 persistent-root injected-input journey
(`journey-b1dff2c503ca45038c5fc1c7f2d5e7e6`) passed **64/64 checks**. It
accepts the first Guild contract, enters Wasteland through the authored exit,
completes the first outing actions, encounters active enemies, extracts through
the physical gate, returns through SceneRouter to Village and generates a
debrief. The contract remains incomplete at 1/2 outings and 2/5 kills; the
second outing, remaining original goals and unstaged one-time hand-in are open.
The save was isolated in Temp; the real player save was not read or written.
This is bounded injected-input evidence, not human playtesting, full campaign,
save compatibility, combat balance or release acceptance. See
[QA_REPORT.md](QA_REPORT.md).

A later full QA attempt (`20261024T221031Z-4eef6dca`) passed the main 800x600
visual review but failed in the cold tutorial's synthetic mouse close/reopen
assertions. The focused cold run after revising those assertions passes 11/11
captures and 53/53 checks for keyboard close activation, scroll and pause
release. The later 2026-10-25 `all` profile documented in the current state
passed after that runner edit. Mouse input and the broader screen gate remain
open beyond the checks represented by that run.

## Earlier cold-window review notes

The following image review belongs to the previous 800x600 source profile and
is retained as historical evidence, not current-source acceptance.

I reviewed all eleven cold-window images, including title, prologue, inventory,
workshop, contract, terminal, journal, atlas, tutorial, map and pause. The cold
process captures the title at the real launch size, then directly stages the
intro and Village before opening HUD panels with injected input; it does not
prove real new-game reachability. That gap is now covered by the focused
current-source title run below. The output window is 800x600, but the content
viewport remains 1024x768 under canvas stretch. The 960x768 inventory capture
passes its stacked-layout check; the current J hierarchy, draft and route-choice
screens are included. The visual-profile Guild flow exercises nearby board E,
keyboard accept/claim, one-time reward, completed-list focus/disclosure and
Escape. Its field-action fixture places the test player beside the authored
Area2D device and stages remaining goals. A newer direct runner result adds a
physical walk through the first Scrap Highway outing and E activation of its
far-side return gate; see below. Asset integrity passed
while warning that many authored player animation clips reuse frames. This is a
motion-quality task; no comparable frame-time or 60 FPS claim was measured.

This is a passing development QA checkpoint, not a release pass. The older state
regressions and captures do not prove a complete player-controlled campaign.
Complete modal focus traversal, the second outing, original combat/material
goals, unstaged contract delivery, broader live-combat balance, other route
walks, measured pacing, save/load fault injection, performance profiling and
Windows export remain open. A real Wasteland-to-Village extraction now has
bounded injected-input evidence; the minimum supported window is undecided. The
800x600 output is candidate presentation evidence, not a logical reflow claim.
The recovered Gemini GUI `core` run at 24/24 is historical only; see
[its report](qa/gui_core_20261024.md).

## Earlier focused screen review (2026-10-25, superseded by the current profile)

On 2026-10-25 the focused `VisualReviewRunner` passed **71/71
captures, 284/284 runtime checks, and 0 errors**. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-screen-verified\20261024T193744Z-1a45494e\artifacts\visual_task_readability\visual_review_report.json`.
The cold 800x600 launch run passed **11/11 captures and 43/43 checks** at
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-screen-verified\20261024T193744Z-1a45494e\artifacts\visual_task_readability_cold_800\visual_review_report.json`.
The focused run exercises the existing-save confirmation, cancel/reopen/confirm,
save preservation through the prologue, and real SceneRouter entry to Village.
It also verifies J mouse-wheel (`0→69`, maximum 84) and PageDown (`0→84`), plus
the 800x600 task-text compensation (14.1px active task, 15.6px catalogue).
These screen checks do not replace a full QA profile or establish complete
gameplay. Cold output is 800x600 while its logical viewport remains 1024x768.
This screen report predates the subsequent `GameState.gd` story-copy edit; that
change has not been exercised.

## New direct first-outing playtest

On 2026-10-25, Godot `4.6.3.stable.official.7d41c59c4` ran
`AutomatedPlaytestRunner.tscn` directly against the current worktree. It passed
**165/165 checks** with zero failures. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-first-walk\20261025T111000Z-physical-first-outing-final\automated_playtest_report.json`.

The runner accepts the Guild contract, creates the Scrap Highway scene directly,
walks from its authored spawn through the first escort and hold-E bypass repair,
follows the authored northbound route to the physical extraction gate, and
verifies E activation, extraction settlement, outing advancement and objective
retention. The runner disables enemies and Wasteland population processing during
the walk, guards the real gate signal from replacing the test scene, then settles
through the API. Later Guild delivery uses a completed-outing fixture. This
confirms a bounded route walk and gate interaction; it does not confirm Village
departure by route gate, actual SceneRouter return, live-combat survival through
the outing, unstaged hand-in, full campaign or release readiness. A separate
`core` profile passed 24/24 after gameplay pacing changes but before the final
journey-runner assertion correction. The newer 64/64 journey now covers actual
first-outing return; it does not replace full `core`/`visual` release checks.

The world v3 captures and their recorded input hashes are historical evidence;
the user rejected their complete-scene cohesion. The current v4 correction changes
ground scale, architecture, landmarks, regional surfaces and basin geometry.
Its isolated ordinary renders establish only the recorded camera compositions,
not gameplay or release acceptance. See [the current world checkpoint](art-direction/world_v4/README.md)
for dated source identity, render evidence and remaining review scope.

Read `../AI_HANDOFF.md` for current source state and remaining production tasks.
Read `GAME_DESIGN.md` for the implemented core loop/player stories and
`art-direction/README.md` for current art manifests and acceptance boundaries.
Thirty-two actual character facings and the complete family/action matrix remain
open until the art-production manifest records and supports them. Do not describe
this project as a finished AAA game or a verified commercial release.

## Earlier all-profile baseline

`20261022T161407Z-60fafde1` passed 31/31 launcher gates on Godot
`4.6.3.stable.official.7d41c59c4`, before the present production changes.
The authoritative checked-in evidence is [redesign_baseline.md](qa/redesign_baseline.md).
Its source-tree SHA-256 is
`a77d0b9fbf981ec5f502ce8d0f0c6c4f61171f4c2805e98012c31dbaec4a7bb3`.
The external report path on the original machine is
`C:/Users/wuwu6/AppData/Local/Temp/first-game-qa/20261022T161407Z-60fafde1/qa-report.json`.
Those external files may not exist after changing machines; retain the evidence
boundary rather than presenting their absence as a new test pass.

That baseline covered 46 rendered captures/120 runtime checks, core gameplay,
wrapped save/load, collision, guarded exploration, directional presentation,
world atlas, scene entrance and representative rendering. The old crystal
capture failure was a physics-overlap synchronization issue in the capture
runner, repaired without changing the map's collision placement.

Its 240 actual post-draw intervals averaged 16.664 ms, p95 17.310 ms and maximum
26.092 ms on the recorded machine/workload. These dated measurements do not
establish current performance, universal 60 FPS or a gain from later changes.
Detailed counts and environment are in the evidence document.

## Deferred checks and known production limits

- Extend the tested Guild input flow through real movement to the wasteland,
  field actions, map-view/return-gate interaction, and extraction. The current
  test directly stages objectives after exercising Guild accept/claim buttons;
  mouse-wheel scrolling and complete catalogue focus traversal remain
  unverified. Focus scrolling to the final completed row is covered only in the
  bounded 800x600 disclosure scenario.
- Continue save/load fault injection and verify the existing contract and
  duplicate-disassembly behavior under real player progression. Older tests may
  require intentional contract updates before they characterize that behavior.
- Inspect new character families through actual movement, aim, attack timing,
  muzzle location, switching, hit/death and directional transitions. Complete
  missing authored angles/actions rather than duplicating reference stills.
- Exercise all revised roads, architectural footprints, entrances, basins,
  evidence approaches and saved-position compatibility.
- Complete a human campaign/balance walkthrough and current controlled timings.
- Matching Windows export templates/standalone package validation remain open;
  an export preset and editor rendering do not prove an executable release.

The full-completion objective authorizes relevant validation after current source
changes are reviewed. Reuse `scripts/tools/run_qa.py` with an independently
discovered engine and isolated user/output paths. Preserve the real save and
existing art. Record actual commands, errors, reports and uncovered requirements;
run visual capture with a desktop renderer and open the full PNGs. Do not treat
historical reports or headless visual runs as current visual/gameplay acceptance.

No push occurred. The current uncommitted work must be carried with the workspace
when changing machines; a fresh remote clone does not contain these local edits.
