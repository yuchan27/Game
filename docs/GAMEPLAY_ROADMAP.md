# Story and gameplay roadmap

Updated: 2026-10-25 (Asia/Taipei). This roadmap sequences independently
reviewable work for the story-driven expedition roguelite target in
[`GAME_DESIGN.md`](GAME_DESIGN.md). The current user priority is story and
gameplay completeness, including the J contract/task presentation, before broad
art work, balance, performance and release work. Do not infer
shipped behavior from a design target or source change that has not been exercised.

## Current implementation snapshot — 2026-10-25

The project retains six main quest IDs, two side contracts, six routes and one
authored ending. Six chapters contain twelve authored outings and 25 actions.
The first contract passes a **109/109-check** isolated GUI journey. Chapter 2
now passes a **50/50-check** isolated GUI journey covering both outings,
physical extraction, Village/Guild return, required-objective and optional-ledger
readiness without revealing the clue, exact hand-in rewards, checksummed save
reload and duplicate-reward prevention. See
[`QA_REPORT.md`](QA_REPORT.md) for the complete evidence and exact limits.

The latest isolated Godot 4.6.3 `visual` QA `20261025T020943Z-87d60cad` passed
**29/29 steps**, including VisualReviewRunner's 77/77 captures and 320/320
checks, plus a cold-narrow 11/11-capture, 53/53-check run. Its source snapshot
hash (`01b5f899…`) predates the Chapter 2 journey snapshot (`67b7cce9…`); do not
infer its visual coverage for that later source. The physical 800x600 output
still renders a 1024x768 logical viewport and does not define the supported
minimum.

The earlier full isolated `all` profile `20261025T003334Z-4f3daac4` passed
33/33 steps and supplied the one-host performance baseline. Four atlas window
profiles (1280x720, 1024x768, 760x900 and 560x900) passed in that earlier
snapshot. Neither the baseline nor the later visual profile demonstrates a
performance improvement.

The current rendered performance sample is a single-host baseline: 240 frame
intervals averaged 16.665 ms (p95 16.981 ms); process time averaged 16.609 ms,
physics 1.311 ms. It is not a measured improvement or guaranteed frame rate.
See [`QA_REPORT.md`](QA_REPORT.md) for the workload and report path.

Chapter 3/4 completion and preparation copy now follows free-order progress and
leaves the next contract to the dynamic J hint. The focused project-data module
passed 34 tests, and current-source Godot 4.6.3 `core` QA
`20261025T004029Z-89e26719` passed 24/24 steps after that copy change. Its
source-tree SHA-256 and report path are recorded in [`QA_REPORT.md`](QA_REPORT.md).
This core run does not replace the preceding full visual profile. The
six-chapter campaign, death/partial-return branches, old-save compatibility,
human playtest, pacing, Windows export, and broad visual/art acceptance remain
open. Broad art work follows story/gameplay acceptance.

The Chapter 2 journey selected the purge-air choice; its alternate settle-sample
choice remains untested. The report's derived `unverified_branches` field
conflicts with named passing checks; driver bookkeeping is corrected in the
current tree but has not been rerun. Chapter 4's quest description was also
clarified to state that finding the factory black box is optional and does not
block delivery; this copy edit is not yet validated. The six-chapter campaign,
death/partial-return branches, old-save compatibility, human pacing, Windows
export and broad art acceptance remain open. Broad art work follows
story/gameplay acceptance.

The Chapter 6 facility event's follow-up was also corrected to call the enemy a
“失控守衛,” matching the quest and character briefings and distinguishing it
from the “動力核心” item. This working-tree copy edit has not been validated in
a new QA or journey run.

The Chapter 5 publication choice now lets Alan decide only about his own name.
The current story contains no independent consent from Liu Qing, so her name
and other residents' names remain in the restricted Guild copy while districts,
water lines and household numbers stay public. Choice IDs and save shape remain
stable; old `ch5b_publish_consent` records now mean Alan's name is public only.
This revision also has not been validated in a fresh run.

## Historical implementation notes from the preceding checkpoint

Latest bounded production: [choice gameplay](choice-gameplay/README.md) gives
marsh settling/purge real8s/3.5s timing through a shared completion/display
resolver, with accurate provisional-supply and planned Facility-priority copy.
The current user also requested a clearer J contract layout. That source pass is
complete: current task/next action/required progress lead, optional goals stay
separate, long story/rules expand, the active task is not duplicated in the
catalogue, the field-ready card directs the player to evacuate, and town-ready
copy points to the visible delivery button below. Four baseline
and14 final frames at1280x720/1024x768 are recorded in
[`quest-layout/README.md`](quest-layout/README.md); all final images were reviewed.
That frozen preview is isolated and non-interactive. The current Godot 4.6.3
`visual` QA run `20261024T215336Z-b2508ce7` passed 29/29 launcher steps;
VisualReviewRunner passed 75/75 captures and 307/307 runtime checks, and the cold
800x600 launch passed 11/11 captures and 45/45 checks. The same run passed
AutomatedPlaytestRunner 165/165, GameplayRegressionRunner 365/365,
CollisionRegressionRunner 52/52, WorldExpansionRunner 192/192,
DirectionalPresentationRegression 571/571, WorldAtlasRegression 82/82 and
SceneEntranceRegression 12/12, alongside fresh import/startup, Python/data and
asset validation. See [QA_REPORT.md](QA_REPORT.md) for report paths and scope.
The title flow exercises existing-save cancel/confirm, preserves the fixture
until the real SceneRouter entry to Village, and checks J wheel/PageDown
scrolling. Opening J focuses its fixed navigation tab and resets contract
scroll to zero; active-task/catalogue text renders at 14.1px/15.6px at an
800x600 output. The cold process retains a 1024x768 logical viewport, so this
does not establish a minimum supported size or true logical reflow. Full modal
focus traversal remains open. The earlier 165/165 direct playtest walks the
first Scrap Highway outing from its authored spawn with enemies disabled and
SceneRouter replacement suppressed; it remains useful as a bounded path check
only. The newer 2026-10-25 persistent-root journey
`journey-b1dff2c503ca45038c5fc1c7f2d5e7e6` passed 64/64 checks using 268 injected
key events. It accepts the real Guild contract, travels through the authored
Guild exit, completes the escort and relay actions, walks the northbound route
with enemies active, extracts through the real gate, and returns to Village
through six successful SceneRouter transitions. A first-outing debrief is
generated. The quest remains at 1/2 outings and 2/5 kills, with 40/12 required
scrap; second outing and Guild hand-in are still open. The fresh save was
isolated under Temp. This run does not establish human playtest or combat balance.
A separate 2026-10-24 core profile passed 24/24 launcher steps; its report
predates the final journey-runner assertion correction. Ordinary enemy chase
now has 720/900 px acquire/release hysteresis and return-to-anchor behavior;
after all authored outing actions are complete, periodic filler respawn stops
while initial and authored wave/boss paths remain. The core pass does not include
a performance comparison. Full-screen map and minimap remain within bounds
through a live 1280x720→800x600 resize. Other route journeys, second-outing
objectives, unstaged hand-in and full save/load acceptance remain open. Detailed
paths and evidence are in [QA_REPORT.md](QA_REPORT.md).
The existing-save confirmation now opens compactly at 480×115 logical pixels
(maximum 160 asserted) on the full 800x600 visual profile. The same field
minimap remains visible and in bounds through live 1280x720→800x600 resizing,
without overlapping status or quest panels; the open full-screen map also stays
within bounds at both sizes. Screen/state
completion remains an acceptance gate. The immediate gameplay stage is to
continue the real first-contract campaign through the second outing, remaining
objectives and one-time hand-in.
The earlier `20261024T182716Z-05ceac96` profile captured the HUD before the J
catalogue was built and used the then-current scaled-panel columns. Its 10/24
800x600 frames show the active contract, available task order and accept
controls; the later integrated run above supersedes its counts for the covered
scope. Current-source checks cover the fixed-tab initial focus, scroll reset,
PageDown and mouse-wheel scrolling, plus keyboard focus to the final completed
row. Full modal focus cycling remains open. The direct playtest covers
the accepted contract's first field outing but does not use the Village route
gate or complete a real return-to-Guild journey.
The six main contract descriptions now carry the causal chain from water
shortage, through the allocation evidence, to the final measured supply; Ada's
post-finale line names the concrete but rationed village effect. Chapter 2 sample
copy no longer discloses the optional evacuation-ledger finding, and Chapters
3/4 no longer assume optional clues from earlier free-order chapters. Targeted
data regressions and the integrated data-validation step passed; these changes
have not been exercised in a full playthrough.
[v019](art-direction/r17_v2/facing-production/intake-v019/README.md) adds one
idle-only hero angle; complete base coverage stays8. The visual QA checkpoint
below covers current screen presentation and regression assertions, but does
not establish full story gameplay, pacing or save/IO acceptance.

The current build remains a persistent salvage action RPG with six main
contracts, two side contracts, six routes, village/guild acceptance and hand-in,
and one ending. The v5 run-haul ledger and core expedition settlement are now
integrated in source: new field items are held in a run haul, usable return gates
settle only after a successful scene transition, and death discards the run haul
and provisional contract/field state. Banked inventory, XP/levels, lifetime
defeats and discovered lore persist. These behaviors have not been verified
through gameplay, save/load acceptance, balance review or QA. Optional run-local
drafts at the first two authored exploration sites on each route are also
integrated in source. The twelve-outing runtime is source-integrated: 25 ordered actions under the six original main quests, with optional acceptance markers preserving old active quests. Gameplay/save acceptance remains open. The 6–8
minute tutorial and 12–18 minute regular outing remain unmeasured targets.

The gameplay bridge source-integrated in this pass retains the six current
main contract IDs and their kill/material goals, adds the existing-schema
`highway_bypass_repair` action to `clear_scrap_route`, and stages village water
as dry → small trickle after `clear_scrap_route` → finite stable supply after
`facility_memory`. Current integration is source work, not play verification.
New accepts use the existing `field_objective_version` compatibility marker;
an older active first quest without the marker keeps its prior completion
conditions and reward. The existing rescue/sabotage side contracts keep the
same rule: old active unmarked saves retain the old kill/material rules, while
new accepts may require their field action. No action grants a second reward.
Alan's early-recognition source change is integrated this pass; runtime behavior
is not verified.

The v1-v4 migration path preserves the old immediate-bank rules for an in-field
legacy save through its first return; the legacy marker survives v5 saves while
the player remains in the field. In a new run, haul ammo is consumed before
banked ammo, and used banked ammo is not refunded on death. Crafting, disassembly,
healing and permanent upgrades are hub-only. The active v5 save records source
claims and generated resource/harvest positions so the same run keeps its layout
and collection identities after reload. These are source facts, not gameplay
acceptance.

This documentation update did not run gameplay, QA or mutate a save. The later
current-source visual QA is recorded in [`QA_REPORT.md`](QA_REPORT.md); it verifies
the bounded Guild/task-panel flow described there, not a complete expedition.
A historical ordinary UI capture is available in the
[expedition-presentation source snapshot](expedition-presentation/source_snapshot.json):
18 staged PNGs (nine per resolution), two observed render exits of 0 with nine
frame records each, 108 listed source/mirror inputs whose hashes match, and a
matching recipe hash. The images stage the new-run HUD, haul inventory, ready
HUD, field J panel, pending-clue journal, legacy inventory, and
extracted/lost/unsaved reports.
Parent and independent review covered targeted frames, not every menu or
catalogue. No player input, quest hand-in, actual settlement, save/load, disk
fault, timing, performance or QA was performed. The real save metadata is
unchanged. The [historical draft presentation record](draft-presentation/README.md)
adds fourteen manually staged frames, seven per resolution, from two final
renders that exited 0 with seven frame records each and no observed
ERROR/WARNING lines; its 108 listed source/mirror inputs and recipe match.
Independent review covered both offer panels at both sizes plus narrow approach
and expiry views, with no visible defect identified in those six frames. The
460px-high offer panels display all three cards. Fields were staged directly;
selection, combat, settlement, save/load and pause scenarios were not exercised.
Keep source integration, staged presentation, runtime behavior, pacing evidence
and later QA as separate status items.

## Prioritized work

**P1 asynchronous-load consistency is source-corrected; fault/IO acceptance remains
deferred.** [Load record](load-consistency/README.md) describes the dedicated
request/completion boundary, silent apply, exact runtime rollback on reported
scene error and usable failure UI. That snapshot covered35 state fields plus
raw expedition/death/ammo state. The newer [continuity correction](story-seams/README.md)
adds its transient campaign generation to the exact checkpoint (now36 fields),
preflushes source actions before transition/apply, and rejects old actor writes
even when a loaded snapshot has the same run ID. HP0 normalization, v1-v4/v5 and
five autoloads remain.
Eight synthetic UI frames do not exercise the transaction; `_ready` exceptions
remain outside the native-return-code boundary. No failure was injected.

[Preparation increment](preparation-journey/README.md) integrates actual-weapon
rank ownership, bounded real-target scan, death retry, responsive workshop,
pinned controls and resource status cards.34 native frames/two exits0/112 matching
listed inputs establish bounded presentation. No gameplay capacity/weight cap
exists; stack metadata is not enforced. Crafting/use/combat/retry/IO remain
unexercised. NPC continuity now uses scoped speaker identity: last-page E closes,
Esc/panel changes reset paging, and reports do not accept another NPC's E input.
Continue full story/gameplay beyond these source corrections; same-run load,
action restart/partial return/death, gift and broader dialogue acceptance are
still deferred. The current first-contract journey now covers a complete contract
handoff and checksummed reload. The other route option, chapters 2–6, old-save
compatibility, death/retreat and pacing remain open; avoid broad cosmetic polish
until those gameplay gaps are understood.

| Priority and status | Deliverable | Owner | Acceptance |
| --- | --- | --- | --- |
| **P0 — first-contract journey verified; later water/gameplay acceptance pending** | First-contract and village-water bridge. Keep the existing main IDs/goals/rewards, add `highway_bypass_repair` to `clear_scrap_route`, and expose the three authored water stages. | `data/maps/quests.json`; `scripts/autoload/GameState.gd`; `scenes/levels/village/Village.gd` | The 109/109 isolated journey verified the new marked acceptance, both outings, original goals, one-time hand-in and save reload. A saved active quest without `field_objective_version` retains its former rule by design; old-save execution remains pending. The hand-in text acknowledges the small tested trickle; verify the Village's visual water-stage transition and later finite-supply outcome in a player journey. |
| **P1 — source integrated; broad save/gameplay acceptance pending** | v5 run ledger, run ID, v1-v4 legacy-trip compatibility, hub-only services, route-authored far-side return-gate positions and settlement, death recovery and same-run story-boss suppression. Preserve banked inventory while tracking new haul, provisional counters/actions/claims and per-run source layout. Router surfaces failed autosave state explicitly. | `scripts/systems/ExpeditionLedger.gd`; `scripts/autoload/GameState.gd`; `scripts/autoload/SceneRouter.gd`; `scenes/ui/HUD.gd`; `scenes/levels/wasteland/Wasteland.gd`; `data/maps/wasteland_routes.json` | The first contract verifies a real departure/extraction, two outings, hand-in, and data-only save reload. Verify old saves and other active runs through load, same-run reload, story-boss re-entry, early retreat, failed scene transition, autosave failure and death. Other route walks, live-combat balance, migration and fault acceptance remain pending. |
| **P1 — source integrated; gameplay/save/balance acceptance pending** | Optional temporary field drafts at the first two authored exploration sites on each route: arc shooter, melee/evasion and salvager. | scripts/systems/ExpeditionLedger.gd; scripts/autoload/GameState.gd; data/maps/wasteland_routes.json; scenes/levels/wasteland/Wasteland.gd; scenes/ui/HUD.gd | At a new unclaimed site, offer only after guards clear and existing loot is credited; an already claimed site can offer again in a new run without duplicate loot. Each choice adds +1 to both existing effects in a package; repeating a package or combining packages is allowed. Pending choices persist across dismissal/reload; the next site's opportunity stays open. No currency, reroll, mission gate or permanent unlock. Up to two run levels stack over permanent ranks, and bonuses clear on extraction/death. Gameplay/save/balance acceptance remains pending. |
| **P1 — source integrated; first two contracts gameplay-verified** | Two authored outings under each of the six existing main quest anchors, for twelve outings and 25 actions total. Keep the current side quests as side content and the current six route regions as campaign locations. Chapter 3/4 return and preparation copy is now order-neutral; dynamic J owns the next step. | `docs/STORY_AND_SCENES.md`; `data/maps/quests.json`; `data/maps/events.json`; `data/maps/npcs.json`; `scripts/systems/CampaignProgress.gd`; `scripts/components/CampaignAction.gd`; `GameState.gd`; `Wasteland.gd`; `HUD.gd` | Chapter 1 and Chapter 2 actions, extraction and Guild hand-in pass 109/109 and 50/50 injected-input journeys. Chapter 2 used the purge-air choice; verify its settle-sample alternative, Chapters 3–6, optional clues, return/settlement behavior and old-save semantics. Keep existing quest IDs, rewards and prerequisites. |
| **P2 — pacing and consequence review, deferred** | Measure the tutorial and regular outing targets, then tune path length, encounter count, breathing space, draft timing and return readability from observed play. | `docs/GAME_DESIGN.md`; route scenes/data; `docs/STORY_AND_SCENES.md` | A fresh tutorial playthrough lands near 6–8 minutes; representative regular outings land near 12–18 minutes. Record route, player actions, pauses and elapsed time so tuning can be reviewed. Confirm the first-return trickle arrives before the ending and that the final supply choice changes only the specified haul support and NPC/record acknowledgment, keeping one authored ending. Execute only after QA/playtest work is authorized again. |

**Acceptance update (2026-10-25):** the earlier 64/64 persistent-root run
verified only the first outing and is historical. The newer 109/109 journey
completed both outings, the chapter-total 5-kill/12-scrap goals, physical
extractions, real Guild hand-in, checksummed reload and repeat-delivery guard.
The later Chapter 2 GUI journey passed 50/50 checks, including both outings,
physical extraction, optional-ledger readiness/copy, Guild delivery, isolated
save reload and duplicate-reward prevention. The first-contract run used the
covered-long route; Chapter 2 selected purge-air. The exposed-short and
settle-sample alternatives, Chapters 3–6, save migration, death, balance and
release acceptance remain pending.

The first-contract bridge and v5 ledger are integrated in source; the first
contract's normal success path has gameplay acceptance. Water-stage visuals,
the v5 death-loss and
provisional state while v1-v4 legacy field trips retain their old immediate-bank
rules through first return. Temporary drafts are integrated in source; the
twelve-outing content and runtime now use the existing run record. Escort/carry
checkpoints, hold-E calibration, bounded defense waves and explicit choices are
source-integrated. A full ordinary player journey and later save/gameplay review
remain pending; no twelve-run or minute-target acceptance follows.

The guidance continuation adds 25 action-specific verb/instruction/result sets,
12 outing NPC briefings, six cleanup lines and shared NPC returned-choice records.
J/K field notes distinguish provisional and committed work; optional v5 chapter
markers preserve history without inventing it for legacy completed quests.
Compact world labels avoid the observed narrow HUD overlap. The
[guidance presentation record](journey-guidance/README.md) contains 26 staged PNGs,
two render exits 0 and 112 matching listed inputs. That source snapshot is now
historical. Return-feedback source now names extracted/lost action receipts and
partial-return continuation, exposes the existing last result through K, and
shares ending copy with the recorded City consent scope. Hand-in autosave failures
also produce an explicit warning. See [return-consequences/README.md](return-consequences/README.md)
for newer staged presentation. First-contract normal settlement/hand-in/save
reload are now verified; other action states, death, IO failure and compatibility
acceptance remain pending.

## Deferred scope

Keep the ending singular. Use local services and NPC responses for optional
consequences; do not add a branching-epic state system. Do not add a new
currency, online features, a starvation timer or endless scaling to solve the
campaign's pacing. Keep environment-art and character-art production outside
this gameplay sequence unless a concrete readability issue blocks a mission
action or return route.

## Validation boundary

The original presentation-only checkpoint ran no gameplay/QA suite and wrote no
real save. The 10/24 full visual-profile QA stages its field action; the newer
10/25 direct `AutomatedPlaytestRunner` run walks the first Scrap Highway outing
and activates its physical return gate. It suppresses the actual scene
replacement and stages later hand-in progress, so it does not validate a complete
player-controlled expedition. See `docs/QA_REPORT.md` for both records.
Verify draft choices, pending choices across sites,
reload and clearing on extraction/death, save migration, old active unmarked quests,
repeated extraction settlement, retreat, death, run reload, legacy v1-v4 trips,
permanent clue persistence, hub-only service guards and all three water stages.
Measure outing duration through actual play; source inspection alone cannot
establish the minute targets.

The earlier story-presentation snapshot is historical: its 20 PNGs, two exit-0
renders and 107-input identity record describe an earlier source state, and its
artifacts remain immutable. Another bounded staged capture is recorded in
[expedition-presentation/source_snapshot.json](expedition-presentation/source_snapshot.json)
and is historical for the source state before drafts. Draft and
[campaign-presentation/README.md](campaign-presentation/README.md) snapshots are
also historical after the guidance/field-note changes. That
[guidance record](journey-guidance/README.md) is now historical too; the current
return record is [return-consequences/README.md](return-consequences/README.md).
The latest [arrival briefing](arrival-briefing/README.md) adds ten staged title
views at both supported sizes. Destination/outing/next-step copy uses shared
journey state; HUD notices and hotkeys defer during transitions. Actual travel,
skip/pause and timing feel remain open. The earlier return capture
includes an unsaved-report state staged in memory, not an actual disk fault.
None establishes gameplay, save/load, balance or pacing acceptance.

The contract-readiness continuation unifies active requirement rows for readiness,
J and G's active main display. It exposes material shortfalls and provisional
counts, moves the delivery button before long outing descriptions, and prioritizes
mandatory goals over optional reading. Final-outing guidance allows completing
remaining goals before return or extracting early; it does not change requirements
or claim fewer trips were measured. [Sixteen staged views](contract-readiness/README.md)
record presentation only. Pending-choice restoration now waits for the router's
transition-finished signal; real arrival/skip/input behavior still needs acceptance.

The latest [story continuation](story-continuation/README.md) integrates six
Gemini CLI event-text patches after source/canon review. Twelve inter-chapter NPC
responses use actual journey hints rather than assume a fixed order for the first
four mains. Story clues have their own reading footer. The recovered GUI
[core QA report](qa/gui_core_20261024.md) passed on its earlier recorded tree; it
does not prove the twelve-outing traversal or the later copy/runtime changes.
The [new action/terminal record](action-readability/README.md) adds a live HUD
adapter, follower-anchored labels and real six-route terminal data, with22 staged
frames at both supported sizes. Timers and rewards remain unchanged. The latest
user stopped Gemini; Codex and GPT-6-Luna/xhigh workers now implement and review. Next
production now includes [world-label occlusion and map viewport corrections](ui-label-composition/README.md),
with26 staged views. Continue remaining native story/journey interfaces and the
full production ledger, and hand24 prepared missing-facing requests to an available raster generator.
No new candidate image or active angle is claimed. The latest full Godot visual
QA run `20261024T215336Z-b2508ce7` passed 29/29 launcher steps,
AutomatedPlaytestRunner 165/165, GameplayRegressionRunner 365/365,
VisualReviewRunner 75/75 captures and 307/307 visual checks,
CollisionRegressionRunner 52/52, WorldExpansionRunner 192/192,
DirectionalPresentationRegression 571/571, WorldAtlasRegression 82/82 and
SceneEntranceRegression 12/12. Its cold 800x600 launch passed 11/11 captures and
45/45 checks. The new title-confirmation, terminal, field-minimap and full-map
resize states pass and were visually reviewed. The first Scrap Highway walk
reaches the physical gate, but disables enemies, suppresses the actual return
scene and uses a fixture for later hand-in. The bounded persistent-root route
roundtrip does not enter Wasteland. Other route walks, live-combat traversal,
Wasteland extraction/return and an unstaged player hand-in remain open. No performance profile or Windows export
was run; this is not release readiness. See
`docs/QA_REPORT.md` and `docs/RELEASE_READINESS.md` for the report path and
release boundary.

The [onboarding increment](onboarding-journey/README.md) now aligns prologue/help
with two outing stages and the original once-only hand-in, removes J/K combat
collisions, protects an existing save before new-game reset and exposes pause
save/load feedback.24 final native frames cover both supported sizes. The
help panel now owns a reading pause, preserving external/story ownership;
blocking player input alone had left enemy/projectile simulation active. The
rejected pause overflow was repaired and all eight final pause frames reviewed.
This closes bounded source/presentation defects; live input, confirmation/IO,
full gameplay, saves, pacing and release acceptance remain pending. Next inspect
remaining dialogue, recovery and ordinary journey seams without running deferred
QA. Do not restart Gemini under the latest model instruction.
