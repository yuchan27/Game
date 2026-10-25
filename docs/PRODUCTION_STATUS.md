# Full production objective and remaining acceptance

Updated 2026-10-25. This ledger preserves the user's complete objective; it is
not a narrower definition of completion. Read `AGENTS.md` / `AI_HANDOFF.md` first.

## Current checkpoint — 2026-10-25

The latest isolated Godot 4.6.3 `visual` profile
`20261025T020943Z-87d60cad` passed **29/29 steps** on source-tree SHA-256
`01b5f899e0f433a7c806eb1b2bcfe38b236fe169dc9c5a25ec316584bf172711`.
VisualReviewRunner passed **77/77 captures and 320/320 runtime checks**; the
separate cold-narrow run passed **11/11 captures and 53/53 checks**. Pause and
staged death recovery passed the wide-to-800 live-resize bounds, action and focus
checks. 800×600 remains a candidate physical size, not an enforced minimum or
true logical reflow boundary. Full report and screenshots are documented in
[QA_REPORT.md](QA_REPORT.md) and [SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md).

The documentation profile `20261025T021833Z-cb858328` passed 3/3; its Python
suites passed **25/25** and **35/35**, with zero documentation or Skill-frontmatter
issues. That validation predates the Chapter 4 optional-black-box wording edit;
no current-source data-validation claim is made for that edit.

The first contract's isolated GUI journey `FirstChapterCurrentCopy-20261025T002852Z-40e59065`
passed **109/109 checks**, including both Scrap Highway outings, physical
extraction, one-time Guild hand-in, checksummed save reload and duplicate reward
prevention. It covers the covered-long route; other chapters and the alternate
route remain open. No human playtest is represented.

Chapter 2's isolated GUI journey `20261025T025900Z-rerun` passed **50/50 checks
with zero failures**, including two outings, physical extraction and Guild
hand-in, required-objective readiness, optional-ledger readiness without early
clue disclosure, exact rewards, isolated checksummed save reload and
duplicate-reward prevention. Report:
`C:\Users\wuwu6\AppData\Local\Temp\chapter2-journey\20261025T025900Z-rerun\chapter2-journey-report.json`;
source-tree hash `67b7cce96b9c60c31ff8ae1144d530e1b1ba5deb43438a2688dd1314f9b939b7`.
The journey selected the purge-air choice; the settle-sample alternative is
unverified. Its derived unverified-branch summary conflicts with explicit
passing checks; the driver bookkeeping is corrected in the working tree but
not rerun. Chapter 4's factory-black-box copy now labels that clue optional;
this copy change has not been validated in a fresh run.

The authored campaign has six contracts and twelve outings. Campaign state,
IDs, story flags, reward quantities, save shape and one-active-contract rules
remain invariants. Chapters 1–4 are free order; Chapter 5 follows the first four,
and Chapter 6 follows Chapter 5. Optional discoveries remain optional and reveal
their content only after discovery. Pacing estimates are not measured. The user
prioritizes story and gameplay before broad art acceptance; keep 800×600 a
candidate and do not call this release-ready. Windows export, later chapter
journeys, human testing, save/IO faults, comparable performance and visual art
acceptance remain open.

The previous full `all` profile `20261025T003334Z-4f3daac4` remains the source
of the one-host performance baseline; the current `visual` profile did not run
the performance suite and proves no optimization.

## Earlier verification notes (superseded where inconsistent with current checkpoint)

Latest passing full-profile verification is Godot 4.6.3 isolated `visual` QA run
`20261024T215336Z-b2508ce7`. It passed **29/29 launcher steps**; the two Python
unit suites passed **23/23** and **33/33**; project-data references, visual-asset
integrity, fresh import, startup and vertical-slice validation passed.
AutomatedPlaytestRunner passed **165/165**, GameplayRegressionRunner **365/365**,
CollisionRegressionRunner **52/52**, WorldExpansionRunner **192/192**,
DirectionalPresentationRegression **571/571**, WorldAtlasRegression **82/82**,
SceneEntranceRegression **12/12**, and VisualReviewRunner **75/75 captures and
307/307 runtime checks with 0 failures/errors**. The cold 800x600 launch passed
**11/11 captures, 45/45 checks and 0 failures/errors**. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\qa-report.json`.

A later full QA attempt (`20261024T221031Z-4eef6dca`) passed its main visual
review but failed in the cold tutorial's synthetic-mouse close/reopen assertions.
The focused cold tutorial run after revising the runner passed 11/11 captures and
53/53 checks; this does not replace a full post-edit QA profile. Mouse input
acceptance remains open.

This profile verifies the existing-save title flow, prologue and actual
SceneRouter entry to Village; J initial focus/scroll; and live 1280x720→800x600
resize behavior for the existing-save confirmation, locked terminal and field
minimap. The confirmation opens at 480×115 logical pixels and keeps Cancel
focused; terminal cards change to one column and restore two. The in-field
minimap stays in bounds at 1280x720 and 800x600 and avoids the status/quest
panels at the narrow size. The full-screen map also stayed in bounds when left
open through that resize; its new 800x600 capture was reviewed. Full-size
captures were reviewed. A separate isolated persistent-root run passed 25/25
checks across real title→Village→Guild→Village SceneRouter transitions with
100 injected Godot keyboard events. Its report confirms Temp-only user data;
`save_game.json` was written there, while the real player-profile save was not
accessed. The cold 800x600 window still
renders a 1024x768 logical viewport; this does not declare a minimum supported
window or prove true logical reflow. Runner logs contain a nested preview-project
skip warning and four non-export-safe PNG inspection warnings; no Godot errors.
No performance profile or standalone Windows export ran; this is not release
readiness.

The 165/165 first-outing path walks the Scrap Highway spawn through escort and
bypass repair to the physical far-side gate, then confirms E activation and
settlement. The bounded runner disables enemies during traversal, suppresses
SceneRouter replacement and stages later hand-in progress. It does not verify
Village-gate departure, the real return scene/debrief or an unstaged Guild
hand-in. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-first-walk\20261025T111000Z-physical-first-outing-final\automated_playtest_report.json`.
Save/load fault handling, comparable performance measurements and a Windows
export remain open.

A newer persistent-root keyboard journey
(`journey-b1dff2c503ca45038c5fc1c7f2d5e7e6`) passed **64/64 checks** on
2026-10-25. It accepts the real Guild contract, enters Wasteland through the
authored gate, completes the first outing actions with enemies active, uses the
physical extraction gate, passes through six successful SceneRouter transitions
and receives a first-outing debrief in Village. It returned at 96/120 HP with no
pending death. The real quest remains incomplete at 1/2 outings and 2/5 kills;
40/12 scrap is present, so the second outing and unstaged one-time hand-in remain
the next gameplay acceptance. The isolated save is under Temp; the real player
save was untouched. This run is bounded injected-input evidence, not human
playtesting, full combat balance or campaign completion. Report:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\journey-b1dff2c503ca45038c5fc1c7f2d5e7e6\journey-report.json`.
The separate 2026-10-24 core launcher run passed **24/24 steps**, but predates
the final journey-driver assertion correction; see [QA_REPORT.md](QA_REPORT.md).

The active J task card keeps its current task/next action/required progress
above optional clues and expandable narrative. Opening J focuses fixed
`ModalTab_contract` and resets `ContractScroll` to zero. At an 800x600 output,
active-task/catalogue text renders at 14.1px and 15.6px; standard 1280x720 font
sizes remain unchanged. The story-site bus now appears fully in frame without
blocking the authored road. Full modal focus cycling remains unverified. Details
and screenshot paths are in [SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md) and
[QA_REPORT.md](QA_REPORT.md).

The earlier full profile `20261024T182716Z-05ceac96` below is retained as
historical evidence for its source snapshot; it is superseded by the newer run
only for the covered scope.

The current [SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md) now includes fresh
captures and runtime evidence for the J page, stacked inventory, expedition
draft, campaign choice, six routes and story sites. These captures establish
presentation and bounds, not player reachability or end-to-end completion. The
latest integrated profile passed the world-expansion and collision suites. The
first-route walk found that the Scrap Highway story bus obstructed the sampled
road; the story-site walk-up anchor was reframed so the bus now appears fully in
view while its collider clears the road. Chapter debrief copy also leaves
free-order next-chapter selection to the existing dynamic J hint and no longer
repeats Chapter 5 work after it is reported complete. The first Scrap Highway
outing now has a real routed extraction and debrief from the persistent-root
journey. The second outing, contract completion and unstaged delivery, other
route walks, combat balance and full campaign acceptance remain open.

The preceding feature checkpoint integrates [choice timing and accurate consequences](choice-gameplay/README.md):
marsh settling8s versus purge3.5s share one resolver for scene timing/HUD and
GameState completion. Highway supplies are provisional choice haul; Facility
priority does not falsely promise an instant village repair. Existing IDs,
reward quantities and saves remain. Eight ordinary staged images cover two
sizes; all113 listed mirror inputs matched at recording. Wide exit0 observed;
narrow final exit was not observed after its handle disappeared, although its
process was absent and all four PNG results0 remain. That checkpoint had no
gameplay/IO/QA run; the current-source run above supersedes it for the covered scope.

The lead also generated and registered [v019 blade idle](art-direction/r17_v2/facing-production/intake-v019/README.md),
after rejecting v018. Blade idle has9 views; complete base coverage and other
actions remain8. Native source comparison and actual frozen Player boards were
opened, both final render exits0. Optional action facings preserve base fallback;
angles are cached at load. The request builder emitted23 remaining idle requests,
exit0, runtime delta0. These are production artifacts, not32-facing or60FPS
acceptance. Quest-layout production is the latest additional user priority.

The J contract layout is now source-integrated and visually reviewed at1280x720
and1024x768. [Its comparison record](quest-layout/README.md) contains four
previous-layout frames, fourteen final native frames, and a source/process
snapshot. The current contract, next step, required checklist, optional clue,
return condition, reward and existing delivery button lead the panel; field-ready
copy directs extraction, and town-ready copy points to that visible button. Long
text is expandable and active quests are not duplicated in the catalogue. Both
final renders exited0. The lead opened all14 final images and reopened the two
final town-ready frames after the copy edit; no horizontal text/button clipping
was observed. Preview input is absorbed; HUD polling/input and button
callbacks are disabled, so those frozen renders are presentation evidence only.
The 800x600 task screen shows the active contract first, actionable catalogue
next, then longer story/rule content. Current-source checks exercise J PageDown
(`0→84`) and mouse-wheel (`0→69`, max 84); text compensation measures 14.1px for
the active task and 15.6px for the catalogue at that output size. Existing
automated Guild checks cover nearby-board E, keyboard accept/claim, one-time
reward, and focus/scroll to the final completed-list row. Full focus cycling,
atlas keyboard navigation, full player journey and save/load acceptance remain
open.
The 113 root/mirror hashes describe capture time. The later main-quest and Ada
copy changes are recorded in the snapshot as two post-capture deltas; neither
their expanded text nor NPC dialogue appears in the reviewed J frames.

The real player-save payload remains unread/unwritten. A stat-only check now
shows1319bytes (last write2026-10-24T07:24:28Z); the preceding handoff recorded
1203bytes. The difference is unexplained. Quest captures use a separate custom
user directory and did not produce it; preserve the current file without
inspection or overwrite.

Story continuation now rewrites only the six existing main-contract descriptions
and Ada's existing post-finale response. Together they connect the water shortage,
route and sample investigation, evacuation records, missing review authority,
and the limited measured outcome. Optional clues remain optional and water-state
timing remains unchanged. This is source-level copy review, not a played campaign.

The preceding continuation integrates [action/dialogue continuity](story-seams/README.md):
transient generation/run ownership prevents old scene actors overwriting a loaded
same-run snapshot; Router preflushes source progress before replacement. Exact
runtime rollback now includes36 fields plus raw expedition state. Scoped NPC
dialogue closes at the final page, resets on Esc/panel changes and cannot replace
reports through stale E input. Source/data review found no proven25-action spatial
blocker; collision traversal remains unverified. No quest/story/reward/save schema
was replaced. Full runtime/input/save acceptance remains deferred.
That record has12 full-viewport staged PNGs, two observed final exits0
and112 matching listed source/mirror inputs. Independent review covered eight
NPC/report images, parent reviewed four field images. Two earlier escort views
were rejected for hidden bodies; follower-aware occlusion preserves the existing
0.2-second cadence and alpha rule, with no collision/placement change. These
frames do not exercise actual reload, departure, E paging or NPC gifts.
The preceding continuation integrated [transactional routed loading](load-consistency/README.md):
validation before queuing, silent apply under cover before destination readiness,
exact runtime restore on reported native scene error, eventual completion and
usable Main/pause failure UI. Five product files/source review and eight native
synthetic UI frames identify the increment; both render exits0/112 listed inputs
match. No actual load/rollback/payload IO/fault ran. `_ready` exceptions remain
outside that return-code boundary. This corrects the source P1 path without
claiming save/gameplay acceptance.
The preceding continuation integrated responsive workshop, pinned modal controls,
resource status cards, actual-weapon rank damage, bounded real-target scan and
guarded death retry. [34 staged frames](preparation-journey/README.md) identify112
matching listed inputs, two observed final exits0 and a ten-frame layout baseline.
Independent review covers30 final interface images; parent covers four recovery/
scan views plus targeted UI/baselines. Parent directly rechecked four disputed
workshop tails and confirmed visible nav/close; no material visible defect found
in this bounded set. Input/crafting/combat/retry/IO remain unexercised. Load
consistency is source-corrected by the later increment above, still awaiting IO/fault acceptance.
The preceding continuation integrated accurate prologue/help, J/K binding separation,
existing-slot new-game confirmation and inline pause save/load feedback.
H now owns the existing reading pause instead of only blocking player input
while enemies/projectiles continue. Dialogue/exit ownership is source-reviewed.
[24 staged frames](onboarding-journey/README.md) identify112 matching listed
source/mirror inputs; both final render processes exited0. Eight final pause
views fully enclose480x520 panels after rejecting an earlier overflow. Main/help
also received bounded visual review. Actual input, confirmation and IO branches
remain unexercised. Earlier [map/label](ui-label-composition/README.md) and
[action/terminal captures](action-readability/README.md) remain historical.
The latest user stopped Gemini; Codex and GPT-6-Luna/xhigh
workers now implement and review. Earlier
[multi-angle request preparation](art-direction/r17_v2/facing-production/README.md)
emitted24 missing blade idle requests without raster production at that time.
The later v019 intake above adds one idle-only view. A recovered GUI `core` run passed 24/24 launcher steps on its recorded
source snapshot; it does not establish full campaign traversal, pacing, rendered
visual/performance profiles or release readiness. Story/gameplay remain the first
priority; preserve existing art and the dirty tree. Real player saves are untouched.

## Detailed evidence ledger from preceding production entries

The rows below preserve their recorded source snapshots and older run reports.
When a row's status conflicts with the current checkpoint above, the current
checkpoint and `QA_REPORT.md` take precedence; append a dated update rather than
rewriting historical evidence.

| Required outcome | Current evidence | Disposition / next requirement |
| --- | --- | --- |
| Factual project audit and prioritized roadmap | `PROJECT_AUDIT.md`, `GAMEPLAY_ROADMAP.md`; current source discoveries | Maintained; reconcile new visual rejection and implemented corrections. |
| Portable agent rules, workflow, handoff, reusable Skills | Root instructions and `.agents/skills/`; live handoff | Maintain during every stage; no dependence on old chats or active agent sessions. |
| Coherent 2.5D pixel medieval-wasteland world | Six-route v4 source/runtime, shared hubs and City street block; `art-direction/world_v4/city_street_block.md` | In progress. New fixed600-width dwelling/workshop and three stepped feet join the City service loop; three cold regions use fine silt/shale.20 final ordinary PNGs/two completed renders/107 mirrored inputs identify this source. Parent reviewed all20, independent final review covered six street views; a separate three-view matched ground comparison supports reduced plate repetition. Whole-frontage fit improves; peripheral crops, warm foundation grass, repeated buildings, sparse quarters and whole-route/player acceptance remain open. |
| Larger, varied, readable complete routes | Six expanded route data sets, 24 regions, 18 guarded sites plus 18 authored contextual yards, authored paths, v4 architecture assignments and water/chasm collision outlines | Integrated source. Existing 24 local-camera captures predate the contextual yards and field-device atlas; 42 later ordinary frames (27 wide / 15 narrow) at `art-direction/world_v4/captures/chapter-sites/` record that pre-hub source snapshot and its local review. Whole-route visual composition and collision traversal acceptance remain open. |
| Hero/weapon scale and fluid combat/movement | Active blade/rifle/heavy source families, registered grips/feet and 60 Hz interpolation | Partial. Complete missing gait/action keys, directional transitions, hit/death/switch; no guaranteed FPS claim. |
| Thirty-two actual hero facings | Eight complete base views; blade idle9 after v019; inactive v017 reference | Incomplete. Idle needs23 more views; other action coverage still needs24 intermediate angles and missing drawings. Repeated poses/slots do not count. |
| Enemy directional art and combat feedback | Seven eight-view enemy sources and existing combat owners | Partial. Review action coverage, presentation, state transitions and collision against latest art. |
| UI, scene-entry effects and adaptable PC views | Main/prologue, HUD/atlas/J/K, native 1024-wide viewport, bounded map labels, draft/story choice UI, collapsible campaign notes and last expedition report, compact action labels | Partial. Latest source run passed 75/75 captures and 307/307 runtime checks; cold 800x600 launch passed 11/11 captures and 45/45 checks. The title confirmation opens at 480×115 logical pixels, live-resizes/recenters while open and retains Cancel focus at 800x600. Field minimap passed same-scene live resize at 1280x720 and 800x600, including no overlap with status/quest panels; the full-screen map and map view also remained visible and in bounds through that resize. The locked terminal reflows to one column at 800x600 and restores its two-column layout at 1280x720; full-resolution captures reviewed. J focus/scroll and task font compensation remain covered (14.1px/15.6px at 800x600). The bus story landmark remains fully visible and clear of the authored road. Output 800x600 uses a 1024x768 logical viewport; minimum supported window and true logical reflow remain undecided. The 960x768 inventory capture verifies stacked orientation. Map click/zoom/navigation, full modal focus/mouse, and several content states remain open. Evidence: [SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md). Preceding [return/consequence presentation](return-consequences/README.md) has 22 manually staged PNGs and 112 listed mirror inputs. Older guidance/campaign/draft/expedition records remain historical with original hashes. |
| Coherent story and meaningful player actions | Six existing main IDs anchor twelve outings/25 actions; early Alan recognition, finite staged water, v5 expedition ledger, field drafts, state-specific NPC briefings and J/K records | Source integrated; full gameplay/save/pace acceptance pending. Completed actions commit only on extraction, partial return preserves those steps, and death loses current provisional work. Original goals and one-time hand-in/reward remain. All 25 actions have distinct verb/instruction/result fields; 12 outing NPC lines and six cleanup lines follow actual state. Both NPC entry paths share returned choices; optional v5 campaign_completed markers preserve completed notes without inventing legacy history. Return receipts now name extracted/lost steps and a partial return's next unfinished action; K reopens the existing single last result without settlement/rewards/save. Ending and K text respect the recorded City consent scope, with neutral legacy wording; hand-in checks autosave failure and warns explicitly. Chapters 1–4 remain order-free while 5/6 keep their real prerequisites; stale fixed next-chapter directives in relevant completion/preparation copy now defer to the existing dynamic J journey hint, and Chapter 5 no longer asks players to repeat its completed register handoff. Chapter 2 sample/return/completion copy reports readings and uncertainty without disclosing the optional evacuation-ledger reveal before discovery; Chapters 3/4 do not assume optional clues from earlier free-order chapters. Four targeted data regressions and the integrated data-validation step passed. An earlier 64/64 player-input journey confirmed the first Scrap Highway outing and is historical. Subsequent 109/109 and 50/50 journeys verified complete first-contract and Chapter 2 flows through Guild hand-in, isolated save reload and duplicate-reward checks; Chapter 2 selected purge-air, with the settle-sample branch still open. Other routes, pacing, optional-clue branches and save acceptance remain pending. [GAME_DESIGN.md](GAME_DESIGN.md) and [AI_HANDOFF.md](../AI_HANDOFF.md) own lifecycle/legacy details. [return-consequences/README.md](return-consequences/README.md) remains staged presentation, not acceptance of other actions, death, IO faults or save/load. |
| Complete inventory/equipment/crafting/progression loop | Existing systems, upgrade persistence, duplicate recycling; responsive cards, real-target scan, actual-weapon rank fix, recovery retry, transactional routed load | Source integrated. No gameplay capacity/weight cap; stack metadata is not enforced and no overflow discard was added.34 preparation/eight later load-feedback frames cover presentation only. Crafting/use/retry, reward/save compatibility and full journey acceptance remain open. Native scene-error rollback is source-corrected; actual IO/fault acceptance remains pending. |
| Clean project without losing work or validated sources | 34 earlier unused files externally archived and individually removed; active and fallback v4 sources are registered | Preserve live/fallback sources. Review any later rejected or unused source against exact paths and references before individual cleanup. |
| Automated quality/release evidence | Full visual source run `20261024T215336Z-b2508ce7`; newer bounded journey `journey-b1dff2c503ca45038c5fc1c7f2d5e7e6`, Godot 4.6.3 | Full visual profile passed 29/29 launcher steps; Python suites 23/23 and 33/33; project-data references, asset integrity, fresh import/startup and vertical-slice validation; AutomatedPlaytestRunner 165/165; GameplayRegressionRunner 365/365; collision 52/52; world expansion 192/192; directional 571/571; atlas 82/82; scene entrance 12/12; VisualReviewRunner 75/75 captures and 307/307 checks; cold 800x600 process 11/11 captures and 45/45 checks. A separate core profile passed 24/24 steps. The newer injected-input player journey passed 64/64, confirms first outing, actual Wasteland extraction/return and debrief, but not second outing or contract hand-in. Save/load fault handling, performance profiling, full campaign and Windows export remain open; this is not a release pass. Two non-failing Godot warnings from the visual run are described in [QA_REPORT.md](QA_REPORT.md). Full-profile report: `C:\Users\wuwu6\AppData\Local\Temp\first-game-map-resize-qa\20261024T215336Z-b2508ce7\qa-report.json`; journey report: `C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\journey-b1dff2c503ca45038c5fc1c7f2d5e7e6\journey-report.json`. |

Earlier story increment: six event records received bounded Gemini CLI copy and
lead-editor corrections, with unknown fates and memory kept unresolved. Twelve
chapter NPC responses no longer assume fixed order; their current next step comes
from journey state. Story clue footers now describe reading/closing rather than
NPC paging. [Story continuation](story-continuation/README.md) records ordinary
staged presentation and source identity. Earlier six-chapter debriefs, K replay,
saved City consent and transition-pause fixes remain integrated. Previous chapter,
contract and arrival records retain historical identity. Full production is open.

The active goal remains open while any required row is incomplete or unverified.
Complete playable-slice acceptance still covers all six wasteland regions, 32
actual hero facings, all 11 requested player actions, supported-size UI and
end-to-end story/gameplay. Current source integration and bounded ordinary art
captures do not narrow or close that acceptance scope.
Ordinary art rendering is allowed production evidence; do not silently run a QA
suite or mark a release pass merely to close this ledger.

Current City street-block evidence and source identity are detailed in
`art-direction/world_v4/city_street_block.md` and
`art-direction/world_v4/captures/city-street-block/`. The final set contains 20
ordinary PNGs (10 at 1280x720 and 10 at 1024x768). Both Godot processes exited 0
after 10 frames with no observed error/warning lines; the snapshot records 107
matching source/mirror inputs and matching recipe hashes. It covers the listed
staged states and inputs only, not all legacy or hero sources.

Independent comparative review covered three matched draft-wide ground controls;
the parent reviewed all20 final states. Independent final row review covered
frontage/bay/main-road at both sizes. The frontage retains full roofs/feet and
doors without HUD overlap. Ground comparison supports reduced outlined diagonal
plates, not a measured seamless texture or whole-world improvement. The City close stance `(4090,4775)`
falls inside the existing 48-pixel saved-position exclusion and is reached only
after population; the staged bay stance `(4200,4820)` is outside the grown feet by
source geometry only. No saved-entry or walking result follows. Roof crops remain
under the HUD in bay/main-road views. Warm authored foundation grass remains
around cold Facility masonry.

No gameplay input/E, quest/reward action, collision walking, saved entry, save/load,
comparable performance, QA or release check ran for this checkpoint. The full
objective and every incomplete acceptance row remain active. Prior late-story and
regional-courts evidence is historical and remains in
`art-direction/world_v4/late_story_courts.md`,
`art-direction/world_v4/captures/late-story-courts/`,
`art-direction/world_v4/regional_courtyards.md` and
`art-direction/world_v4/captures/regional-courts/`; older QA disposition remains
in `RELEASE_READINESS.md`.
