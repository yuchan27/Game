# Pixel world and R-17 redesign — approval plan

Status: production remains authorized and in progress; art and release acceptance
remain open. See [the current production ledger](PRODUCTION_STATUS.md) and
[release evidence boundary](RELEASE_READINESS.md) for the live project state.
Follow the repository-root [AGENTS.md](../AGENTS.md) for current user and
delegated-agent policy. Preserve the existing Godot project and original assets.

## Acceptance target

Use Path of Exile's readable dark-fantasy environments, encounter rhythm and
equipment identity as quality references. Preserve original Wasteland Recycler
fiction and mandatory pixel art. Build and approve one representative playable
slice as an integration acceptance gate within the full six-region target. It
does not replace or reduce that scope or suspend ongoing authorized art work
while QA is deferred.

Interpret "32 actions (angles)" as **32 facings at 11.25-degree intervals**.
Facing, action, source keyframe count and rendered FPS are separate contracts.
Sixty FPS remains a measured runtime target, not a count of generated stills.

## First review package

1. One world-composition plate and six region composition boards.
2. Six navigable region plans marking roads, alternate loops, combat arenas,
   evidence sites, landmarks, return routes and collision envelopes.
3. One R-17 body/weapon scale sheet at actual gameplay size and enlarged pixels.
4. One 32-facing idle/contact sheet with consistent pixel density, handedness,
   body height, ground plane and grip/muzzle anchors.
5. Three motion proofs: blade walk/strike, rifle strafe/fire and heavy strike.
   Each must include real-time playback and frame contact sheets.
6. A manifest listing native sizes, pivots, source provenance, action timings,
   collision dimensions and accepted/rejected artifacts.

## Character production contract

Pilot target: 96-pixel visible body on a 192-square action canvas; confirm at
1280x720 and 1024x768 before locking these proposed dimensions. Weapon length is
specified relative to body height per archetype. Shared pixel cluster scale,
outline, lighting and perspective are mandatory.

Design body, hands and weapon together for every key pose. If exported as layers,
they share the same canvas and registered pivots; equipment must not be attached
by arbitrary scaling/rotation of unrelated icon art. Use a deterministic pose
pipeline and inspect intermediate views. Generated concept illustrations are
references, not automatically approved production animation.

Planned core actions: idle, walk, run, dodge, aim/fire, light strike, heavy strike,
weapon swap, hit, death and interaction. Reload is conditional on an explicitly
implemented ammunition rule; do not add a misleading cosmetic reload mechanic.
Plan 8–16 meaningful source keys per action, with action-specific timing and
continuous rendered movement. Three loadout families: blade, firearm and heavy.
At 11 actions × 32 facings × 12 average keys, one complete family is roughly
4,224 frame placements. Shared bodies/layers reduce unique drawing work but do
not remove the review burden. Approve representative directions/actions first.

## Region identity and playable composition

| Region | Spatial identity | Gameplay composition |
| --- | --- | --- |
| Scrap highway | Broken flyovers, overturned evacuation convoy, branching service roads | Long sightlines, vehicle cover, loops back to the main road |
| Toxic marsh | Flooded foundations, raised timber/metal crossings, pump islands | Choke points, safe islands, visible hazardous ground |
| Crystal scar | Fractured canyon, stepped crystal terraces, buried acoustic machinery | Alternating broad arenas and narrow crossings; clear traversable edges |
| Old factory | Furnace courts, pipe corridors, production halls | Close combat rooms, flanking loops, readable industrial hazards |
| Ruined metropolis | Broken cathedral/plaza silhouette, collapsed blocks, evacuation archive | Landmark-led streets, optional interiors and reconnection paths |
| Underground facility | Concentric reactor halls, sealed labs, water-treatment spine | Layered visual depth, connected chambers and a distinct finale arena |

Each region needs a unique silhouette, architecture kit, ground language,
lighting accents and encounter rhythm. Color changes and scattered props alone
do not satisfy diversity. Decorative height must not misrepresent walkability.

## Bounded implementation sequence

This sequence organizes production and acceptance; it does not suspend
user-authorized art production while QA is deferred. Keep source integration,
visual/art acceptance, gameplay QA and collision acceptance, performance
acceptance, and release evidence separate. Gameplay and performance checks stay
open until authorized and run; their deferral is not a reason to pause art work.

1. Character and world art direction: produce the first review package above.
2. One finished slice: village edge → rebuilt highway → optional guarded event
   → narrative discovery → elite encounter → return/reward/save. Include UI and
   entrance sequence. Collision and performance remain separate acceptance
   checks for later authorized verification.
3. Character production: approve blade/firearm/heavy motion, then complete the
   32-facing action matrix in reviewed batches. Do not mass-generate unreviewed
   sheets or overwrite existing validated sources.
4. Six-region integration and acceptance: maintain approved modular kits across
   all six routes, preserving old saves, evidence IDs and quest prerequisites.
   Source expansion already spans six routes; full composition acceptance remains
   open in the production ledger.
5. Release verification: integrated QA, rendered inspection, controlled timing,
   human pacing assessment and standalone export/runtime checks.

## Review gates and agent ownership

- Parent: scope, art/animation specifications, integration decisions and final
  approval. Do not equate a passing test report with acceptable art quality.
- Character production: character source/layer assets and action data.
- World production: region layouts, modular kits and route composition.
- Implementation: Player, combat, collision, UI and scene integration.
- Verification: regressions, visual captures, frame-time comparisons and failure
  reports, when those checks are authorized. Follow root `AGENTS.md` for the
  current delegated-agent model and reasoning policy; avoid overlapping ownership.

Art acceptance requires readable actual-size silhouettes, weapons that meet the
hands through an action, stable adjacent facings, and VFX aligned to impact or
muzzle timing. Gameplay acceptance separately requires clear collision paths.
Performance acceptance separately requires equivalent stress samples that
support the target frame budget. Record rejected examples and reasons; source
integration, art review, gameplay evidence and performance measurements do not
substitute for one another.

## Current implementation boundary

The current ledger records expanded source across all six routes, while
whole-world visual composition, traversal and player acceptance remain open.
Eight actual character facings are active; the 32-facing target and complete
11-action matrix remain outstanding. QA suites are explicitly deferred and no
fresh integrated QA result is claimed. These acceptance gaps do not pause the
authorized art-production work.

The `20261022T155341Z-019421f6` result (29 of 31 launcher gates, including the
then-failing `exploration_crystal_walkup_is_reachable` visual stage) is a
historical run tied to its older source snapshot; it is not the current project
status or fresh validation. Current implementation, art-review limits and the
explicit QA deferral are recorded in [PRODUCTION_STATUS.md](PRODUCTION_STATUS.md)
and [RELEASE_READINESS.md](RELEASE_READINESS.md). Do not infer a current pass or
failure from that older run, and do not require deferred QA before continuing
authorized art production.

## 繁體中文摘要

先交付世界主視覺、六區可行走藍圖、主角武器比例規格、32 朝向圖與三組動作樣片。
武器和身體必須一起設計，地圖必須有不同建築輪廓、道路結構與戰鬥節奏。
先驗收一段完整可玩的廢鐵公路，再完成全部六區與角色動作；像素風格與原存檔相容性
都屬於硬性要求。子代理分工與模型政策依根目錄 AGENTS.md；主代理負責規劃、整合與審批。
