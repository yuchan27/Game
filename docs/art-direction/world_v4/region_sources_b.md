# World v4 architecture source record — batch B

Updated: 2026-10-23 (Asia/Taipei). These three original architecture sources are **provisional art candidates**. They are not selected by a manifest, registered in runtime code, or accepted in a full gameplay-camera composition. The existing v2 module widths and foot shapes below are reference contracts for the parent integration/review; this batch does not change them.

The fixed camera, weathering, small stone courses, restrained slate/umber palette and localized contact debris follow the inspected v4 shelter and rooted-debris sources. Each prompt is saved beside its selected source. The project PNGs are byte-for-byte copies of the built-in `image_gen` outputs; no crop, alpha repair, resize, repaint or re-encoding was applied. PNGs decode as 1536 × 1024 with RGBA alpha. Alpha bounds below are the measured bounds at alpha ≥128, so faint edge pixels may extend farther. Full-camera cohesion and physical collision registration remain with the parent owner.

## Fallen bell sanctuary/archive

- Source: `assets/world_v4/architecture/fallen-bell-sanctuary-v4-01.png`
- Prompt: `assets/world_v4/prompts/fallen-bell-sanctuary-v4-01.txt`
- Generator: built-in `image_gen`; selected third bell iteration after rejecting two earlier outputs for cramped vertical margins. Earlier generated variants remain untouched in the Codex generated-images folder and were not copied into the repository.
- Selected original output: `C:\Users\wuwu6\.codex\generated_images\01a164f2-715c-7693-88a6-c226da092d94\exec-ee7066f9-8d26-431f-abb1-65b6646b194a.png`
- Dimensions / decoded mode: 1536 × 1024, RGBA; source and project copy SHA-256: `A342E5547EC3C0D69D97AD01D189C5A84EDA8643B2D2D77C8A074FF8B7AA091C`.
- Alpha ≥128 bounds: x=175–1409, y=85–928.
- Visual read: broken slate roof and side planes are visible; a bronze bell hangs in the tower; the archive cabinets block the lower arch. The arch is visually prominent, so confirm at game scale that it still reads as sealed detail rather than a walk-in opening.
- Contact / foot note: loose slate and roots form one broad irregular lower foundation band, approximately y=800–928. A provisional single-wide-foot anchor near (790, 900) is only a visual starting point; register the actual stone contact line and footprint after camera review, excluding the outermost loose chips.
- Existing v2 reference: `metropolis_bell`, width 420 world pixels, one footprint `[-188, -62, 376, 74]`.

## Sealed cistern

- Source: `assets/world_v4/architecture/sealed-cistern-v4-01.png`
- Prompt: `assets/world_v4/prompts/sealed-cistern-v4-01.txt`
- Generator: built-in `image_gen`; copied without post-processing or re-encoding.
- Original output: `C:\Users\wuwu6\.codex\generated_images\01a164f2-715c-7693-88a6-c226da092d94\exec-405bc830-5366-401d-a16f-bd913398c215.png`
- Dimensions / decoded mode: 1536 × 1024, RGBA; source and project copy SHA-256: `43C5481B9A181085F85558D37F2A4792C4F466E84C75657B3467000BDB36824B`.
- Alpha ≥128 bounds: x=123–1411, y=118–910.
- Visual read: the low vaulted roof and two masonry side planes are visible. The base is closed; the side has dull iron pipes and valves with a small dim cyan inspection port.
- Contact / foot note: the low stone base and sparse roots form one continuous closed contact footprint, with debris reaching the lower edge around y=910. A provisional anchor near (768, 884) is a guide only; register the bearing base, not detached chips.
- Existing v2 reference: `facility_lab`, width 460 world pixels, one footprint `[-210, -58, 420, 70]`.

## Stone service crossing

- Source: `assets/world_v4/architecture/stone-service-crossing-v4-01.png`
- Prompt: `assets/world_v4/prompts/stone-service-crossing-v4-01.txt`
- Generator: built-in `image_gen`; copied without post-processing or re-encoding.
- Original output: `C:\Users\wuwu6\.codex\generated_images\01a164f2-715c-7693-88a6-c226da092d94\exec-a4f22d0f-9044-46b8-b896-26eae40c9245.png`
- Dimensions / decoded mode: 1536 × 1024, RGBA; source and project copy SHA-256: `78CC113E377A16D1DF90A84F2F12AFF36707DF59BC35CE0CBD3DEAAE50096C12`.
- Alpha ≥128 bounds: x=211–1343, y=302–781.
- Visual read: two separate outer stone piers carry the slate cap and iron pipe. No center pier or ground strip was generated. The opening between the feet is genuine transparent alpha: sampled center points `(768, 500)`, `(768, 560)`, `(768, 620)`, `(768, 700)` and `(768, 760)` all have alpha 0.
- Contact / feet note: keep two independent contacts only. Approximate image-space starting points are left `(365, 700)` and right `(1180, 745)`; determine precise support polygons from the stone feet after scaling. Do not bridge them with a traversal footprint.
- Existing v2 reference: `industrial_crossing`, width 430 world pixels, two separate footprints `[-196, -40, 88, 52]` and `[112, -40, 84, 52]`.

## Review boundary

The native-source inspection confirms the requested oblique roof/top and side-plane views, transparent outer backgrounds, closed cistern base, and transparent crossing gap. It does not establish material cohesion with the complete camera, runtime alpha thresholds, visible-world scale, movement clearance, or collision. In particular, verify that the generated masonry courses resolve to the requested 4–8 world-pixel units at each legacy module width; source inspection alone is not enough to accept that scale. Register the feet and physics in the owning runtime work, then review the complete scene with the normal gameplay camera. No manifest/runtime edits or tests/QA suites were part of this source-only batch.