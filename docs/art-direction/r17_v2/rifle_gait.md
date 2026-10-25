# Rifle gait source production

2026-10-23. Parent-approved three-key rifle gait, merged into the active family.

## Delivered source keys

The approved compact two-hand rifle ready v002 already supplies contactA.
Two new drawings now supply visibly different leg phases while preserving
the same eight camera views, blue-gray/gold armor, gold-cross helmet,
crimson cape, compact carbine and stock/trigger/support hand relationship:

- `assets/sprites/player/redesign_v2/firearm/r17_firearm_contact_b_v002.png`:
  opposite-contact key, final bounded correction. SHA256
  `36a37e00263e9cf16464df381dfef05d2da4f6385762d1b4ddf70636e593f243`.
- `assets/sprites/player/redesign_v2/firearm/r17_firearm_passing_v001.png`:
  narrowed mid-step stance, planted leg near vertical and bent passing knee.
  SHA256 `55f6a5c11e453b510c8c3c7279a3df9dbca31611e28198046aa1da01ef7d4064`.

Both are1536x1024 original RGBA outputs from built-in imagegen. Their full
prompts are versioned beside them as `prompt_gait_contact_b_v001.txt`,
`prompt_gait_contact_b_v002.txt` and `prompt_gait_passing_v001.txt`.
The original approved reference is unchanged. No pixel repainting, mirroring
or flat sprite rotation was used. Rejected/superseded contactB v001 remains
outside active runtime, preserved rather than deleted.

## Art findings and acceptance boundary

I directly inspected both source sheets and ordinary native96px renders.
Passing visibly closes all eight footprints and lifts the swinging knee/heel.
ContactB changes the spread, leg overlap, knee flexion and cape response;
front/oblique views show a different lead/trail arrangement. The single
targeted correction makes N's right boot the lower/larger contact instead of
the original left boot. E/W anatomical lead exchange remains visually subtler
than oblique/front/back views; do not claim mechanically proven opposite-leg
anatomy from those silhouettes. Both keep the two-hand supported compact
carbine, including front/rear projected gun treatment.

The parent approved the native three-key package and merged passing/contactB
into the active rifle family. Active walk order is
`passing,ready,passing,contact_b`, where `ready` is the approved contactA source.
The parent then inspected the actual Player's ordinary rifle idle/walk/fire
renders and approved the bounded three-key gait. This source worker did not
edit Player code or the active family manifest; the parent owns integration.
The request for32 actual facings remains incomplete: these sheets each have
eight views. The active four-slot `passing,A,passing,B` loop contains only
three authored source keys; the reused passing slot is not another drawing.
A separately authored second passing phase and the remaining action matrix
remain open.

## Portable registrations

`rifle_gait.json` contains source paths, hashes and all eight cells for each
key in the current runtime schema:
`[x,y,width,height,soleX,soleY,handX,handY,bodyHeight,muzzleX,muzzleY]`.
Coordinates are absolute source pixels. ContactA copies the accepted ready
registration. Each new source's actual visible gutters were inspected before
selecting crops; the same-size page did not imply blindly using384px columns.
ContactB uses top x-boundaries0/410/800/1140/1536 and lower0/425/800/1140/1536.
Passing uses top0/410/800/1140/1536 and lower0/420/800/1140/1536. Both rows
split at y512. Hand/muzzle anchors were manually placed on each drawing.

Solid pixel bounds, measured grounded contact and body height are recorded in
the versioned measurement sidecars under `firearm/gait_preview/`. Pixel alpha
cutoff0.65 matches the current family contract, without modifying source bytes.
New registered sole y is the lowest solid contact. Sole x keeps the approved
contactA's normalized helmet/torso projection: switching to the other grounded
foot must not translate the torso about28px sideways at96px scale. The raw
supporting-foot positions remain separately inspectable in sidecars. These are
art registrations, not evidence of runtime motion smoothness.

## Ordinary art output

`assets/sprites/player/redesign_v2/firearm/gait_preview/rifle_gait_96_contact_sheet.png`
compares approvedA, passing andB at96px body height for all8 views. Individual
`contact_b_v002_native.png` and `passing_v001_native.png` show96px and1.6x.
All three final outputs were directly viewed. The separate source-only preview
project has its own custom user directory, calls no gameplay/save code and
does not overlap the parent's full-project art copy.

Rendered with Godot4.6.3.stable.official.7d41c59c4, Compatibility/OpenGL3.3,
Intel Arc140V. Final ordinary render commands exited0 with no logged errors.
The parent's integrated Player art evidence is
`docs/art-direction/r17_v2/sprite_preview/player_v2_rifle_walk_keys.png`, with
the idle/walk/fire output log at
`docs/art-direction/r17_v2/sprite_preview/rifle_gait_render.log`.
The log identifies the same Godot4.6.3 Compatibility renderer and actual Player
art outputs; the parent reports exit0, no logged errors and direct walk review.
This is ordinary integrated art playback evidence. No tests/QA runners or
gameplay/campaign checks were executed. No push.

On another platform change the preview scripts' `ROOT` constant and run the
source-only project with `res://contact_sheet.tscn`; it loads `rifle_gait.json`
and the original project PNGs. The JSON is portable (`res://` source paths).
Generation tools are optional for continuing integration from these saved
sources; do not introduce paid API/key use to reproduce an already saved key.
