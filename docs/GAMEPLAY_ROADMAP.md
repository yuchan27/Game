# Gameplay improvement roadmap

Canonical priorities derived from `PROJECT_AUDIT.md`, 2026-10-21. Keep the
current world/R-17 identity and existing modular data-driven scenes.

| Priority | Work | Acceptance |
| --- | --- | --- |
| P1 / current | Isolate QA writes; restore saved coordinates; validate save schema; repair audio import | Tests cannot change player save; manual restore and transition entrypoints both work; corrupt input leaves state intact; clean import has no errors. |
| P2 / current | Per-contract/route progress and real factory Boss objective | Previous/wrong-route kills do not count; one active contract; rewards once; all six contracts can progress and reload. |
| P2 / current | Single interaction target; HUD/map/menu fixes | One E selects one target; load failure retains menu; map markers stay in bounds; inventory/dialogue/pause can be used by keyboard/mouse. |
| P2 / current | Align current art contracts and strengthen runners | No approved art regeneration; atlas/reference validation; rendered interface/route captures; representative performance evidence. |
| P2 / next | Player-balance playthrough of all six contracts | Human keyboard/mouse route timings, ammo/EP economy, enemy pressure, Boss telegraphs and return/reward flow recorded at target PC settings. Adjust JSON only from evidence. |
| P2 / next | Release packaging | Correct-version export templates installed, Windows debug/release export and packaged launch/save/load/audio smoke; document platform prerequisites. |
| P3 / decision | Resource stack/capacity rules | Decide overflow/pickup/crafting/reward behavior before implementing declared stack limits. Preserve old quantities or define migration. |
| P3 / decision | Route reset/persistence rules | Decide what resets on re-entry/death/load, then use or remove unused route_states with explicit compatibility. |
| P3 / next | Route difficulty/reward differentiation and semantic event objectives | Characterize existing four themes first; add rescue/sabotage objectives only with playable event interaction, guidance and regression tests. |
| P3 / evidence-led | Large-script decomposition / optimization | Only extract repeated or costly code with caller/scene characterization and comparable measurements. No whole-game rewrite. |

The current rescue/sabotage contracts are combat/resource contracts with story
framing, not fully separate rescue/destructible event mechanics. No completion
claim is made for those future mechanics. Exact implemented dispositions and
remaining release limitations are recorded in `RELEASE_READINESS.md`.
