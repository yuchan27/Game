# World v4 landmark and grounded-hazard source sheets

Generated 2026-10-23 as provisional source art for parent-owned cropping and
whole-camera review. Each sheet was generated once with the built-in image_gen
tool, with transparent output requested, then copied into the project unchanged.
Neither PNG was cropped, resized, repainted, or alpha-edited. The prompt files
record the prompts used for the two generation calls.

| Source | Dimensions | Bytes | SHA-256 | Prompt |
|---|---:|---:|---|---|
| `assets/world_v4/landmarks/ancient-salvage-landmarks-v4-01.png` | 1536 × 1024 | 2,395,169 | `dcabc5a757e3054f53bcd666806445fc4536067df877de37af31e40a4323a87c` | `assets/world_v4/prompts/ancient-salvage-landmarks-v4-01.txt` |
| `assets/world_v4/props/grounded-hazards-v4-01.png` | 1536 × 1024 | 1,416,864 | `181fabe736f2e1150742da1e1df568a7f900647c62e5f7d7c302972c795143a9` | `assets/world_v4/prompts/grounded-hazards-v4-01.txt` |

## Shared source contract

- Style references: `roadwarden-shelter-v4-01.png` and
  `rooted-medieval-debris-v4-01.png` were used only for the gray-brown slate,
  umber soil, matte iron, pixel-cluster density, upper-left overcast light and
  oblique camera language. Their subjects and backdrop were not requested.
- Materials: small gray-brown masonry and charcoal slate, soot-dark umber soil,
  aged bronze, matte oxidized iron, muted olive seep, and restrained slate-violet
  mineral. Both sheets use the same approximately 38-degree down-looking
  orthographic perspective and upper-left soft light.
- Alpha: both files decode as 32-bit RGBA. All four canvas corners are alpha 0.
  For the landmark sheet, sampled transparent gutter points `(600,300)`,
  `(950,300)`, `(1000,520)`, and `(760,760)` are alpha 0; `(800,520)` is alpha
  1. For the hazard sheet, sampled gutter point `(896,512)` and margin points
  `(768,128)`, `(768,896)`, `(32,512)`, and `(1504,512)` are alpha 0. These
  samples confirm genuine transparent regions; the source alpha remains intact.
- Status: source work only. These are not accepted in gameplay scale yet. The
  parent owns object crop rectangles, physical feet, story-ID mapping, placement,
  and review in the real camera composition. No manifest, runtime, collision,
  test or QA result is claimed here.

## Ancient salvage landmarks

The source sheet has three objects across its upper row and two across its lower
row: a small rooted bronze-and-iron water manifold, a broken slate-violet
acoustic obelisk with an old bronze ring, a toppled iron rotating governor set
into forge rubble, a closed stone archive chest with iron clasps and record
bundles, and a closed stone memory vault with a matte-iron face and small cyan
inspection glass. No door, entrance, or traversable floor was authored.

The visual inspection found all five objects complete and distinct, with clear
transparent space at the sampled gutters. The governor's rotor is large and
visually assertive; confirm that it reads as toppled machinery rather than a
windmill-shaped landmark at actual game scale. Register lower object feet from
the integrated crop, not from this sheet's debris.

## Grounded hazards

The second sheet contains two low ground entries side by side: an irregular
muted-olive seep with a few bubbles and a sparse, partly buried slate-violet
crystal outcrop. Their shapes remain low to the ground and use matching shale,
soil, small slate flecks, dust, and roots. The seep's wet highlights are more
visible than the surrounding material; review its low-risk/readability balance
in the camera before activation.

Both patches are source candidates only. Crop their actual alpha bounds and
contact details independently; do not infer equal cells or physical extents from
the overall canvas layout.
