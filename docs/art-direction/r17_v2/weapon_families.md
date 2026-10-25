# R-17 firearm and heavy family production checkpoint

Updated: 2026-10-23 Asia/Taipei. Production is authorized; no tests, QA runners,
commit or push are authorized in this pass. Ordinary isolated art rendering is
allowed. Preserve all unrelated dirty work and all original PNG bytes.

## Ownership and active boundary

The held-weapon producer owns `assets/sprites/player/redesign_v2/firearm/`,
`assets/sprites/player/redesign_v2/heavy/`, this document, and optional
`data/art/r17_weapon_families_v2.json`. The character integration producer owns
Player and its runtime config. Do not edit Player or that producer's config.

Rifle and heavy are parent approved as bounded eight-facing art and published in
`data/art/r17_weapon_families_v2.json`. The current Player reads this manifest,
selects the family from equipped attack mode/item, and disables legacy weapon
overlays for its baked poses. Parent approved the actual Player rifle idle/walk/fire
and heavy idle/walk/strike-key production captures listed below. This is bounded
art-integration acceptance; gameplay validation remains deferred. Never substitute an
inventory icon or independently scaled/rotated weapon for an integrated held
body+weapon pose. The approved body identity is the slim blue-gray steel R-17,
gold cross greathelm, narrow gold armor edging, brown belt and torn crimson cape.

## Approved visual reference

- Source: `assets/sprites/player/redesign_v2/source/r17_blade_contact_a_v007.png`.
- Accepted native 96-pixel and 2x view:
  `docs/art-direction/r17_v2/sprite_preview/contact_a_render.png`.
- Required direction order: E, SE, S, SW, W, NW, N, NE.
- Source layout target: 1536x1024, four columns by two rows. Each body and held
  weapon must be composed together with matching pixel density and lighting.
- Rifle accepted stock-to-muzzle length: approximately 0.50 body height. Parent
  approved the v002 native render as a compact pipe-rifle/carbine; the earlier
  0.65-0.75 proposal is not a hard gate and must not trigger enlargement.
- Heavy hammer physical length target: 0.65-0.90 body height, two-hand grip.

## Firearm artifacts and review state

| Artifact | Status | Reason / next action |
| --- | --- | --- |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_ready_v001.png` | Rejected | Front/back rifles remain lateral instead of axial foreshortening. Never activate. Archive/removal disposition belongs in the cleanup ledger. |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_ready_v002.png` | Parent approved for integration | Compact carbine about 0.50 body height reads coherent at96px. Correct eight aim directions, stock/shoulder and both-hand grip. Do not enlarge it. |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_fire_v001.png` | Rejected, superseded | First muzzle flash overhangs the crop gutter. Corrected no-flash v002 is accepted; runtime draws native muzzle flash from anchors. Never activate v001. |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_fire_v002.png` | Parent approved for integration | Corrected no-flash recoil key, coherent grips/feet/cape and S/N axial aim. The active key and native continuous recoil supply movement; do not claim many unique authored frames. |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_passing_v001.png` | Parent approved; active walk key | Narrow passing stance, explicit eight-view roots/grips/muzzles; accepted in actual Player walk capture. |
| `assets/sprites/player/redesign_v2/firearm/r17_firearm_contact_b_v002.png` | Parent approved; active walk key | Opposite contact after the bounded correction; accepted with ready/passing in actual Player walk capture. |
| `assets/sprites/player/redesign_v2/firearm/preview/ready_v002_native.png` | Review image only | Ordinary isolated Godot render, alpha scissor 0.65, actual 96px body plus 2x views. First small east sprite's cape reaches preview margin; source is complete. |
| `assets/sprites/player/redesign_v2/firearm/preview/ready_v002_measurements.json` | Source measurement metadata | Rects, sole anchors, solid silhouette bounds, individual body heights, scale and SHA-256. This is measurement, not a test result. |
| `assets/sprites/player/redesign_v2/firearm/prompt_ready_v001.txt` | Provenance | Exact built-in imagegen prompt; reference was approved blade v007. |
| `assets/sprites/player/redesign_v2/firearm/prompt_ready_v002.txt` | Provenance | Exact corrective imagegen prompt; reference was firearm v001. |

The ready v002 source SHA-256 is
`b94f3219e3fa06b7dba258d2a0f2dbafd0349a6b8671f43456f05fab2b13fd0d`.
The accepted fire v002 SHA-256 is
`36083a76f30837ace3af28e7df4b0833bef55658a775109d158df997547c5a98`.
Accepted source PNGs above are copied into the workspace. Built-in originals
also remain in `C:/Users/wuwu6/.codex/generated_images/01a16479-e9c1-7142-92a1-57f80d7301f6/`:
v001 `exec-c0fc1266-fceb-44c5-b34b-4b93ce05fdfd.png`,
v002 `exec-3f99cc59-242c-4f0a-b54a-a6b86ba1bac9.png`.

Rifle walk now uses the active manifest sequence
`passing -> ready -> passing -> contact_b`: four phase slots with three unique
authored gait keys per facing. Passing is reused in two slots; this does not
create a fourth authored pose. Parent inspected and accepted the actual Player
rifle walk capture listed below. Rifle still has eight actual facings and a
bounded set of gait/fire keys, not the complete 32-facing action matrix.

## Runtime data contract agreed with character integration producer

Use a private family dictionary or `data/art/r17_weapon_families_v2.json` with:

```json
{
  "families": {
    "rifle": {
      "enabled": true,
      "facing_angles": [0,45,90,135,180,225,270,315],
      "keys": {
        "ready": {
          "path": "res://assets/sprites/player/redesign_v2/firearm/r17_firearm_ready_v002.png",
          "source_sha256": "EXACT_SOURCE_SHA256",
          "cells": [[0,0,410,512,257.81,462,260,214,337,385,194]]
        }
      },
      "actions": {
        "idle": ["ready"],"walk": ["passing","ready","passing","contact_b"],
        "shoot": ["fire","ready"],"hit": ["ready"],
        "interact": ["ready"],"swap_tool": ["ready"]
      }
    }
  }
}
```

The example shows the contract, not a complete family; all referenced keys must
be supplied as in the active manifest. Use the full eight cells in the final JSON.
Each final key needs exactly eight cells in E,SE,S,SW,W,NW,N,NE
order. Cell values are absolute sheet coordinates:
`[x,y,w,h,sole_x,sole_y,hand_x,hand_y,body_height,muzzle_x,muzzle_y]`; muzzle fields
may be omitted only if the runtime owner explicitly handles that case.
Normalize each facing using `96 / cells[i][8]`; compute region offset as
`region_center - sole`, and hand/muzzle offset as absolute anchor minus sole.
Preserve per-key soles; generated body heights vary and must not use one shared
310px divisor. Baked families disable legacy weapon overlays. The Player accepts
nine-value cells for heavy because its muzzle is unused; rifle keeps all eleven.

For firearm v002 only, custom x bounds `[0,410,800,1160,1536]` and row height 512 retain
cape/muzzle pixels beyond nominal 384px cells. The silhouettes do not overlap.
Do not blindly crop this source into 384px columns. Final approved sources may
need their own explicit rectangles.

## Heavy artifacts and review state

Parent inspected and accepted all three native previews on 2026-10-23 for
silhouette, two-hand grip and body identity at the bounded eight-facing scope.
Original source PNG bytes remain unchanged.

| Artifact | Status | Reason / integration boundary |
| --- | --- | --- |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_ready_v001.png` | Rejected | True North leaves a free hand; never activate. Archive/removal disposition belongs in the cleanup ledger. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_ready_v002.png` | Parent approved; enabled in family manifest | Corrected rear grip, eight distinct ready views. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_windup_v001.png` | Parent approved; enabled in family manifest | Eight overhead anticipation poses with both hands meeting the shaft. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_impact_v001.png` | Rejected, superseded | Impact silhouettes crowd/cross the crop gutters; v002 repacks the complete figures. Never activate v001. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_impact_v002.png` | Parent approved; enabled in family manifest | Eight lowered strike poses, including frontal/back foreshortening and retained crouch. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_passing_v001.png` | Parent accepted native and actual Player walk; enabled | Eight narrower passing poses with changed knees/boot spacing; bounded two-key walk with ready. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_contact_b_v001.png` | Rejected; not referenced by manifest | Repeats ready's leading foot instead of providing opposite contact. |
| `assets/sprites/player/redesign_v2/heavy/r17_heavy_contact_b_v002.png` | Rejected after one targeted correction; not referenced by manifest | Some poses change, but E/W still repeat the same lead foot; crowded cape gutter also prevents acceptance as a full opposite-contact sheet. No further generation in this slice. |
| `assets/sprites/player/redesign_v2/heavy/preview/ready_v002_native.png` | Accepted review image | Native 96px standing reference and 2x view. |
| `assets/sprites/player/redesign_v2/heavy/preview/windup_v001_native.png` | Accepted review image | Native standing-reference scale; raised hammer may extend above 96px body. |
| `assets/sprites/player/redesign_v2/heavy/preview/impact_v002_native.png` | Accepted review image | Same standing-reference scale; the crouched body deliberately occupies less than 96px. |
| `assets/sprites/player/redesign_v2/heavy/preview/passing_v001_native.png` | Parent accepted review image | Actual 96px body plus 2x views; rendered in the separate heavy preview project. |
| `assets/sprites/player/redesign_v2/heavy/preview/contact_b_v002_native.png` | Rejected review image | Documents the failed opposite-contact correction; not active game art. |
| `assets/sprites/player/redesign_v2/heavy/preview/*_measurements.json` | Source measurement metadata | Each key's actual crop, solid bounds, sole and normalization divisor. Metadata is not a test result. |
| `assets/sprites/player/redesign_v2/heavy/prompt_*.txt` | Provenance | Exact built-in imagegen requests retained for accepted and rejected sources. |

Accepted SHA-256 values:

- Ready v002: `5d1894496ccabebb9065f7baf9ad29d149a97396748b95a977e6528bccf8535e`.
- Windup v001: `2a7baa99a7e2c75b3bc18aeef7e27c879a5e819cc1915f94aacd1717f606adc6`.
- Impact v002: `1e791e0318a591bbd4cf094d2c74df29dedab7287a124efa1bb98f1411b3c573`.
- Passing v001: `5a2094209991afe346b8799e060094d4da128182929a5abcffbebbf5335ed6bf` (parent native and actual Player walk acceptance).

Heavy's three strike/guard keys and passing each have eight explicit
crop/sole/primary-grip registrations.
Some rear grips are partly cape-occluded; their anchors use the visible/projected
shaft contact. These are hand anchors for the existing Player attack origin,
not independently movable hammer layers. Muzzle fields are omitted because the
loader handles their absence and the heavy family does not fire projectiles.

Standing ready normalization heights in E,SE,S,SW,W,NW,N,NE order are
`[360,366,372,364,366,379,385,384]`. Both strike keys reuse those per-facing
divisors. Windup solid bounds include the raised hammer, and impact solid bounds
are shortened by the crouch: neither is a valid substitute for standing body
height. Per-key soles still follow the actual feet, so pose changes remain
grounded. The native source measurement files already use these standing
divisors, even where their historical field is named `helmet_to_sole_height`.

`slash` and alternating `draw_sword` both play `windup -> impact -> ready` with
durations `[0.16,0.12,0.14]` seconds. This matches the current Player's
`MELEE_WINDUP = 0.16` and 0.42-second presentation; it does not change weapon
cooldown/damage data. Idle/hit/interaction/swap currently reuse ready;
native motion supplies bob/strike movement. Heavy has four authored keys per
facing, including the passing gait below, not a complete walk cycle or separate
second-combo artwork. Death keeps
the existing fallback. Thirty-two real facings and the full action matrix
remain incomplete.

## Bounded heavy gait production

The accepted ready pose supplies the broad contact stance. New passing v001
narrows the feet, plants the support leg under the hips and bends the advancing
leg past it, while keeping the same low maul guard and two-hand shaft grip.
`walk` now alternates `ready -> passing` using the existing distance-driven walk
phase. These are two authored keys per facing, not a full left/right gait.

Passing standing anatomical heights are
`[393,398,398,397,393,396,402,397]` in E,SE,S,SW,W,NW,N,NE order. Because this
sheet remains upright and the guarded hammer stays below the helmet and above
the feet, these are helmet-to-planted-sole body measurements. They normalize
the new sheet's changed source pixel size to a 96px body. They are not derived
from a raised weapon or crouched action. The older accepted guard/strike keys,
their crops/soles/grips and both strike timings were left unchanged.

Passing runtime ground y follows the measured planted sole. Runtime ground x
preserves ready's torso/belt projection after scaling rather than selecting
whichever boot is lowest. Consequently its manifest `sole_x` may differ from
the source measurement's visible-foot center; it is the horizontal ground-root
registration used by the loader. This prevents a leading-foot change from
moving the whole torso sideways. Measurements retain the original foot center
and separately record `runtime_ground_root`, hand and torso-registration notes.

Two opposite-contact attempts were produced with built-in imagegen. Version
001 repeated ready's leading legs; one targeted legs-only v002 correction still
failed to swap them consistently. Both remain outside the active manifest.
The generation ceiling was reached for this slice; no procedural repaint,
mirrored pose or additional generation was used to hide the incomplete cycle.
Prompts are `heavy/prompt_passing_v001.txt`, `heavy/prompt_contact_b_v001.txt`
and `heavy/prompt_contact_b_v002.txt` relative to the character asset directory.
Generated source PNG bytes were copied unchanged into versioned workspace files.

Passing and corrected contact B were each rendered at actual 96px plus 2x in
the independent `heavy/preview/` Godot project, without game autoloads or save
access. Both ordinary renders exited 0 on Godot 4.6.3 Compatibility/OpenGL;
their logs are `passing_v001_render.log` and `contact_b_v002_render.log` in that
directory. Parent native preview inspection accepted passing; contact B was rejected.
Parent subsequently inspected four phases in the actual Player walk capture
and accepted stable horizontal roots, coherent body scale and grip for this
bounded two-key integration. Opposite contact remains unmet. No test or QA
runner was executed.

The five rejected source/review artifacts from this gait slice are
`assets/sprites/player/redesign_v2/heavy/r17_heavy_contact_b_v001.png`,
`assets/sprites/player/redesign_v2/heavy/r17_heavy_contact_b_v002.png`, and the
`heavy/preview/contact_b_v002_native.png`, `contact_b_v002_measurements.json`
and `contact_b_v002_render.log` review artifacts. Physical archive/removal status
belongs in `docs/ASSET_CLEANUP_REPORT.md`; this document does not infer it from
rejection or repeat a pending cleanup instruction. This producer removed nothing.
Keep their small prompt files for provenance. Historical rejected guard/fire/
impact sources were externally archived and individually removed by the parent;
exact disposition belongs in `docs/ASSET_CLEANUP_REPORT.md`.

## Accepted actual Player production captures

Parent rendered these through the current Player and family loader in an
isolated Godot 4.6.3 project, then inspected and accepted their bounded art
integration on 2026-10-23:

- Rifle ready/idle: `docs/art-direction/r17_v2/sprite_preview/player_v2_rifle_idle.png`.
- Rifle fire/ready keys: `docs/art-direction/r17_v2/sprite_preview/player_v2_rifle_fire_keys.png`.
- Rifle walk keys: `docs/art-direction/r17_v2/sprite_preview/player_v2_rifle_walk_keys.png`.
- Rifle gait rendering log: `docs/art-direction/r17_v2/sprite_preview/rifle_gait_render.log`.
- Heavy ready/idle: `docs/art-direction/r17_v2/sprite_preview/player_v2_heavy_idle.png`.
- Heavy windup/impact/ready keys: `docs/art-direction/r17_v2/sprite_preview/player_v2_heavy_strike_keys.png`.
- Heavy walk keys: `docs/art-direction/r17_v2/sprite_preview/player_v2_heavy_walk_keys.png`.
- Heavy gait rendering log: `docs/art-direction/r17_v2/sprite_preview/heavy_gait_render.log`.
- Heavy rendering log: `docs/art-direction/r17_v2/sprite_preview/heavy_render.log`.

The parent reported both ordinary gait renders exited 0 without errors; their
logs record the actual Player capture paths and Godot 4.6.3 Compatibility/OpenGL.
Parent accepted the rifle's three unique gait keys and heavy's two unique gait
keys at the captured phase boundaries; heavy keeps stable roots/body/grips while
its opposite-contact key remains unimplemented. These
captures demonstrate the actual Player's family presentation for the pictured
poses. They do not establish combat/gameplay acceptance, a complete walk cycle,
32 facings, tests or QA results. Game validation remains deferred by the user.

## Alpha and ordinary preview procedure

Raw built-in transparent PNGs contain a diffuse low-alpha halo, typically alpha
1/255; the opaque art is about 252-253/255. Keep source PNGs unchanged. A native
Godot canvas shader discards alpha below 0.65 and makes retained interior opaque:

```glsl
shader_type canvas_item;
void fragment(){
    vec4 pixel=texture(TEXTURE,UV);
    if(pixel.a<0.65){discard;}
    COLOR=vec4(pixel.rgb,1.0)*COLOR;
}
```

The standalone project under `firearm/preview/` reads PNGs directly by absolute
path, has no game autoloads or save access, writes its own preview/measurements,
and exits. It was rendered with Godot
`4.6.3.stable.official.7d41c59c4`, Compatibility/OpenGL on Intel Arc 140V.
This does not establish game integration, animation quality or a passed test.
No automated QA/test runner has been run in this art task.

## Immediate continuation and evidence boundary

1. The enabled heavy and rifle guard/attack/walk families have parent-approved
   actual Player production captures. Heavy has two unique gait keys; rifle has
   three. Heavy opposite contact still needs a successful future authored batch.
   Game/animation acceptance is deferred.
2. Rejected source and preview archive/removal disposition is tracked separately
   in `docs/ASSET_CLEANUP_REPORT.md`; this checkpoint does not infer file presence
   or removal from rejection alone. This task deleted nothing.
3. Complete the remaining real intermediate facings and action keys in approved
   batches. Do not enlarge the accepted compact rifle or replace standing
   normalization with action silhouette height.

This checkpoint was reconciled by direct Player/manifest source inspection;
the codebase graph was unavailable after a transport failure, so graph coverage
was not established. No tests, QA suite, game acceptance run, commit, push or
real save writes were performed for this integration. Source hashes were read
directly and native images were inspected as ordinary art production evidence.
