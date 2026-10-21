# Project audit — Wasteland Recycler

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
| A04 | P2 | `GameState.gd:323-350,377-398` | Shared kill counters survive quest completion and count wrong-route kills. Reset on acceptance, reject replacement, route-scope objective updates. |
| A05 | P2 | `quests.json:56-74`; `Enemy.gd:134`; `Wasteland.gd:288` | Factory core contract can complete without Boss defeat. Add an explicit Boss objective using the existing counter mechanism. |
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
