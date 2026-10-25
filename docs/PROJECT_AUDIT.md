# Project audit — Wasteland Recycler

## Current follow-up: first two contract journeys and story continuity (2026-10-25)

| Priority | Evidence-backed finding | Disposition / remaining scope |
| --- | --- | --- |
| P1, first playable chapter loop | An isolated 109/109-check GUI journey used both physical Scrap Highway extractions, completed chapter-total goals, delivered at the actual Guild counter, reloaded the checksummed save and retried the interaction. | First-contract normal success is verified. The test selected the covered-long route; the exposed-short option, human pacing, later chapters, death, old saves and field water-stage visuals remain open. See `QA_REPORT.md`. |
| P2, free-order Chapter 3/4 follow-up copy | Chapters 1–4 are free order, but some completion, return and preparation lines implied that the factory command or City archive was always the next unfinished task. | Chapter 3/4 story, debrief and preparation copy now avoids fixed sequencing and points to dynamic J. A project-data regression covers both main completion strings and their return/preparation copy; the focused module passed 34 tests. Current-source Godot 4.6.3 `core` QA passed 24/24 steps after the edit. |
| P2, Chapter 2 optional clue framing | The original quest description disclosed what the optional pump ledger would reveal, while the story step and Alan's briefing made the clue sound mandatory. | Chapter 2 GUI journey `20261025T025900Z-rerun` passed 50/50 checks, including readiness and Guild J copy with the ledger undiscovered, without revealing its result. Its report's derived `unverified_branches` field contradicts those explicit passes; the driver bookkeeping is corrected in the current tree but not rerun. The separate Chapter 4 black-box wording correction also clarifies that clue is optional and remains unvalidated. |
| P2, Chapter 6 enemy/item terminology | The facility event follow-up called the enemy a “失控核心” immediately before requesting a “動力核心,” but the quest and NPC briefings call the enemy a runaway guardian. | Corrected the event copy to “失控守衛” in the working tree. This copy-only change has not been tested or seen in a runtime journey. |
| P2, Chapter 5 consent scope | The city choice let Alan select public release of both his and Liu Qing's names, but the story records no independent consent from Liu Qing. Other NPC copy also implied resident names would be restored publicly. | The working tree now lets Alan decide only about his own name; Liu Qing's and other residents' names stay in the restricted Guild copy while districts, water lines and household IDs remain public. Choice IDs and save shape are unchanged; old `ch5b_publish_consent` selections now resolve to Alan-only publication. No test or runtime journey covers this copy change yet. |
| P2, water urgency implied a missing countdown | The story said water would last only a few days while gameplay had no water timer and used ration stages. | Player-facing story now frames scarcity as scheduled rationing with no deadline. The first-contract GUI run confirms the first two debriefs preserve that state and only the physical Guild hand-in changes the contract result text. Visual village-state transition still needs acceptance. |
| P1, full campaign not yet player-verified | Six chapters / twelve outings / 25 actions are authored, but two successful chapter journeys cannot prove the remaining four or campaign pacing. | Continue through Chapters 3–6 with authentic inputs and actual gates. Keep human playtime/balance findings separate from automated runs. Chapter 2's settle-sample choice is also open. |

The latest isolated Godot 4.6.3 `visual` profile (`20261025T020943Z-87d60cad`)
passed 29/29 steps, including 77 captures / 320 runtime checks and a cold-narrow
11-capture / 53-check run. Its source-tree hash is `01b5f899…`; the later
Chapter 2 journey reports a different source snapshot, `67b7cce9…`, so visual
coverage must not be projected onto that later snapshot. The documentation
profile `20261025T021833Z-cb858328` passed 3/3 before the latest copy and
driver-bookkeeping edits. The earlier full `all` profile remains the source of
the single-host performance baseline; it does not demonstrate an improvement.
Reports and scope are in [QA_REPORT.md](QA_REPORT.md).

## Historical follow-up: terminal layout, death recovery and QA checkpoint (2026-10-24)

| Priority | Confirmed issue | Current disposition |
| --- | --- | --- |
| P2, locked terminal was left-aligned and duplicated the journey summary | Native 1024x768 capture showed two narrow cards with unused modal space and a second journey card below. | The scroll child now expands horizontally; recipe and journey cards fill equal columns, and the bottom summary is retained only after the terminal controller is unlocked. Runtime checks cover both supported captures. |
| P2, no readable death/recovery presentation in wasteland | Earlier visual review staged the death condition in the Village, so it rendered a healthy HUD and did not cover the actual recovery state. | Added a Wasteland-only R-17 recovery panel with clear provisional-loss text, clinic retry button, E shortcut, and gameplay input blocker. Viewport changes trigger a settled layout pass. Both death screenshots are now in the required visual set and remain inside the viewport. |
| P2, privacy-choice dialogue stated public consent before the choice | Allen's story line declared public family names before the current outing choice was resolved; the dialogue is selected only by outing ID. | Reworded it to leave public naming to the outing choice while retaining the invariant that affected districts and water-short households stay public. No quest IDs, triggers or rewards changed. |

The last full isolated Godot 4.6.3 `visual` snapshot for this follow-up passed
27/27 launcher steps, 356 gameplay regressions, 62/62 screenshots and 176/176
runtime checks. It is historical evidence and is superseded by the 2026-10-25
run documented below and in [QA_REPORT.md](QA_REPORT.md). Neither full visual
profile proves a complete physical player campaign. A separate direct playtest
passed 165/165 but walks with enemies disabled, suppresses the gate-driven scene
replacement and stages later hand-in progress. The newer persistent-root input
journey passed 64/64 and verifies one actual first Scrap Highway outing, physical
extraction, routed Village return and debrief. It leaves the quest incomplete at
1/2 outings and 2/5 kills; no second outing or hand-in was attempted. No
performance profile, save/load fault injection or export was part of the earlier
full-profile run. Asset validation warned that authored player clips reuse
frames; smoothness/60 FPS remains unverified. Earlier report:
`C:\Code\Game\qa-output\2026-10-24-story-ui-final\20261024T132644Z-d6c30559\qa-report.json`.

## Current follow-up: story continuity and stale runtime ownership (2026-10-24)

| Priority | Confirmed source path | Source disposition |
| --- | --- | --- |
| P1, stale action write during load | `CampaignAction._exit_tree()` flushes cached dirty progress after Router has silently applied the candidate. `update_campaign_action` previously checked current quest/route/outing/status only; the same action, including an older snapshot of the same run ID, can accept an old node's write. | Transient generation plus run/quest/route/outing owner captured at setup and checked on write. Router preflushes current-scene actions under cover before identity/apply; exact rollback includes generation. No schema/reward change. Runtime fault/reload/extraction acceptance remains deferred. |
| P2, NPC paging does not end/reset | Final E repeated second_line indefinitely. HUD Esc/panel close did not reset the NPC page; reopening nearby could skip the first line. `body_exited` cleared the near flag before the distance helper and could bypass cleanup. | Explicit first/last/close lifecycle, owner-specific reset and corrected distance-exit path. Actual E/E/E, Esc/reopen and range input remain unexercised. |
| P2, report overwritten by stale NPC input | Shared panel accepted E against any nearby active NPC. Closing an NPC then opening a quest report could leave that NPC active and allow its second line to replace the report. | Scoped NPC request/close signals, transient HUD owner ID and exact Player filter. Generic reports retain original signal and no NPC paging owner. No actual report/input scenario executed. |
| P2, obscured escort | Initial two frozen escort frames showed a foreground bridge beam hiding the follower's body while the player stood clear. Architecture fading sampled only the player. | Register local active followers and include their silhouettes in the existing BitMap/alpha0.32 fade; preserve collision/placement and0.2 cadence. Before/final images identify the camera; actual escort movement remains unexercised. |

Bounded manual data review covered all25 action coordinates and six route IDs;
escort/carry endpoint dependencies align with their next action/return approach.
No data-proven blocked target was found. Authored architecture/ground collision
does not share every campaign reservation, and one covered path shortcuts a road
junction: these remain traversal coverage limits, not confirmed collisions.
No validator, traversal, tests or save payload IO ran. The
[continuity record](story-seams/README.md) separates source and picture evidence.

## Current follow-up: screen inventory, chapter guidance and extraction layout (2026-10-25)

| Priority | Confirmed source issue | Current disposition |
| --- | --- | --- |
| P1, near-spawn extraction shortcut / blocked first route (corrected; broader traversal pending) | All six routes previously spawned the player 210 world pixels from the shared return gate; the legacy 184×128 gate trigger began about 102 pixels away. The first direct Scrap Highway walk then found its landmark bus collider intruding into the central northbound road. | Each route now authors a far-side terminal-road gate, with generated prop/resource/enemy clearance reserved around it. Moving the Scrap Highway landmark farther west cleared the tested lane. The older 165/165 path runner disables enemies, suppresses SceneRouter replacement and stages later hand-in. A newer persistent-root Godot 4.6.3 input journey passed 64/64 checks and confirms actual first-contract entry, field actions, physical extraction, routed Village return and a generated debrief; the quest remains at 1/2 outings and 2/5 kills. This is not a full campaign. Other routes, second outing, unstaged hand-in, save and balance acceptance remain open. |
| P1, excessive enemy pressure / endless ordinary refills (source-corrected; balance and performance pending) | The failed 2026-10-24 first-contract journey reached only five of six escort waypoints with 11 HP and enemies close. Source review found non-boss enemies pursued the player without an aggro bound and the periodic Wasteland population check refilled ordinary enemies around the player up to the configured cap. | Non-bosses now acquire at 720 px, release at 900 px and return toward their spawn anchor; bosses retain their explicit chase behavior. When every authored action in the current outing is done, periodic ordinary-enemy refill pauses without removing remaining enemies. Scene-entry population and authored wave/boss spawn paths remain. The later 64/64 journey completed the first outing and extraction at 96/120 HP with enemies active, and the 24/24 core QA passed after the gameplay changes. This is not a comparable performance benchmark or broad combat-balance result. |
| P2, contradictory free-order chapter guidance | Chapters 1–4 allow free order, but several completion/preparation hints named a fixed next chapter. Chapter 5's report said the register had already been delivered and verified, then its preparation hint asked for the same handoff again. | Relevant debrief copy now preserves findings and preparation while deferring the immediate next quest to the existing dynamic J/journey hint. No quest IDs, objectives, rewards or prerequisites changed. Source/data review only. |
| P2, no maintained screen/state coverage record | AGENTS.md required an inventory of entry/exit controls, focus/scroll, viewport coverage and evidence; the referenced matrix did not exist. | Added [SCREEN_STATE_MATRIX.md](SCREEN_STATE_MATRIX.md) with current-run screenshots, runtime assertions, staged presentation, input coverage and remaining gaps. The latest visual run captures J, stacked inventory, expedition draft and campaign-choice screens; the cold 800x600 process adds 11 staged screen captures and first-focus/input checks. Logical content stays at 1024x768, and full modal focus/mouse coverage plus player reachability remain open. |

The last full isolated run `20261024T182716Z-05ceac96` passed 29/29 launcher steps,
including 70 captures/254 visual checks, 11 cold-window captures/32 cold checks,
and the route collision/world-expansion assertions noted above. It verifies
presentation and authored clearance for its recorded snapshot, not a full player
journey, save IO fault handling, performance or release export. A later direct
165/165 playtest adds physical traversal and gate E evidence for the first
Scrap Highway outing, with the harness limitations described above. Full-profile
counts and source hash are in [QA_REPORT.md](QA_REPORT.md).

## Current follow-up: preparation and load consistency (2026-10-24)

| Priority | Current evidence | Disposition |
| --- | --- | --- |
| P1, source-corrected; IO/fault acceptance pending | Previously SaveManager applied data before Router travel and Router restored only scene/spawn; Main discarded title and HUD closed pause on request bool. Old runtime could remain paired with loaded run/inventory/route. | Dedicated load request/completion, silent apply and exact35-field + raw-expedition checkpoint/rollback now integrated. Failure retains title/pause, normalization and legacy/v5 rules remain. [Load evidence](load-consistency/README.md): eight synthetic UI frames, no actual transaction/fault. Native `_ready` exceptions remain outside the return-code recovery boundary. |
| P2, wrong weapon rank | Space/right-click resolves melee/ranged, but stat calculation used selected quick-slot weapon rank. | Pass actual weapon ID; other bonuses unchanged. Source reviewed; combat unexercised. |
| P2, unsupported scan promise | Tool announced marked salvage without querying targets; controller hint promised unsupported remote control/decryption. | Nearby actual unclaimed-target query, max6 transient pulses, honest empty info and private cooldown; truthful controller hint. Frozen helpers rendered; actual action unexercised. |
| P2, stranded failed death travel | Automatic death travel ran once; failure left HP0/death_pending without retry. | Guarded Esc-pause retry; no early healing/settlement. UI rendered; actual failure/retry unexercised. |
| P2, workshop clipping | Native narrow craft/mod/forge/perk overflow162/72/74/82px; wide craft42px. Costs/buttons visibly clipped. | Allocated-width cards, wrapped prose, single-line badges. Final PNGs inspected; live resize unexercised. |
| P2, disappearing mouse controls | I/C/J/T/K switcher/close was in each scrolling list; tail captures hid it, although Esc remained available. | Shared fixed header outside original SC; final tails retain controls. |
| P3, material affordance | Resource cards used the same equip-style Button path as gear. | Labelled non-equippable status cards, distinct gear buttons, explicit bank/haul ammo and hub rule. |

[Preparation evidence](preparation-journey/README.md):34 final images,112 matching
listed inputs, two observed exits0, ten baseline images and rejected drafts.
No QA/input/save IO/performance ran. This bounded source review found no additional
ammo softlock, unreachable recipe or partial-cost defect; do not invent a rewrite.

## Current follow-up: onboarding and recovery feedback (2026-10-24)

Fresh source inspection confirmed these bounded issues. Corrections are
source-integrated; actual input/save and complete gameplay acceptance remain open.

| Priority | Evidence and issue | Current disposition |
| --- | --- | --- |
| P1, progress protection | `Main._new_game()` reset memory immediately; `_finish_intro_to_game()` then overwrote the one slot without a new-game warning. This is a source-confirmed overwrite path, not an observed player-loss incident. | Existing-slot confirmation now precedes reset; cancel is side-effect free. The overwrite point is unchanged. Native popup is rendered; actual confirmation/cancel/IO remains unexercised. |
| P2, contradictory controls | `GameState._ensure_input_actions()` bound J/K to attacks, while `HUD._unhandled_input()` used them for contracts/notes. The tutorial also called right-click melee and advertised arrow movement unsupported by the current bindings. | Remove only the two combat key registrations. Keep mouse/Space and menu keys; correct the guide. Actual input behavior is pending. |
| P2, stale journey promises | Main described a single repair outing then delivery; help omitted both authored outing stages and promised unsupported divine-weapon rewards and a boss shockwave. Quest data and combat sources disagree with those claims. | Explain two outing stages plus original goals and one hub delivery; remove unsupported rewards/encounter advice. Preserve optional clues, nonlinear first four chapters and limited water. |
| P2, hidden save outcome | Pause save/load callbacks only triggered the global notice, while `_update_notice_visibility()` explicitly hid it underneath pause. | Add inline bool feedback using existing SaveManager calls. Native synthetic states render; no save fault was injected. |
| P2, reading under attack | H set the player input blocker but was absent from HUD reading-pause ownership. Enemy and projectile physics had no corresponding blocker guard; CampaignAction did stop. This inconsistent source path could leave a motionless player taking damage while reading. | Include only help in existing owned reading pause, dialogue transfer and exit cleanup. Frozen native help capture observes owned pause; actual enemy/input/pause switching remains unexercised. |
| P2, newly observed layout | First ordinary pause captures showed the outer panel below both viewport edges despite the script assigning520px height. Wrapped status outside the scroll enlarged native minimum sizing. | Move status inside ScrollContainer and remove forced Label reset. Final eight pause views show480x520 panels fully enclosed; no arbitrary-size or live resizing acceptance follows. |

[Onboarding evidence](onboarding-journey/README.md) preserves24 final images,
source identity, final exits and rejected logs. The legacy help branch was also
corrected during review: its discoveries count immediately, while the new ledger
requires extraction for unbanked clue credit. No save/gameplay rule changed.

## Current follow-up: environment cohesion (2026-10-23)

Further confirmed findings from the road/convoy production frames and source:

- **P1, local art/source correction:** the coach was only about 191x127 world
  pixels beside a 100-pixel hero, and its road/shelter foreground lacked a shared
  shoulder/forecourt. Current coach-stop integration gives it 320x213 visible
  scale with proportional collision, a routed feeder and 96-pixel yard spur,
  sparse irregular ground transition and bounded wall/rubble framing. Native
  occlusion fade and bottom target text correct hero/HUD obstruction. The old-size
  saved-entry fallback is source-reviewed, not executed. See
  `art-direction/world_v4/convoy_courtyard.md` and its 14-frame ordinary evidence.
  Local composition improved; full-world/traversal/old-save acceptance remains open.
- **P1, local correction only:** later hub/entrance frames still showed separate
  prop islands on a broad dirt field despite matching materials. Village's east
  trade court now connects actual market/house/repair feet and the Guild threshold
  through the existing ground sampler. A Village-only continuity setting keeps
  the road core readable; two physically registered wall segments frame the
  house-to-Guild frontage with saved-position exclusion. This addresses one district; full-world
  cohesion remains open. See `art-direction/world_v4/entrance_readability.md`.
- **P2, source/local camera correction:** the nearby Village Guild/east gates
  shared a silhouette. A distinct Guild arch and separated east gate reduce that
  ambiguity. Redundant world badges and an experimental overlay panel were
  removed in favor of the existing HUD hint row. Hub M roads now use the actual
  loaded lane segments. Walking/transitions were not executed.
- **P1:** nested WorldProp Y sorting used the negatively offset sprite top;
  a wagon canopy was hidden by a farther depot. Grouped body-foot sorting fixes
  this in the same camera. Original art/collision feet are preserved.
- **P1:** highway median placement 10 crossed the west-turn corridor. Its four
  physical rectangles were retained and moved west onto the shoulder. Source
  clearance and camera presentation are recorded; traversal remains unverified.
- **P1, source and local camera correction:** the road/convoy Village/Guild
  frames exposed metallic floors and neon facilities. The later hub checkpoint
  replaces these with shared material ground, stone/timber fixtures and frontage.
  Registered roots use sampled earth; original art/fallbacks remain. See
  `art-direction/world_v4/hub_presentation.md`. Whole-hub traversal/player
  acceptance remains open; repeated gateways and sparse circulation remain P2.
- **P2:** fullscreen map resource/site labels overlapped; essential bounded labels
  plus hover detail replace the clutter. Nearby duplicate region names are suppressed.
- **P2:** path validator rejected diagonals already consumed natively and present
  in a highway branch. Nonzero finite segment and projection-based reachability
  rules replace the stale restriction. Related existing tests were updated, not run.
- **P2, open:** expanded diagonal-segment AABB spawn reservations remove more land
  than the visible path; roadside sample spacing restarts at each segment. These
  source risks need future route-density work, not an unmeasured speed claim.

Evidence: `art-direction/world_v4/road_and_convoy.md` and
`art-direction/world_v4/captures/road-and-convoy/`. No QA suites ran.

P1 visual defect, confirmed by source and representative scene captures: the
64px grayscale FastNoise floor, geometric road/basin marks, detailed independent
architecture and globally selected legacy props did not share a material/scale
contract. The v2 facade captures established silhouettes, not complete scene
cohesion. The user subsequently rejected v3's palette-only correction. V4 replaces
oversized paving and frontal structures with finer paving, oblique architecture,
rooted debris and site-specific landmark sources. Optional regional floors and
shared polygon basin geometry address repeated brown floors and rectangular water.
WorldBackdrop/WorldProp/Wasteland retain their owners and fallback paths. Current
evidence and remaining scope are in `art-direction/world_v4/README.md`; no tests/QA
were run under the current user instruction. Whole-route composition, traversal
and gameplay acceptance remain open; art captures alone do not close this P1.

## Current follow-up: scene and story audit (2026-10-22)

The later motion/expansion pass confirmed three additional behavior defects in
source and regression tests: instant melee damage before the visible swing (P2),
an inherited action timer delaying a new action's phase (P2), and nano-salvage
pickups healing a zero-health player during pending death (P1). The current
changes add synchronized melee windup, fresh per-action timing and dead-player
pickup/reward guards. Directional tests validate actual distinct source crops,
not merely eight animation names. Codebase Memory later returned `Transport
closed`; direct source inspection was used, without a complete graph claim.

This follow-up starts from Gemini's clean revision `4ab05f0`, rather than the
older baseline below. Inventory: 1,883 tracked files, 41 GDScripts, 13 scenes,
840 PNGs and 12 JSON files. Read the current instructions, runtime scenes,
services, route/quest/NPC/event/art data, asset loaders and QA runners. The fresh
core baseline `20261022T092303Z-bb45e37d` passed 16/16 gates on Godot 4.6.3.
The graph index excludes `scripts/` and reported changed scene metadata; source
reads supplied the evidence for those paths. No exhaustive graph claim is made.

| ID / priority | Confirmed evidence | Disposition in this change |
| --- | --- | --- |
| B01 / P1 | Six route definitions but four village gates and four distinct quest destinations. | Add reachable gates and two connected finale contracts. |
| B02 / P1 | `weapon_levels` was mutated by forging but absent from save serialization/loading. | Add optional validated field, legacy defaults and file-backed regression. |
| B03 / P2 | Saved discoveries had no reading UI; NPC pages did not follow campaign state. | Six physical evidence sites, K journal, conditional NPC responses and completion payoff. |
| B04 / P2 | Six generic event nodes cycled four definitions, duplicating two scoped IDs. | One physical node per generic event ID; story sites are separate. |
| B05 / P2 | Highway screenshots show factory-grate atlas block and large repeating ground panels. | Use cached fine-grain biome surfaces, low-contrast palettes and authored road corridors. |
| B06 / P2 | Old factory story Boss requires 40 lifetime defeats although preceding quest goals total fewer. | Active Boss contracts request their encounter directly; free exploration keeps the threshold. |
| B07 / P2 | Handoff/release docs cite old dirty-tree evidence and runners/export gates absent from the current launcher. | Replace current status with traceable run IDs and explicit release limitations. |
| B08 / P3 | City/facility reuse common props and lack unique evidence silhouettes. | Add two new transparent landmarks; preserve all existing PNGs and the latest knight. |

Acceptance, data/persistence details and bilingual player steps are in
`STORY_AND_SCENES.md`; executed final results are in `RELEASE_READINESS.md`.
Human narrative pacing and a complete manual six-region playthrough remain
separate from automated correctness and screenshot inspection.

---

## Historical modernization baseline (2026-10-21)

Audit date: 2026-10-21 (Asia/Taipei). Technical specification in English; see
`DEVELOPER_GUIDE.zh-TW.md` for the developer overview. This is an evidence-based
snapshot of the starting revision, followed by an implementation disposition.

## Scope and baseline

- Actual Git / Godot root: `first-game/`, starting at `ffa49ca5c92c3146297f6ef261c4f3024afd6709`.
- Starting branch: `wip/codex-3d-game-progress`; working tree was clean.
- Installed engine: `4.6.3.stable.official.7d41c59c4`, verified with `--version`.
- Inventory: 1,624 tracked files; 38 GDScripts, 11 scenes, 10 JSON documents,
  725 PNGs, 17 WAV-named files and one MP3. `.godot/` is ignored.
- Read all entrypoint instructions, scene/source/data inventories, runner sources,
  existing reports, export configuration, and the relevant runtime dependencies.
  Codebase Memory lists no index for this checkout: findings use direct source
  reads and searches, without graph completeness claims.
- Historical playtest/performance reports were last committed on 2026-06-22 and
  contain no run timestamp. They were not treated as current passes.
- Baseline commands ran against a tracked-file mirror with a separate custom Godot user
  directory. The existing real player save was not used or overwritten. Logs are
  in the external `wasteland-baseline-wq37vrm0` temporary run directory.

| Check | Starting result | Interpretation |
| --- | --- | --- |
| `--headless --editor --import` | exit 0, nine ERROR lines | Three MP3 streams named WAV fail Godot import; exit status alone is insufficient. |
| `--headless --quit` | exit 0, ObjectDB exit warning | Startup smoke only, not proof of all script paths or leak-free shutdown. |
| `ValidationRunner.tscn` | exit 1, 19 failed assertions | Mix of obsolete assertions, missing UI groups and resource contract drift. |
| `AutomatedPlaytestRunner.tscn` | exit 1, one failed assertion | `village: HUD shows 4 quick slots`; actual slots exist in the screenshot, group registration is missing. |
| `PerformanceRunner.tscn` | exit 0 | 90 physics frames, 30 bare enemy bodies, 200 allocated projectiles; mean physics cadence 15.3875 ms. Not rendered FPS. |
| `verify_visual_assets.py`, default Python | unavailable | Python 3.11 lacks Pillow. Bundled Python has Pillow. |
| `verify_visual_assets.py`, bundled Python | exit 1, 122 issues | Missing manifest paths, obsolete body/hand heuristics, MP3/WAV format mismatch. |
| GUI `VisualReviewRunner.tscn` | exit 0, 11 PNGs | Village, three action views, guild, wasteland road, four routes. Inventory/map/Boss captures silently absent. |

The first fresh import log was captured before a console encoding failure in the
external orchestration script; import and all checks were then rerun with UTF-8.
No product result is inferred from that failed orchestration attempt.

## Existing systems and maturity

| System | Implementation and current limits |
| --- | --- |
| Application / scenes | Main title and intro; village, guild, one data-driven wasteland scene. Five existing autoloads. Core scenes instantiate successfully. |
| Player | Eight directions, nine actions, eight frames each; movement/collision, sprint/energy, melee/ranged, quick slots, hit/death feedback. Current runtime uses the existing preview atlas; overlays intentionally disabled. |
| Combat | Seven enemy definitions with distinct chase/dash/ranged/hybrid/Boss behavior; collision bodies, health, drops, pooled projectiles capped at 200. Synthetic pool smoke exists. |
| Inventory | Four resources, 14 equipment entries, eight recipes; equipment compatibility, consumption, forge/shop/crafting/upgrades. Stack limits are descriptive, not enforced capacity. |
| Quests | Six contracts, automatic next-contract selection, objectives, rewards and completed ids. Progress scope and Boss objective do not yet match the story contract. |
| World | Four route definitions with seeded themes, enemies, resources and props. Encounters repopulate on entry; `route_states` is serialized but unused. No persistent cleared-world contract. |
| NPC / dialogue | Six NPCs, first-talk reward guard, dialogue panels, distance dismissal and procedural motion. Shared E input has no single-target arbitration. |
| UI | Title, HUD, inventory/equipment, quest summary, dialogue, maps, tutorial, pause/save/load and death feedback. Mostly procedural Controls; test groups and viewport/marker handling drifted. |
| Persistence | Version 4 payload with Base64 and SHA-256 corruption check. Counters, equipment, quests and route id persist; position spawn semantics and schema validation need repair. Checksum is not authentication/encryption. |
| Art / audio | R-17 authored preview atlas and split frames exist. Latest item replacements are resolved partly through runtime overrides. Validation still assumes deleted assets and an earlier overlay style. |
| QA / release | Four requested runners exist. No consolidated safe launcher, dependency declaration or representative performance regression gate. Export presets alone do not prove a distributable build. |

## Prioritized findings

No P0 crash was observed during the baseline. P1 prevents reliable delivery or
risks player progress; P2 is a functional/verification defect; P3 is maintenance
or a design limit requiring an explicit product decision.

| Id | Priority | Evidence at starting revision | Impact / recommendation |
| --- | --- | --- | --- |
| A01 | P1 | `SaveManager.gd:3,15`; `VerticalSliceVerifier.gd:136,239`; `AutomatedPlaytestRunner.gd:124` | Test runners overwrite the real `user://save_game.json`. Isolate every writing test and provide a safe launcher. |
| A02 | P1 | `SaveManager.gd:8-20,48-49`; `Village.gd:52`, `Guild.gd:41`, `Wasteland.gd:72` | Saved coordinates are ignored because no gameplay path requests the `saved` spawn. Separate explicit restore from scene-transition entrypoints. |
| A03 | P1 | Fresh import ERROR logs; `AudioManager.gd:6-8`; MP3 headers in three `.wav` files | Clean import fails to create audio resources. Correct filenames/references while preserving original audio bytes. |
| A04 | P2 | Starting-revision evidence: `GameState.gd:323-350,377-398` | Resolved in current source: enemy and Boss objective counters advance only on the active quest route (`GameState.gd:1222-1225`, `_is_active_quest_route()`), and the current gameplay regression explicitly verifies wrong-route and matching-route kills. The current HUD hint also distinguishes those kill counters from salvage carried home. Keep the route mismatch guard covered. |
| A05 | P2 | Starting-revision evidence: `quests.json:56-74`; `Enemy.gd:134`; `Wasteland.gd:288` | Resolved in current data and regression: `old_factory_core` requires its Boss objective; ordinary kills do not satisfy it, and a Boss killed on another route does not advance it. The current gameplay regression covers these cases. |
| A06 | P2 | `GameState.gd:478-525`; `SaveManager.gd:30-43`; `Main.gd:113-119` | Invalid types/versions can partially apply state; failed Continue destroys title before checking load. Validate before mutation and retain a usable menu on failure. |
| A07 | P2 | `DialogueNpc.gd:47-56`; `Interactable.gd:32-35`; village NPC/station positions | Merchant/forge and repair/craft interaction radii overlap. One E can trigger both. Select one eligible nearest target. |
| A08 | P2 | `visual_assets.json`; `DataRegistry.gd:3-58`; `Player.gd:7`; missing-path scan | Thirteen declared asset paths are absent although replacements exist. Consolidate manifest references to current art; do not regenerate authored files. |
| A09 | P2 | `HUD.gd`; baseline 19/1 assertions; GUI captures | HUD groups expected by tests/capture scripts are missing. Register existing components; tests must check the current atlas/data/Boss spawn contract. |
| A10 | P2 | `WorldMapView.gd:75-87`; inspected village PNG | Promised enemy/pickup groups omitted; markers can draw beyond the map rectangle. Include useful groups and clip/map positions correctly. |
| A11 | P2 | `VisualReviewRunner.gd:15-24,146-166`; README headless command | Headless runner exits 0 without images; missing targets silently skip. Return a failed/skipped result and capture all supported interfaces with a real renderer. |
| A12 | P2 | `PerformanceRunner.gd:13-43` | Physics timer cadence mislabeled as FPS; no real enemy work, distribution/memory/environment metrics or failure assertions. Preserve smoke and add representative measurements. |
| A13 | P2 | `verify_visual_assets.py:100-111,198-209`; checklist build commands | JSON check only parses; atlas absence silently allowed; color heuristics reject valid side/back views. Validate current references/atlas structure and separate visual warnings from proven corruption. |
| A14 | P3 | `AGENTS.md`, `WORKFLOW.md`, `AI_HANDOFF.md`, missing `docs/IMPLEMENTATION_PLAN.md` | Duplicated rules, machine paths, automatic push snippets, mandatory asset rebuilds and dead documentation references. Replace with concise canonical English instructions and a Traditional Chinese guide. |
| A15 | P3 | `route_states` source search; `equipment.json` stack fields | Cleared-route persistence and inventory capacity are not implemented contracts. Document current reset/unbounded-resource behavior; do not silently invent a migration/capacity policy. |
| A16 | P3 | `HUD.gd` 713 lines, `GameState.gd` 617 lines; baseline shutdown warning | Large procedural modules increase change coupling. Keep fixes local; investigate lifetime/performance evidence before splitting or claiming a leak fix. |

## Architecture and performance assessment

The scene → autoload → JSON/signal structure is serviceable; no subsystem needs
replacement. The highest coupling is progression, autosave and scene routing.
Save schema changes must retain legacy defaults and reject malformed input before
mutating live state. Keep counters and inventory resource mirrors synchronized.
The cache in `RuntimeAssetLoader` avoids repeat PNG/audio construction only where
implemented; no comparable timing yet establishes a bottleneck. The physics-only
baseline above cannot support CPU/GPU or release FPS claims. No optimization is
justified until representative and repeatable measurements exist.

## Implementation sequence and acceptance

1. **B — Agent infrastructure:** one authoritative AGENTS, risk-based lifecycle,
   bounded handoff, Traditional Chinese guide, four distinct repo-local Skills.
   YAML validation, path checks and discovery evidence required.
2. **C — Reliability:** safe isolated QA, save restore/schema handling, audio and
   manifest reference repairs. Reproduce failures, add regression coverage and
   retain original authored bytes. No broad scene rewrite or art regeneration.
3. **D — Playable progression:** per-contract/route progress, Boss requirement,
   duplicate reward guard and single-target interactions. Exercise all contracts,
   save/reload, death/return and upgrades through existing infrastructure.
4. **E — Usability:** HUD discovery, usable maps, menu/load feedback and visual
   captures. Inspect screenshots at 1280×720 and a smaller PC window; retain R-17.
5. **F — Delivery:** run fresh integrated import, validation, playtest, regression,
   data/art and rendered visual checks; collect representative performance and
   inspect export capability. Update `AI_HANDOFF.md` and `RELEASE_READINESS.md`.
   Commit only verified groups; no push. Report unavailable checks separately.

Final dispositions and fresh test evidence belong in `RELEASE_READINESS.md`;
this baseline remains unchanged so regressions can be compared honestly.
