# World v4 regional architecture sources — set A

Generated 2026-10-23 as provisional regional architecture sources for the whole-camera art review. The three PNGs are direct copies of built-in image-generation outputs requested on transparent RGBA canvases. They were not cropped, repainted, resized, or alpha-edited. The matching prompt files preserve the exact generation prompts. A source hash identifies each copied PNG.

| Source | Dimensions | Bytes | SHA-256 | Prompt |
|---|---:|---:|---|---|
| `assets/world_v4/architecture/marsh-pumphouse-v4-01.png` | 1536 × 1024 | 2,375,780 | `c4512511be1fc5f3b6d17c35813f4e2020cdc6d695ac114c8ad8b53dc2effe2d` | `assets/world_v4/prompts/marsh-pumphouse-v4-01.txt` |
| `assets/world_v4/architecture/crystal-buttress-v4-01.png` | 1536 × 1024 | 2,161,957 | `6a42b41f02ea57a763101f762b6a10cdd3a86130548033ff2f1f175b0453900c` | `assets/world_v4/prompts/crystal-buttress-v4-01.txt` |
| `assets/world_v4/architecture/ruined-forge-v4-01.png` | 1536 × 1024 | 2,479,443 | `db35a69962b03eeed374398ad714d61abeeee556ebe5802e90c142d7526625fc` | `assets/world_v4/prompts/ruined-forge-v4-01.txt` |

## Shared source contract

- Style references: `roadwarden-shelter-v4-01.png` and `rooted-medieval-debris-v4-01.png` were supplied as material, lighting, contact, and oblique pixel-art references. Each new source is a distinct building design.
- Target scale: roughly 390–420 world pixels wide, with masonry units intended to read at 4–8 world pixels and a shallow contact band near 70 world pixels. The built-in image tool returned the requested 1536 × 1024 size. These target dimensions and pixel density still need a whole-camera review at normal gameplay scale.
- Light/materials: soft overcast light from the upper left; shared soot-brown soil, weathered gray-brown masonry, charcoal slate, rotten oak, and dull oxidized iron; regional accents remain sparse.
- Alpha: true transparent output was requested. Corner alpha samples were 0,0,1,0 for the pump-house and 0,0,0,0 for the buttress and forge (top-left, top-right, bottom-left, bottom-right). The pump-house's bottom-left sample is near-transparent alpha 1; preserve the source and inspect the edge in the integrated camera before activation.
- Status: source work only. No runtime placement, manifest, collision, or foot registration is claimed here. Parent integration owns the actual source feet after camera composition review.

## Per-source foot and contact notes

### Marsh pump-house

The building has a continuous closed lower wall and a shut, partly blocked service door; there is no large entrance or walk-through floor. Treat the bottom edge of the masonry walls as the provisional foot region. The shallow soil, slate, root, and dead-reed traces are authored contact art only. The handwheel, pipes, roof overhang, and reeds are not feet. Register physical feet from the actual integrated crop; do not infer walkability from the door or pipe geometry.

### Crystal buttress

The final source is one connected solid wall remnant with a continuous lower masonry edge beneath both unequal buttresses. It has no arch, doorway, courtyard, or passage. Sparse rubble and short roots beside the wall are authored contact art only. Register the actual foot extent from the integrated crop; do not treat the broken crest or resonance hoop as a support point.

### Ruined forge

The lower masonry enclosure is closed and continuous beneath the broken roof and both short chimneys. The small iron-grated furnace niche is shallow and non-traversable; it is not an entrance or passage. Soil, slate, cinder, and root flecks are shallow contact art only. Register the actual wall-base feet from the integrated crop; the chimneys, roof rubble, and furnace detail are not feet.

These are source-level contracts and provisional descriptions, not proof that the assets fit the current camera, gameplay scale, collision, or terrain blend. Keep each source provisional until the complete composition is reviewed.
