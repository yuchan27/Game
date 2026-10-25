# Wasteland Recycler — campaign and expedition design

Updated: 2026-10-25 (Asia/Taipei). This is the canonical English gameplay
design. The six-chapter, twelve-outing campaign is authored in quest data and
integrated with its source runtime. Isolated Godot 4.6.3 GUI journeys verify the
first contract (109/109 checks) and Chapter 2 (50/50 checks), including both
outings per verified contract, physical extraction, Guild hand-in, isolated save
reload and duplicate-reward prevention. The remaining four chapters, death
loss, old-save compatibility, alternative choices, broader balance and pacing
remain unverified. The latest full isolated QA and journey limits are summarized in
[`QA_REPORT.md`](QA_REPORT.md); neither pacing estimate is measured. Player-facing
copy remains Traditional Chinese.
Narrative beats and sample dialogue live in
[`STORY_AND_SCENES.md`](STORY_AND_SCENES.md).

## Player promise and campaign shape

R-17 leaves a village that needs water, takes dangerous trips through six
wasteland routes, and returns with useful material and evidence about the
people affected by an old emergency closure. A trip should make its purpose,
field action, return condition and lasting result clear. Combat and salvage
create pressure and supply the trip; they do not replace its authored action.

The campaign has six chapters and twelve main outings: two outings per chapter.
The quest data stores these outings under the existing six main quest IDs, which
remain the chapter and save-compatibility anchors. The authored sequence has 25
actions across escort, carry, channel, defend and choice modes. It does not
create twelve unrelated main quest IDs. Preserve the two existing side quest
IDs as side content, along with old IDs, rewards, completed state and
active-quest meaning. Stable outing IDs are `ch1a_escort_repair`,
`ch1b_route_coupling`, `ch2a_sample_taps`, `ch2b_first_flush`,
`ch3a_resonator_sync`, `ch3b_relay_defense`, `ch4a_isolate_alarm`,
`ch4b_vent_defense`, `ch5a_district_map`, `ch5b_household_record`,
`ch6a_sensor_review` and `ch6b_supply_test`.

| Chapter | Existing main quest anchor | Route | Authored outing beats |
| --- | --- | --- | --- |
| 1. First water | `clear_scrap_route` | Scrap highway | **A:** escort the recovery crew, then repair the south bypass relay. **B:** the crew is already back in the village; R-17 alone chooses an exposed short route (more ambush pressure; selecting it adds two mutant herbs to the run haul, banked only after a safe return) or a covered longer route (fewer encounters, no bonus supplies) to carry the coupling to a staging point by the far-side return gate. The carry checkpoints do not complete the return; R-17 must reach the actual gate and press E. |
| 2. Measure the water | `toxic_sample` | Toxic marsh | **A:** seal an upstream sample, then calibrate a return-flow sample. **B:** choose slow settling (hold E for 8 seconds; selection adds two mutant herbs to the run haul) or quick purge (hold E for 3.5 seconds; selection adds four rounds of ammo). Then open the controlled return valve; the selected supply banks only after safe return. This is a small test and does not change village allocation. |
| 3. Direction of the echo | `crystal_scar_recon` | Crystal scar | **A:** align the south resonator and replay the gate echo. **B:** carry the charged relay to the authored south-entry connection point, then defend its output to preserve a copy of the echo verified in A. The relay stays there; after the defense, follow the northbound road to the separate far-side return gate and press E to extract. |
| 4. Why the gate stayed shut | `old_factory_core` | Old factory | **A:** isolate the contamination-warning branch, then read the operator's closure order and missing review. **B:** open the pressure vent and defend it through stabilization; the existing contract's boss/core requirements remain. |
| 5. The severed district | `metropolis_archive` | Ruined metropolis | **A:** power the distribution map and mark affected household rows. **B:** copy the register; Alan decides whether his own name appears publicly. The current record has no Liu Qing consent to publish her name, so hers and other residents' names stay in the restricted Guild copy. The affected district, water lines and household numbers stay public either way. |
| 6. A human opens the valve | `facility_memory` | Underground facility | **A:** compare the alarm threshold with a new sample and mark the stale isolation flag for review. **B:** start the controlled bypass and defend the pressure test, then record priority for clinic support (selection adds two mutant herbs to the run haul) or cistern-interface repair (selection adds four scrap). These are planned priorities, not completed facility repairs; supplies bank only after safe return. Both choices retain finite rationing and the same authored ending. |

The chapter 1B choice routes preserve their exposed-short versus covered-long
tradeoff and converge at a staging point on the existing northbound road, just
before the far-side gate. The authored return gate remains at `0.50, 0.07`;
the carry action ends at `0.50, 0.14`, so its completion is not an extraction.
In chapter 3B, the relay and defense remain at the south-entry connection point;
the separate north-side gate at `0.50, 0.06` is the only return. In both cases,
the player completes the trip by reaching that physical gate and pressing E.

For `ch2b_open_return_valve`, the selected option duration is resolved by the
shared `CampaignProgress.effective_duration()` helper for both the action timer
and the GameState completion check. The action's base duration remains 8 seconds,
the upper bound used when validating saved elapsed progress.

The three defend-action timer defaults are 18 seconds for `ch3b_defend_relay`,
24 seconds for `ch4b_hold_vent`, and 30 seconds for `ch6b_hold_supply`. The
timer pauses while threats are being cleared. These are initial design values,
not balance targets or gameplay-verified timings.

The first Scrap Highway outing now has bounded runtime acceptance, including
extraction persistence and its return debrief. Remaining action order, offer
copy, choice resolution, second outing and the ordinary full contract journey
still need review in the game. The six existing quest objectives, prerequisites and
reward quantities are unchanged; the first four story clues remain optional.
Existing active quests are not retroactively forced to perform the new outings.
Completing the two authored outings does not replace the contract's old
requirements or its single existing Guild hand-in/reward.

All 25 actions carry four presentation fields: `interaction_verb`,
`instruction`, `active_instruction` and `result_text`. The two carry actions
reference existing resource icons through `payload_item`: `broken_coil` for the
bypass coupling and `precision_chip` for the charged relay; these references do
not add rewards or persistent resources. NPC data contains 12 outing-gated lines
and six post-outing lines, resolved by `requires_campaign_outing` and
`requires_campaign_finished`. `GameState` refreshes active-step hints when an
action starts or reaches a checkpoint, not every frame. The J contract panel
and K codex can expand field notes that distinguish records awaiting this trip's
safe return from records already brought back.

The current field HUD reads `CampaignAction.presentation_state()` at four Hz,
showing the first ready/active action in the current outing. Waiting reasons and
counts remain visible together; the card hides under modals/transitions/death.
An escort's local label follows its actor. T uses the six actual main contracts,
routes, recipe and existing M/K panels instead of invented telemetry or lore.
The [historical action/terminal record](action-readability/README.md) has22
staged frames. The newer [UI label record](ui-label-composition/README.md) adds26
frames: world labels hide when they overlap viewport-space HUD controls or a
modal blocks them, while the action card retains progress. Full-map labels
prioritize the actual action/waypoint and exit, and use side-space callouts.
Radar minima now fit the allocated HUD area; the full map expands vertically.
These are native frozen displays, not actual action, hover or input acceptance.

The [onboarding continuation](onboarding-journey/README.md) aligns Main and H help
with those actual outings, original goals and one hub hand-in. M remains a map;
E at physical gates performs travel. J/K no longer double as combat defaults;
mouse/Space combat bindings remain. Help refreshes current journey and legacy
rules read-only: legacy-trip discoveries count immediately, whereas new unbanked
clues require extraction. An existing save requires confirmation before a new
journey resets memory; the intro-finish save point is unchanged. Pause displays
the existing IO calls' bool outcomes inline and keeps field snapshot/banking
distinct.24 staged images cover two sizes; actual input, confirmation and IO
branches remain unexercised. No schema, reward or settlement rule changed.
H help also participates in existing owned reading pause and dialogue/exit
handoff; it no longer merely locks input while enemy simulation continues.
Native frozen opening records the pause flag, not live combat/pause acceptance.

Live campaign actions now capture a transient generation plus run/quest/route/
outing owner. Loading an older snapshot of the same run ID also advances this
generation, so the exiting old actor cannot overwrite the candidate's progress.
Router flushes the source scene's pending action progress under cover before
normal scene identity changes or load apply/checkpoint. Failed-load rollback
restores the generation with the other live fields; the original actors remain
valid. Existing two-argument synchronous progress updates remain compatible.
No save field/action ID/reward or new persistence version was added.
Active escort bodies also participate in the existing architecture occlusion
fade; a foreground beam must not hide the mission target while the player stands
clear. This retains the current0.2-second sampling, alpha rule, paths and collision.

NPC actor dialogue has a transient owner in HUD, separate from shared reports.
E advances the current NPC, then closes its final page; a one-page dialogue also
closes with E. Esc, a different panel or a report resets only that speaker's
paging state. Player routes E only to the visible panel's exact NPC owner.
Reports/clues have no NPC paging owner and advertise reading/close controls.
Leaving an unrelated NPC cannot close the report or stop the current speaker's
voice. Generic three-argument dialogue requests and data-only NPC text helpers
remain available. Gifts, voices, positions and chapter copy retain their rules.
These continuity corrections are source-integrated; actual input, loaded-run
ownership, ordinary extraction/death and full campaign acceptance remain open.
See the [continuity record](story-seams/README.md) for bounded presentation.

`GameState.campaign_npc_record()` supplies the same returned-choice record to
the real `DialogueNpc._talk()` path and the alternate `talk_to_npc()` entry.
Dialogue signatures include that record so changed chapter context starts at
the first page. While an authored campaign is active, generic earlier-chapter
advice is skipped; an NPC without a matching outing/ready/discovery line gives
its neutral repeat line and the current journey hint. Old unmarked quests keep
their earlier dialogue selection rules. World action labels show compact
progress; long instructions stay in the HUD/J, and result prose stays in J/K.

After every authored outing and original quest objective is complete, the
existing Guild hand-in records the optional
`route_states[route].campaign_completed = questID` marker and persisted choices.
That marker lets completed-chapter field notes be reconstructed. A completed
legacy quest without the marker does not gain invented notes; an active quest
continues to show committed actions from `quest_progress.campaign.actions`.
Validation ties a marker to a completed quest on the same route and requires a
valid value for every authored choice. This is an optional extension to the v5
save shape; it adds neither a save-version bump nor an autoload.

The [historical guidance presentation record](journey-guidance/README.md) contains
26 staged PNGs, 13 each at 1280x720 and 1024x768, from two render processes that
exited 0. Its 112 listed source/mirror inputs match. It covers selected dialogue,
carry, field-note and notice states, not an actual player journey, choice,
handoff, extraction, save/load or balance result.

The first tutorial outing targets 6–8 minutes. A regular outing targets 12–18
minutes. These are editorial targets, not measured build behavior. Measure a
full route from departure through return before tuning them. Keep each route
bounded and readable: a direct path to its main action, a small number of
connected encounter spaces, at most a short optional branch, a breathing or
resupply beat, and a visible return approach. Do not add map acreage, repeated
backtracking or endless enemy refills to manufacture duration. Each outing has
one signature action and a small number of supporting combat/salvage beats.

## Expedition lifecycle

Each main's `campaign_completion_text` provides its authored return scene.
`GameState.has_completed_campaign()` requires both a completed quest ID and its
existing route completion marker; only then does that copy override the earlier
completion/discovery prose. K reuses the same read-only story in collapsed chapter
records, while unmarked legacy completions keep their earlier copy. NPC
`requires_campaign_completed` uses the same predicate. Twelve inter-chapter lines
for Alan, Ada and Mia additionally require no active contract, so they do not
displace current outing instructions. Existing final lines remain higher priority.
Their prose describes only the completed chapter; the shared NPC resolver appends
the actual `get_journey_hint()` so free-order completion cannot suggest a locked
City contract or a route already complete. NPC paging and story-record reading
have separate dialogue footers.

CampaignAction's transient wait reason is derived from the existing escort,
carry and defense branches. It replaces the compact status/progress line when
distance, enemies or wave placement prevent the next step. Clearing or changing
the branch clears stale text. It does not alter saved runtime, wave/timer rules,
enemy scans or rewards. These new reasons have source review only; actual waiting,
escort-site label visibility and wave recovery remain gameplay acceptance work.
No save field, quest/reward change, automatic discovery or new cinematic system
is introduced. The first four mains retain their existing free order; recollections
connect evidence without forcing another outing. Briefings and contract descriptions
for those chapters must not state another chapter's event as completed unless the
line is gated by its completion condition. Chapter 2's first pump-station briefing
uses order-neutral copy. Current goals remain in J.

Pending campaign choices and field drafts do not open while the router is pending.
The router emits `transition_finished(succeeded)` after releasing its pause and
publishing its result/warning. A successful destination HUD then restores the
story choice before the draft, acquiring its own pause. It does not consume a
pending option. The current notice timer pauses while a modal/curtain covers it;
closing the covering UI restores its remaining display time. This retains only
the existing latest notice, not a notification queue. Actual skip-input,
transition-error, save-error and load behavior still need gameplay acceptance.

SceneRouter's arrival title now combines the destination with the current outing
name (only on its matching route) and `GameState.get_journey_hint()`, also used by
HUD/J. Other trips retain their contract/free-salvage context; wrong routes get
the existing return-and-switch guidance. Village/Guild titles use the same next
step after settlement. This is read-only presentation, not a second quest-state
resolver. The native curtain remains skippable; its subtitle has a 112px wrapped
area at 18px font. Dwell is clamped to 0.65–3.0 seconds based on text length,
plus the existing 0.25s reveal/fade. HUD notifications and polled/unhandled
hotkeys defer while the router reports a pending transition. No new UI or save
state is added. [Arrival views](arrival-briefing/README.md) stage title composition;
skip input, timing feel, pause ownership and actual travel remain unexercised.

The latest return-feedback continuation uses the existing single
`ExpeditionLedger.last_result`; it adds no save field or growing history log.
`CampaignProgress.action_receipt()` lists only valid completed action IDs in the
recorded outing, including the selected option name. `return_report()` names the
first remaining step on a partial return, distinguishes no new complete steps,
and retains the next-outing/original-hand-in boundary after a complete return.
`GameState.expedition_result_text()` presents these receipts as brought back or
lost, alongside the haul and named side-contract field actions. K can expand the
last report. Its next-step prose is labeled as the state at that time; current
objectives remain in J. Reopening it performs no settlement, reward or save.

`quest_completion_report()` and `quest_completion_story()` build the hand-in and
ending copy without awarding anything. The ending and K premise preserve Alan's
saved choice about his own name. Liu Qing's name and other residents' names stay
in the restricted Guild copy because the current story records no independent
consent from them; public records retain affected districts, water lines and
household numbers. A legacy save without Alan's recorded choice gets neutral
archive prose, with no invented consent. The existing choice IDs remain stable;
an older `ch5b_publish_consent` choice now publishes Alan's name only.
The original hand-in checks, rewards and finite-water ending remain unchanged.
The hand-in now observes the autosave return value and shows the shared explicit
in-memory-only warning on failure. That failure was not reproduced through IO.
Report dialogue hints describe scrolling/closing/K rather than an NPC next page.

The [return/consequence presentation record](return-consequences/README.md) covers
selected staged receipt, journal and ending states. It exercises read-only text
builders and native UI presentation, not actual settlement, hand-in or save/load.

The current source implements the core run lifecycle below. Gameplay acceptance
is still pending; this table describes source behavior, not a completed
playthrough:

| State | Player-facing rule | What becomes permanent |
| --- | --- | --- |
| **Prepare** | Village or guild is the service hub for crafting, upgrades and perks. Equipment and quick slots can still be changed in the field. | Existing banked inventory, equipment, perks, XP/level and recorded discoveries remain saved. |
| **Enter** | The field run records a unique ID, route, active contract and its run state. A v5 save resumes that same active run rather than creating another. | No new haul or provisional mission result is committed just by entering. |
| **Field** | Fight, gather and perform registered field actions. Newly found items go into the active haul. Haul ammo is usable immediately and is spent before banked ammo. At the route's first two authored exploration sites, a run-local draft can add to existing effects. | Contract counters, field actions, ordinary field claims, and draft choices are provisional. XP/levels, lifetime enemy defeats and discovered lore are recorded independently. Draft behavior is source-integrated but not gameplay/save/balance accepted. |
| **Ready** | When required contract conditions are met, use a designated usable return gate. The player may leave earlier through a usable gate for a partial extraction. | Nothing is settled merely because the contract becomes ready. |
| **Extract** | Reach an authored return gate. SceneRouter completes the transition to the village before it asks GameState to settle the run; there is no pause-menu extraction. | Successful extraction banks the remaining haul and commits eligible counters, field actions and claims. Unmet requirements remain incomplete; the contract reward still requires the existing hand-in. |
| **Return** | Review the result, then use the village/guild contract flow when its requirements are met. | The active run is cleared before its result is published, preventing a repeated callback from settling the same run again. |
| **Death** | Death recovery returns R-17 to the village clinic and settles an active v5 run as lost. | The run haul and provisional counters, field actions and claims are discarded. Banked inventory/equipment, XP/levels, lifetime defeats and discovered lore remain. A lore discovery made during the lost run stays in the journal, but delivery credit requires a successful extraction on that original route. |

Each route authors its return-gate position at the far end of its terminal road.
The gate clearance and the player entry lane are reserved from generated
obstacles, resources and enemies. Early extraction remains an available player
choice, but the exit is no longer a few steps from the route spawn. This placement
is integrated in source; actual traversal, encounter pacing and the rendered
gate approach still require player acceptance.

An early retreat through a usable gate is a successful extraction with partial
results: it banks the remaining haul and already completed eligible steps/actions,
but it does not mark the contract complete or grant its completion reward when a
required condition remains. A field action must be complete before the player
leaves to be included in that extraction. Direct travel from the field to the
village/guild is blocked unless it is the return gate or death recovery.

Campaign outing actions follow the same extraction boundary. A successful
partial extraction preserves actions already completed, while a channel,
escort, defend or other action still in progress is not saved as a partial
timer; it must be started again in a later run. Death discards the current
unextracted haul and action progress, but never rolls back steps committed by an
earlier successful extraction. Once both outings and the existing contract
requirements are complete, the player uses the existing hand-in once to receive
the original contract reward. Choice item rewards enter the run haul and are
banked only if they remain at successful extraction.

Death before extraction ends the run. It discards that run's unbanked haul and
provisional counters, field actions and claims. Previously banked inventory,
equipment, permanent perks, XP/levels, lifetime enemy defeats and discovered
lore survive. A clue discovered during the lost run remains visible in the
journal, while its quest credit stays pending until a successful extraction on
the same route. Used ammo is not refunded; see the haul rules below.

On v5 save and reload, the active run keeps its run ID, route/quest, haul,
provisional state, source claims and generated resource/harvest positions. This
keeps the same run's recorded source layout and claim identities. The ledger is
cleared before settlement results are published. Story-boss source keys in the
factory and facility runs are also saved, so a defeated story boss is suppressed
when that same active run is resumed. Router and result-dialogue source now
surfaces an explicit warning when an automatic save fails; the failure path has
not been fault-reproduced in gameplay. The older v1-v4 in-field save
path is migrated as a legacy trip: its already-banked items and progress keep
the old immediate-save rules through its first return, and the legacy marker is
preserved by later v5 saves while the character remains in the field. A new
ledger run can begin after that return.

## Preparation, inventory and recovery rules

Prepare in Village/Guild: review J/T, equip banked gear in I, use C for
recipes, weapon ranks, ammunition and permanent chips. Materials are status
cards; gear uses equip buttons. Selecting a resource quick slot consumes nothing.
Shooting automatically spends usable ammo (haul first); Space remains melee
when ammo is empty. Field C is disabled and explicitly says to return to a hub.

No gameplay slot/weight/capacity limit exists. Catalogue stack values are
descriptive, not enforced maxima. Current persistence validates IDs/counts;
no overflow discard policy is introduced. Recycling duplicates keeps at least
one of each gear type. Existing recipes/rewards/compatibility remain unchanged.
Weapon-rank damage belongs to the weapon actually used, including Space/right-
click when another slot is selected. Existing equipped flat bonuses remain.
Permanent chip ranks and temporary draft levels retain separate ownership.

Tool scan marks at most6 nearest actual uncollected pickups/unharvested resource
nodes within520 world units for1.8 seconds. Claimed sources are excluded; empty
results say so. It uses a private0.7-second cooldown and existing0.20-second
interaction state, granting no loot/claim and spending no ammo. The player still
approaches pickups or presses E at resources. T opens existing route information;
no remote-control/decryption mechanic exists.

Death loss and HP/EP restoration still wait for successful clinic arrival. If
travel fails, Esc pause offers a guarded retry through the same router; pending
travel cannot be duplicated. This is source correction, not an exercised retry.
[Preparation presentation](preparation-journey/README.md) identifies34 frozen
native frames covering inventory, workshop, pinned navigation, staged recovery
and scan marks. Actual use/combat/settlement/IO/resize acceptance remains open.

The [load-consistency increment](load-consistency/README.md) now separates routed
request acceptance from eventual completion. Candidate state is applied silently
under cover before destination initialization; reported native scene-request
errors restore an exact transient-inclusive checkpoint and the original pause.
Main/pause remain available on failure. Data-only loading stays synchronous;
HP0/legacy normalization and existing autosave remain. Save-schema round trips
are not rollback. This is source integration plus eight synthetic UI frames;
real IO/error/migration acceptance is deferred. Destination `_ready` exceptions
have no separate recovery protocol and are outside this return-code boundary.

## Haul, contract progress and save compatibility

Active contract readiness and J/G objective presentation now share
`GameState.active_quest_requirements()`: the original collect/defeat/required
discovery predicates, optional field marker and authored-outing completion remain
the gates. Rows expose banked versus provisional quantities and separate optional
reading. J places the checklist and delivery button before the longer outing
details; its disabled button states why delivery is unavailable. G reuses those
rows when its displayed main contract is the active one, instead of omitting the
run haul/counters. Unaccepted/completed main cards retain their existing preview.
No quest amount, reward, save field, acceptance marker or delivery mutation changed.

After the final outing's actions are done, the shared journey hint prioritizes
missing mandatory goals and permits either finishing them before return or early
extraction. Once none remain it directs the player to return and hand in, without
inventing another outing. Hub guidance names the actual shortfall after both
outings are banked. Optional clues no longer displace missing required goals in
the next-step hint. The [contract presentation record](contract-readiness/README.md)
uses assigned states and does not prove hand-in, migration or a played campaign.

Keep banked inventory distinct from the expedition haul ledger. While a new v5
run is active, newly gathered items and salvage enter the run haul; successful
extraction banks what remains. Ammo from the haul can be spent during the run
before banked ammo is consumed. A projectile-pool refund restores the exact
portion of that shot, but ammo actually used from banked inventory is not
refunded when the run is lost. Existing equipment and inventory in a v1-v4 save
remain banked; if loaded while in the field, the legacy trip keeps immediate
banking until the first return. Hub-only services prevent field crafting,
disassembly, healing and permanent upgrades from converting or altering banked
stock mid-run.

Keep one active contract. Preserve the existing main quest IDs, side quest IDs,
reward quantities and completed state. The current bridge adds the authored
`highway_bypass_repair` action to the first main contract while keeping its
existing defeat and material requirements. The `field_objective_version` marker
distinguishes a new acceptance from an already-active legacy contract: an old
active first quest without the marker keeps its previous kill-and-material
completion rule and is not retroactively blocked by the repair action. Apply
the same compatibility discipline already used by the `drainage_rescue` and
`factory_sabotage` side contracts: older active saves without the marker keep
their original completion rules; new acceptances can require the added field
action. Field actions do not create a second reward path.

For every successfully extracted run, commit eligible counters, field actions,
claims and remaining haul once. A retreat cannot satisfy unfinished requirements
or pay a full contract reward. A death cannot commit provisional run state.
Discovered lore is stored separately from run claims so a found clue can remain
in the journal after death without granting its quest credit before extraction
on its original route.

The v5 source includes the ledger and migration behavior described above; do not
describe it as absent, and do not describe it as gameplay-verified. Current
source keeps active unmarked contracts under their prior objective rules.

## Temporary choices and permanent progression

Permanent equipment, levels, stats, weapon upgrades and existing perks remain
part of the saved character build and continue using their current village
menus. They are not removed or temporarily reset by an expedition.

The source now offers three readable temporary ability packages at the first
two authored exploration points on the selected route. At a newly unclaimed
site, the player clears its guards and collects its existing reward before the
draft offer appears. A site already claimed in an earlier run can offer a new
run's draft without repeating its reward. Each site permits one choice; the
same package can be selected again at the next site or a different package can
make a hybrid build. Each choice adds one level to both of its existing effects.
There is no new currency, mission gate, purchase or reroll. The offer shows the
benefit and tradeoff before selection. A draft is optional and is not required
for a contract objective.

Choices and a pending selection live in the active run ledger. Closing the UI
does not spend the pending choice. If another site is used while a choice is
pending, the earlier choice opens first and the new site's opportunity stays
available. The ledger saves the choice so reload does not apply it twice. The
temporary bonuses expire when the run is cleared by extraction or death and do
not change saved permanent perks. Existing permanent perk ranks are 0–3; the run
can add 0–2 levels, for an effective maximum of 5. A v1–v4 legacy field trip
keeps its old immediate-bank behavior and receives no drafts until it returns;
pre-draft v5 saves default their missing draft fields to empty.

The three provisional packages are:

| Temporary package | Existing effect patterns | Benefit | Cost or tradeoff |
| --- | --- | --- | --- |
| **Arc shooter** | `arc_overload` + `armor_piercer` | Favors ranged pressure against lined-up enemy groups. | Commits the draft to ranged effects; it gives no melee/evasion or pickup sustain benefit. Ammo and positioning still matter. |
| **Melee / evasion** | `vibro_rend` immediate bonus damage and knockback + `dodge_blast` | Supports a close strike followed by space-making and repositioning. | Requires entering melee range and timing the dodge; it gives no ranged armor-piercing benefit. |
| **Salvager** | `nano_salvage` pickup-triggered HP/EP + `scavenger_savant` field scrap-pickup bonus | Rewards routes with useful pickups and supports recovery through salvage. | Depends on field pickups and offers no direct damage package; the temporary Scavenger bonus applies to scrap pickups, not hub disassembly. The permanent Scavenger effect remains unchanged, and detours can cost time or expose R-17. |

These three packages are source-integrated, but their gameplay, save/reload and
balance behavior still needs acceptance. At the second site, the player may
repeat a package or add a second package for a hybrid run. Keep their effects
within the existing perk patterns; do not promise unimplemented bleed, critical-hit
or other catalog effects as part of these packages.

## Observable player acceptance targets

| Player story | Observable acceptance | Current status |
| --- | --- | --- |
| A new player wants a reason to leave and a visible result. | The first contract points from the rationed village supply to the highway repair; first-main completion changes the village to a small trickle, and the facility finale changes it to a finite stable supply. | The first contract's objectives, hand-in and save reload are verified. Inspect the resulting Village water presentation and verify the later Facility outcome in future journeys. |
| Alan wants the past named honestly. | Alan recognizes R-17 in the village opening, before the first outing, so the campaign does not rely on a delayed identity reveal. | Early-recognition source change is integrated this pass; runtime behavior is not verified. |
| A player wants to do the contract's field work. | A new marked first-contract acceptance requires `highway_bypass_repair`; the bus manifest remains optional lore and cannot block completion. | Verified in the first-contract 109/109 input journey; legacy active-save execution remains unverified. |
| A returning player wants the trip to matter. | A usable exit commits the remaining haul and eligible completed counters/actions; unmet requirements remain open and do not pay the contract reward. | Normal two-outing extraction, one-time hand-in and data-only post-hand-in reload are verified. Death loss, partial return and legacy settlement remain open. |
| A player with an older save wants the quest to remain valid. | An active first quest without `field_objective_version` keeps its former kill/material requirements and reward; active saves are not forced into the outing steps; v1-v4 field trips retain old banked-item rules through first return. | Compatibility is implemented in source; old-save runtime validation is pending. |
| A player wants to choose a temporary play style. | The first two authored exploration sites on the selected route each offer one of the three packages above, with benefit and tradeoff shown before selection; the same package may repeat or combine with another. | Draft offers and HUD choices are source-integrated. Gameplay, reload, extraction/death clearing and balance remain unverified; bounded ordinary presentation frames are documented separately. |
| A campaign finisher wants a clear ending. | The facility result provides the same authored ending and public account; the clinic/cistern choice records the intended support priority and adds two herbs or four scrap to the run haul, without completing a repair. | The choice is authored in source; gameplay consequences and the final journey are pending review. |
| A player wants a complete campaign without a dozen disconnected errands. | The six existing main quest IDs anchor twelve authored outings and 25 ordered actions; choices have legible local consequences and do not replace the old contract requirements or hand-in. | Outing data and runtime integration are in source; the ordinary full journey and save/death/extraction behavior remain pending review. |

## Story and persistent village state

The campaign is one authored story with persistent village and evidence
progress. The first four current discoveries remain optional where the current
quest data treats them as optional. Alan recognizes R-17 early; the story is
about the human consequences and the stale emergency closure, not a delayed
identity twist. Evidence should arrive through the outing's physical action;
the journal can keep optional concise context.

The authored water progression has visible stages: the village pump begins dry;
a small, tested trickle appears only at the first main-contract hand-in, after
both authored outings and the original objectives are complete; the final
facility hand-in establishes a finite, stable supply. Chapter 1A returns only
bypass readings and a limited test sample, and chapter 1B returns the coupling;
neither outing changes village water. Chapter 6A compares the sensor and flags
the missing review, while 6B performs the controlled bypass test; neither
outing return changes the village's water stage. The final chapter has one
authored ending. Optional local choices may affect a service, preparation or
NPC acknowledgment, while the same safe-water outcome and public account remain.
Do not promise branching endings or let one clue erase the consequences of the
old allocation.

The current source derives the visible water stages from the existing contract
layer: dry at the start, a small trickle after the `clear_scrap_route` hand-in,
and finite stable water after the `facility_memory` hand-in. The first contract
journey verifies normal outings, hand-in, saved completion and narrative return
copy; it does not directly inspect the resulting Village water sprite/state. The
Facility outcome and death/legacy transitions remain open. See
`STORY_AND_SCENES.md` for chapter actions and Traditional Chinese story copy.

## Detailed source contract and earlier QA snapshot

This section preserves the implementation and compatibility notes from an
earlier review. For current gameplay and QA evidence, use the acceptance table
and the current checkpoint at the top of this document; historical counts below
do not override that evidence.

The selected direction is a story-driven expedition roguelite with temporary
field abilities and persistent hub/story progress. The source baseline retains
village/Guild contract acceptance and hand-in, six main contracts, two side
contracts, six routes, saved inventory and equipment, journal discoveries,
permanent upgrades, and one authored ending. Existing contract kill/material
goals and rewards remain. The first-contract bridge adds `highway_bypass_repair`
using the existing objective/versioning contract and stages the village water
result; the authored outing sequence adds mission actions under the same six
quest anchors.

Current field-action compatibility is explicit: new first-main/side acceptances
can require their registered action, with `field_objective_version` in
`quest_progress`; an already-active save with no marker keeps its old
kill-and-material rule after load and is not forced to perform new outing steps.
Field actions do not create a second contract completion reward. The small
item rewards on outing choices enter the run haul and remain subject to the
normal extraction/death rules. Factory sabotage affects future normal-enemy
capacity; it does not despawn current enemies or change the Boss rule.

The v5 source now has a separate run-haul ledger, explicit return-gate
settlement, death-loss handling for provisional run state, v1-v4 legacy
load-path handling, hub-only services, and saved per-run source positions/claims.
These source changes are not gameplay, migration, save/load or QA acceptance.
Optional in-field drafts are source-integrated, but gameplay, save/load and
balance acceptance remain open. The twelve outings and 25 authored actions are
integrated with the source runtime, with ordinary action flow, reload, partial
extraction and death review still open. Alan's early-recognition and water-stage
source changes remain unverified in gameplay.

The latest isolated Godot 4.6.3 visual QA passed 27/27 launcher steps, 360/360
gameplay regressions, 66/66 captures and 218/218 visual checks; the automated
playtest reports 77/77 checks. The Guild flow covers board proximity/E-open,
keyboard accept/claim, one-time reward and completed-list focus scrolling at
800x600. It also sends E to the first contract field device after directly
positioning the test player, then verifies run recording and safe-return
settlement through the state API. Remaining kill/item goals are staged directly;
walking to the site, physical gate extraction, save-compatibility and a full
player playthrough remain unverified. QA used isolated save paths and did not
write the real save. A first-open J-layout fix was added after that QA snapshot
and has not been tested. The 6–8 and 12–18 minute targets remain unmeasured.

Current first-four contracts and their optional clues retain free order with a recommended next chapter. City and Facility retain prerequisites. The bridge does not impose new chapter gates on old saves. Permanent perk ranks and effects remain unchanged; temporary draft bonuses use the existing effect hooks. Gameplay and balance acceptance remain open.
