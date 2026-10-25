# R-17 blade production checkpoint

Updated 2026-10-24. The lead generated and reviewed v019, then registered one
blade-idle-only extra view at nominal11.25 degrees. Actual Player presentation
review is recorded in [intake-v019](facing-production/intake-v019/README.md).

## Current integration

`scenes/player/Player.gd` now loads `data/art/r17_presentation_v2.json` and the
optional `data/art/r17_weapon_families_v2.json` using the existing runtime PNG
loader. Blade idle, four walking keys, melee anticipation, hit, interaction and
swap use integrated body-and-sword images. Source grips are baked with the body;
the unrelated weapon icon overlay is hidden for these poses. Collision, movement,
damage, action timers, save state and the five autoloads keep their owners.

The approved native silhouette is `source/r17_blade_contact_a_v007.png` under
`assets/sprites/player/redesign_v2/`. Actual-size parent approval evidence:
`sprite_preview/contact_a_render.png` in this directory. Original generated RGBA
bytes are preserved. Native alpha clipping removes low-alpha background fringe;
later edited keys use the stricter 0.96 threshold. Nearest sampling preserves
pixel clusters. Per-view sole, hand and body-height registrations live in JSON.

## Honest production boundary

- **8 complete base facings; blade idle9, all other actions8.** The new idle-only
  registration adds1 to that action, not to complete family coverage. Blade idle
  needs23 more angles; the full action matrix still needs the24 intermediate
  angles plus missing action drawings. Shared `actual_facing_count` remains8.
  Full 32-facing coverage across the 11 canonical production actions remains
  incomplete.
- Four body gait keys: contact A, passing A, contact B, passing B. Contact B is a
  subtler weight/cape change; this is not 8-16 unique keys per action.
- Real integrated windup and saved impact keys exist (`windup_v014` and
  `impact_v015`). The strike has three unique keys: windup, impact and ready as
  recovery. Both strikes now use three explicit timings: 0.16s anticipation,
  0.12s impact and 0.14s recovery, matching the existing damage instant. Both
  action keys use ready's standing normalization height, preserving the crouch
  without enlarging the helmet/body. Both combo strokes share this sequence; a separately authored
  alternating backhand remains open.
- Firearm and heavy are enabled in the separate family manifest. Their actual
  Player idle/fire and idle/strike sheets were inspected and approved. See
  `weapon_families.md` for exact active sources and incomplete actions.
- Rifle now walks through three unique keys over four slots:
  `passing,ready,passing,contact_b`. Heavy uses `ready,passing`, two unique keys;
  its attempted opposite-contact sources were rejected and archived. Actual
  Player walk sheets (`sprite_preview/player_v2_rifle_walk_keys.png` and
  `player_v2_heavy_walk_keys.png`) were rendered and inspected with stable
  torso roots/scale/grips. Four displayed stride phases do not imply four drawings.
- Existing legacy death art remains. No completion or runtime pass is claimed.
- The existing Player was rendered in an isolated ordinary art copy using Godot
  `4.6.3.stable.official.7d41c59c4`, Compatibility renderer, 1280x720, exit 0 with
  no logged errors. `sprite_preview/player_v2_idle.png`,
  `player_v2_walk_keys.png` and `player_v2_strike_keys.png` were directly inspected
  and parent-approved as the first integrated blade production batch. This is
  art playback evidence, not an automated regression or gameplay result.
- Revised blade standing-scale/timing sheets were rendered and inspected under
  `sprite_preview/blade_standing_scale/`, exit 0 with no logged errors. These
  supersede the earlier strike sheet for current action proportions.
- No automated QA/test runner was executed at this art checkpoint. Gameplay and
  full campaign validation were deferred under the explicit no-test request then
  in force. The current full-production objective now requires relevant isolated
  QA; this historical deferral is not a current testing restriction.

## Next work

Current production/review owner: **Codex lead with GPT-6-Luna/xhigh workers**.
The lead used built-in `imagegen`, retained raw RGBA and rejected v018 for
insufficient perspective change. v019 is visually distinct between E0 and the
inactive v017 reference. The lead reviewed its288px/96px native comparison and
registered only blade idle, with sole/grip/body height. Exact azimuth is not
mathematically certified. Preserve this partial coverage when producing the
remaining angles; do not extend the other actions with repeated idle drawings.

Historical provenance: on 2026-10-24, Gemini 3.8 Flash medium authored the
portable builder and prompt package retained in
[`facing-production/README.md`](facing-production/README.md). That Antigravity
CLI context did not confirm a raster-generation tool and produced no candidate
image; this was a limitation of that historical CLI run, not a statement about
current image-generation availability. The request package records 24 missing
blade-idle facings and remains useful input for candidate production.

The visually intermediate E22.5 v017 remains an identity/perspective reference
only; it is not active, registered for every action, or proof of exact azimuth.
See `angular_e22_5_checkpoint.md`. Never rotate or mirror flat sprites and label
those as additional camera views. The heavy opposite contact, second
independent rifle passing key, full rifle/heavy actions, death, and the remaining
11-action matrix stay open until actually authored, reviewed, and registered.

## Portable source contract

Each enabled family has `facing_angles`, `keys` and `actions`. A key contains a
source PNG `path` plus one `cells` entry per facing. Each cell is
`[x,y,width,height,soleX,soleY,handX,handY,bodyHeight,muzzleX?,muzzleY?]`.
All anchors are absolute source-image pixels. Body height excludes a raised
weapon. Action crouches reuse their standing reference's normalization divisor,
rather than scaling their shorter bounding boxes back to standing height.
Runtime standing body height is 96 pixels; offset is crop center minus sole.
Actions list key IDs in playback order. Walk advances by existing travel phase;
timed actions follow the existing action duration. Legacy fallback is retained
when the family/action or its complete source registration is unavailable.

Optional `additional_action_facings[action]` entries keep the complete base
arrays intact. Each enabled entry declares a unique finite angle in[0,360) and
`frames` equal in count to that action's sequence slots; each frame supplies its
own path/cell. Invalid extras are skipped independently. Player caches merged
action angles once at load and shares their indexing with animation and pose
lookup. Shooting extras should register muzzle anchors. v019 is idle-only.

## Source retention and cleanup candidates

Active blade sources: `r17_blade_contact_a_v007.png`,
`r17_blade_contact_b_v008.png`, `r17_blade_passing_a_v009.png`,
`r17_blade_passing_b_v010.png`, `r17_blade_idle_v011.png`,
`r17_blade_windup_v014.png`, `r17_blade_impact_v015.png` under
`assets/sprites/player/redesign_v2/source/`. Keep all seven source PNGs and JSON.

`r17_combined_pose_design_v002.png` is approved proportions/grip concept only;
its background is rejected and it is not a runtime sprite. Other combined v001
and v003 sheets and crowded `r17_blade_windup_v012.png` /
`r17_blade_impact_v013.png` were externally archived and individually removed.
See `../../ASSET_CLEANUP_REPORT.md` for the backup boundary.

The standalone `sprite_preview/project.godot` is a source-only art-sheet viewer.
Actual Player playback uses `sprite_preview/actual_player_preview.tscn` from an
isolated full-project copy at
`C:/Users/wuwu6/AppData/Local/Temp/first-game-art-preview/r17_v2_current`, with
custom user directory `R17-Ordinary-Art-Preview-20261023`. It never calls save.
The viewer now requires that custom-directory setting and an absolute output
argument, so another platform does not need the original machine's path:

```text
<godot> --path <isolated-project-copy> --rendering-method gl_compatibility --audio-driver Dummy --resolution 1280x720 res://docs/art-direction/r17_v2/sprite_preview/actual_player_preview.tscn -- --family heavy --art-output=<absolute-output-directory>
```

Use `--family rifle`, `--family heavy` or omit it for blade. Add `--live` after
`--` for idle/walk/strike playback; Escape quits. The main game's real
`user://save_game.json` was not opened or modified by these ordinary previews.
