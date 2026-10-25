# Wasteland ground-area geometry

`data/art/world_v2.json` keeps each ground area's normalized `rect` as its
conservative bounds and backward-compatible fallback. Water and chasm areas may
also provide an optional `outline`, an ordered list of normalized world points:

```json
{
  "rect": [0.29, 0.29, 0.1, 0.3],
  "outline": [
    [0.31, 0.32], [0.34, 0.30], [0.38, 0.33], [0.385, 0.45],
    [0.37, 0.55], [0.33, 0.57], [0.30, 0.53], [0.305, 0.41]
  ],
  "kind": "water",
  "blocking": true
}
```

The example points are illustrative; production outlines should follow the pool
inside its existing `rect`. Point pairs use whole-world coordinates, not offsets
from the rectangle. Omit the repeated closing point. Valid outlines contain at
least three distinct finite numeric pairs, stay inside the world and `rect`, have
nonzero area, and do not cross or overlap themselves. Invalid or absent outlines
use the legacy rectangle path.

`WorldBackdrop` uses one parser to convert valid outlines to world-pixel points
for both its fallback ground detail and material mask. It samples signed distance
to those edges into the existing cached eight-world-pixel ground mask, using the
rectangle only to reject unrelated chunks and samples early.
The same parsed vertices form a native `CollisionPolygon2D` for blocking areas;
they are not rounded or expanded to the old rectangular collision. The mask's
eight-pixel spacing softens the rendered shoreline around the physical edge.
The old rectangle still bounds architecture reservations and placement checks.
For a valid outline, saved-player protection checks polygon containment and
distance to its edges, with a 48-world-pixel margin. For legacy rectangles, the
existing rectangle collision, tile snapping and save-position escape behavior
remain in place.

An area's `kind` continues to select its material treatment. Only
`blocking: true` creates collision. Keep optional outlines on water and chasm
areas; other ground kinds retain their existing area behavior unless they need
an explicitly authored basin shape.

## Regional floor sources

The optional top-level `regions` object in `world_materials_v3.json` can override
the shared `ground.earth` and `ground.road` entries for a route, using the same
`path`, `world_size`, and `source_rect` fields. An omitted floor source inherits
the shared entry. A three-channel route `tint` may also be supplied; absent or
invalid tint values keep the existing route tint. This keeps each region's floor
identity while reusing the existing world-space mapping and cached masks.

## Parent activation checkpoint

The route manifest now supplies four marsh-water, two crystal-chasm, three furnace and three coolant outlines. Wide/narrow ordinary renders are recorded in `captures/current-production/`; traversal and old-save regression remain deferred. All outlines share the validated renderer/collision path; conservative reservation rectangles remain.
