# World v4 regional floor source record

Updated: 2026-10-23 (Asia/Taipei)

Historical source-generation record. Later runtime selections and camera review
supersede the provisional status below. The old fractured shale is preserved
inactive; [the City street pass](city_street_block.md) selects fine cold silt/shale
at512 repeat for Crystal/Factory/Facility. Damp slate remains active for roads.

These are two new flat ground-material candidates intended to add regional
identity where the six route captures currently share a weak brown-floor read.
Each source is 1254 × 1254 pixels and maps to a 512 × 512 world-pixel tile
(about 2.45 source pixels per world pixel). Both are opaque RGB PNGs copied
byte-for-byte from built-in image_gen outputs. Prompts and generation history
are recorded beside the assets. They remain provisional and are not a claim of
runtime integration or full-camera visual acceptance.

## Cold fractured shale

- Source: assets/world_v4/ground/cold-fractured-shale-v4-01.png
- Prompt record: assets/world_v4/prompts/ground-cold-fractured-shale-v4-01.txt
- Built-in image_gen output:
  C:\Users\wuwu6\.codex\generated_images\01a16509-18a4-7ec1-b9fa-8247778ff862\exec-4c300138-e2fb-451b-9ef2-bd6b632cdc88.png
- Dimensions and native PNG mode: 1254 × 1254, 8-bit RGB, no alpha channel
- File size: 2,049,234 bytes
- SHA-256: 1dacd0b113d5881c34c42db71fdf1a01f2935186b1588acefc4f55d9c87b6ab8
- The project copy has the same SHA-256 as the generated output; no re-encoding
  or pixel post-processing was applied.
- Source inspection shows broad muted blue-charcoal and slate-violet ash planes,
  sparse thin fractured seams, a few tiny slivers and rare dim purple glints.
  The large forms stay low contrast and do not read as deep traversable chasms.
  Some fine surface texture remains; inspect its final density at world scale.

## Damp cut slate

- Source: assets/world_v4/ground/damp-cut-slate-v4-01.png
- Prompt record: assets/world_v4/prompts/ground-damp-cut-slate-v4-01.txt
- Built-in image_gen output:
  C:\Users\wuwu6\.codex\generated_images\01a16509-18a4-7ec1-b9fa-8247778ff862\exec-55b955f7-6d93-4d54-8d72-4f20da5848e0.png
- Dimensions and native PNG mode: 1254 × 1254, 8-bit RGB, no alpha channel
- File size: 2,875,960 bytes
- SHA-256: 0f3de8e194c2460d98118884e7c178a62deb184f486717f35b7f6421561263a1
- The project copy has the same SHA-256 as the generated output; no re-encoding
  or pixel post-processing was applied.
- Source inspection shows dark cool slate flags partly buried by broad ash-gray
  sediment, with subdued gray-olive seam color. A 2 × 2 repeat preview showed
  no obvious abrupt seam at normal viewing size. The exposed stones read as
  small irregular paving patches rather than large slabs; verify their exact
  count and 10–18 world-pixel width in the gameplay camera. Some fine texture
  remains, and the preview is not a substitute for the live composition review.

## Review boundary

Both sources were inspected directly and in temporary 2 × 2 repeat previews.
Their opposite edge pixels are not identical, so the review establishes only
that no abrupt join was obvious in those previews; it does not establish a
pixel-identical wrap or an in-game seamless result. Neither source was added to
the runtime material manifest in this source-only batch. Keep both provisional
until the ordinary gameplay camera confirms scale, edge behavior, palette
separation and ground/architecture cohesion. No tests or QA suites were run.
