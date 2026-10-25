# World v4 highway architecture sources

Updated: 2026-10-23 (Asia/Taipei). These are source-only candidates for the
highway composition. They are not registered in a manifest or runtime loader,
and parent scene review and crop/foot/collision registration remain pending.
The rejected composition and ground/runtime review boundary are in
[ground_runtime.md](ground_runtime.md).

The roadwarden shelter at assets/world_v4/architecture/roadwarden-shelter-v4-01.png
was visually inspected as the material reference: gray-brown small masonry,
charcoal blue-gray slate, dark warm mortar, weathered rotten oak, matte iron and
subdued upper-left overcast light. The built-in imagegen calls used those traits
in text; no reference image was attached to the new gate, wall or viaduct calls.
This avoided inheriting the shelter image's broad ground/backdrop treatment.

## Slate boundary wall

- Source: assets/world_v4/architecture/slate-boundary-wall-v4-01.png
- Prompt: assets/world_v4/prompts/slate-boundary-wall-v4-01.txt
- Generator: built-in image_gen, original generation (no edit pass)
- Original generated output: C:\Users\wuwu6\.codex\generated_images\01a164e7-56a6-7e82-9da2-0fc6c0ba647b\exec-8bcc518f-d21d-4b36-9355-bb19b1f61c31.png
- Dimensions and PNG format: 1536 × 1024, 8-bit RGBA
- File size: 1,411,937 bytes
- SHA-256: D8717504DC6B2D2690DD1EAB3E6FAD2F5ECBD2BD6ACF4F5D40A1BFB664532E11
- The project copy's hash matches the generated output; source PNG bytes were
  copied unchanged.
- Alpha-map inspection: 80.82% of canvas pixels are alpha zero. Sampled empty
  background coordinates are zero-alpha. Low-alpha pixels extend within the
  asset/contact region; no backdrop pixels were edited or removed.
- Provisional native foot: approximately (768, 679), the midpoint of the
  lowest visible front-face stone toe line. This is an observation only; register
  the actual crop and ground-contact contract during parent integration.

## Roadwarden gate

- Source: assets/world_v4/architecture/roadwarden-gate-v4-01.png
- Prompt: assets/world_v4/prompts/roadwarden-gate-v4-01.txt
- Generator: built-in image_gen, original generation (no edit pass)
- Original generated output: C:\Users\wuwu6\.codex\generated_images\01a164e7-56a6-7e82-9da2-0fc6c0ba647b\exec-cb8b19d8-ab17-4211-a6e2-935ad68c5ecf.png
- Dimensions and PNG format: 1536 × 1024, 8-bit RGBA
- File size: 1,762,363 bytes
- SHA-256: A8E1DE60CC341E56D3E0D900C750EC9176D3357CE935A460ABCECF3F938257BF
- The project copy's hash matches the generated output; source PNG bytes were
  copied unchanged.
- Alpha-map inspection: sampled center-aperture coordinates (768, 500),
  (768, 600), (768, 750), (600, 750) and (768, 900) are alpha zero, so
  the open passage shows the underlying game ground. Sampled far corners are
  also zero-alpha. Whole-canvas alpha-zero coverage is 70.02%; the larger gate
  silhouette occupies more area than the prompt target, and low-alpha pixels
  extend into some outer margins. Inspect its contact and margin behavior in a
  full-camera composition before acceptance.
- Provisional native foot: approximately (768, 800), midway between the two
  lowest pier toe contacts on their shared ground baseline. This point falls in
  the transparent passage and is only the placement anchor.

## Broken viaduct

- Source: assets/world_v4/architecture/broken-viaduct-v4-01.png
- Prompt: assets/world_v4/prompts/broken-viaduct-v4-01.txt
- Generator: built-in image_gen, original generation (no edit pass)
- Original generated output: C:\Users\wuwu6\.codex\generated_images\01a164e7-56a6-7e82-9da2-0fc6c0ba647b\exec-24bc4654-a645-47d5-9cb5-906cbe983354.png
- Dimensions and PNG format: 1536 × 1024, 8-bit RGBA
- File size: 1,836,641 bytes
- SHA-256: F3D8C7E18F9D7D574D5349EB0E8831292F22994E9678F9F30A3C661ECB8B0B73
- The project copy's hash matches the generated output; source PNG bytes were
  copied unchanged.
- Alpha-map inspection: sampled open-arch coordinates (768, 350), (768, 450),
  (768, 500), (768, 600), (768, 700), (600, 600) and (950, 600) are
  alpha zero. Whole-canvas alpha-zero coverage is 72.99%. Some low-alpha pixels
  reach the outer image edges, so inspect source margins and contact at full
  camera scale before acceptance.
- Provisional native foot: approximately (768, 780), midpoint between the
  two lowest pier toe contacts on their shared ground baseline. It lies in the
  transparent passage and is only a placement anchor.

## Review status

All three assets are provisional source art. Parent integration owns crop
rectangles, actual feet, collisions, scale and the full highway-scene render.
The faint alpha around some generated contacts/margins has not been edited. No
manifest, runtime code, tests, QA suite or commit was changed for this source
batch. Byte hashes and dimensions were checked; visual acceptance remains open.