# Shared prop and scene grounding adapter

Production source checkpoint: 2026-10-23. The parent has approved all three source
PNGs for integration and the manifest is enabled. This pass follows the current no-tests /
no-QA directive. Source review and whitespace inspection have been performed;
ordinary isolated GUI rendering and parent art review establish only bounded
visual acceptance, recorded below. No gameplay, collision-traversal, save/load,
or release pass is claimed.

## Activation and scope

`WorldProp.material_kit()` reads `data/art/world_materials_v3.json` once. Version
must be `3` and `enabled` must be `true`. Activation followed the parent's
source-image approval; the parent subsequently accepted the representative
in-scene compositions described below.
Missing/disabled data keeps the legacy art path.

The adapter is opt-in through the fourth `WorldProp.setup` argument, the route
context. Wasteland supplies its existing route ID at every prop call site;
Village/Guild callers omit it and retain the legacy presentation and shadow.
No world-v2 JSON, route IDs, events, reward IDs, narrative copy, or save schema is
changed by this adapter.

## Pixel and foot contract

The eight cohesive kit keys are `rubble_a`, `rubble_b`, `wall_stub`, `wagon`,
`thorn`, `dry_grass`, `supply`, and `waypost`. Each prop provides its original
PNG path, explicit source rectangle, absolute source-pixel foot, fixed world
width, and world-pixel collision rectangles relative to that foot.

Native `AtlasTexture` plus nearest sampling draws the original pixels. A native
CanvasItem shader discards alpha below each entry's `alpha_cutoff`, falling back
to the manifest value and then `0.65` (the approved eight entries use `0.5`).
The placement bounds inspect the same
retained-alpha threshold; the explicit foot remains fixed. No generated source
PNG is rewritten, painted, carved, or background-removed by the loader.
Procedural silhouette carving remains restricted to the old missing-file
fallback. Kit props use authored scale and unmodified colors, with no random
size or tint drift. Collision rectangles remain separate from decorative height.

V3 atlas regions are shared in a static dictionary keyed by original PNG path
and source rectangle. Their existing metadata stores the retained-alpha bounds
per threshold, so matching props and later scene entries reuse the same scan.
The immutable cutout shader is shared, with one shared material per cutoff;
each sprite retains its own color and transform. This avoids repeated resource
construction and bounds work; it is not a measured performance claim.

Common legacy prop IDs keep their IDs, map labels, blocking state, and groups
while receiving kit visuals and their registered small physical footprints.
The six unique story landmark sources and their original normalized collision
footprints remain in place. Their contextual soil contact is shared with the
new palette. Crystals retain their visual emphasis on `crystal_scar`; the marsh
retains its existing toxic-pool art. Other routes map those generic props to
quiet rubble. Harvestables reuse the same nonblocking visual adapter while
preserving their existing interaction, drop IDs, amounts, and harvested state.

## Composition and ground contact

The activated kit replaces the uniform whole-map decorative scatter. Half its
existing prop budget is available to small clusters at architecture footprint
edges; the remainder follows existing road paths at their shoulders. Uneven
pairs of rubble, dry grass, thorn, and occasional supplies use fixed local
offsets. These additional clusters have no physical blockers. Existing authored
cover and landmarks retain their placement responsibilities.

Cluster placement excludes the existing story and guarded-discovery reserves,
path reserves, return lane, player area, real architecture feet, and other prop
silhouettes. Rejected candidates are omitted. This intentionally permits fewer
decorations than the budget when the authored layout needs open space.

Explicit wasteland props use a shallow stepped soil/contact shadow rather than
a broad smooth ellipse. Architecture uses two short, thin ragged soil patches
at its foot corners, sparse small `rubble_b` atlas fragments and a minimal local
contact shadow, without new physics. Positive collision-foot depth is clamped
to the image base for these marks; the physical rectangles stay unchanged.
No continuous strip spans the facade. The first ordinary capture revealed an
overly opaque full-width skirt; that treatment was removed after visual review.
Prop soil starts at
RGB `47,43,36` and shadows use charcoal `18,20,19`, matching the shared muted
earth/slate family. These are contact marks, not traversable raised floors or
large opaque ground rectangles.

## Parent production review and remaining scope

The parent inspected updated ordinary scenes across all six route themes and
highway arrival after removing the opaque facade skirt and sharing atlas/bounds
resources. The final render exited 0 with seven captures and no observed logged
errors. `captures/source_snapshot.json` records the 16 matching source inputs and
capture fingerprints. This accepts the bounded common-material integration;
whole-map encounter composition, traversal and region-specific detail remain open.

For subsequent changes, inspect the same route seeds/camera positions as the
baseline in an isolated ordinary project run. Check retained atlas silhouettes,
foot contact, camera-scale density, foreground overlap, and clear evidence /
return approaches. Any screenshots establish bounded art evidence only. The
campaign's old mechanical QA evidence does not cover this new source change.
