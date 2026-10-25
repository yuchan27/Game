# Visual review evidence checklist

## Resolve the current screen set

- Treat `scripts/tests/VisualReviewRunner.gd`'s `REQUIRED_CAPTURES` as the
  executable capture contract. Read it at review time; never copy a capture count
  or a stale list into this reference.
- Cross-check the runner against `docs/SCREEN_STATE_MATRIX.md`. The matrix owns
  player entry/exit paths, applicable states, keyboard/mouse behavior,
  scrolling/focus, viewport coverage, and remaining evidence gaps.
- A screenshot staged by assigning state, emitting a signal, or moving the player
  proves composition only. Record it separately from input and player-reachability
  evidence.

## Derive viewport profiles

Read `project.godot` and record the logical viewport, configured launch window,
stretch/aspect behavior, any declared minimum size, and the actual rendered image
dimensions. Review the configured launch size, the declared narrowest supported
cold launch, and live resize from the default launch as distinct cases. If a
minimum supported profile is not declared, record the gap and use an explicit
candidate profile without claiming platform support.

## Inspect each affected capture

- UI: readable Traditional Chinese text, no overlap or clipping, consistent
  spacing, reachable primary/close actions, focus visibility, modal occlusion,
  empty/loading/error/success feedback where applicable, and scroll boundaries.
- World: terrain and props share material, lighting, palette, perspective, scale,
  and contact shadows; interactables have readable approaches and are not buried.
- Characters: compare active frame crops, soles, grips, weapon muzzle/pivot, and
  collision shapes to current manifests. Check every captured direction/action
  for missing, mirrored, duplicated, or misaligned frames.
- Transitions and story: check title-to-prologue, scene entrance, interaction
  prompts, journal/choice states, death/recovery, return, debrief, and close or
  cancel paths covered by the current runner.

## Record limits

Keep the source fingerprint, engine version, profile dimensions, cold-start or
resize path, capture names, report counts, and unresolved states together. Open
the actual full-resolution PNGs; runner success, dimensions, or headless output do
not prove visual quality. Do not claim whole-screen completion while any
applicable state, input path, or supported viewport remains unreviewed.
