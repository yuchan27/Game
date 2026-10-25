# World v4 terrain source record

Updated: 2026-10-23 (Asia/Taipei)

These 1254 × 1254 ground sources are art candidates for the revised wasteland
surface. The rejected highway composition and the ground/contact review boundary
are recorded in [ground_runtime.md](ground_runtime.md). The v4-01 cobble attempt
is retained as history; v4-02 is the denser paving candidate. Source files do not
constitute scene integration or visual acceptance.

## Packed umber earth

- Source: `assets/world_v4/ground/packed-umber-earth-v4-01.png`
- Prompt: `assets/world_v4/prompts/ground-quiet-packed-earth-v4-01.txt`
- Dimensions and native PNG mode: 1254 × 1254, 8-bit RGB (no alpha channel; opaque)
- SHA-256: `1f786a1d6006edc0974052653f5e4b6c3a9ed5c21179aec56c724d499ae8abbf`
- Status: pre-existing source inspected and retained byte-for-byte. It has broad
  umber patches and restrained values; close inspection still shows visible
  low-contrast micrograin. Review its readability at the intended camera scale.

## Buried slate cobbles

- Source: `assets/world_v4/ground/buried-slate-cobbles-v4-01.png`
- Prompt: `assets/world_v4/prompts/ground-buried-slate-cobbles-v4-01.txt`
- Generator: built-in `image_gen`; no post-processing or re-encoding
- Original generated output:
  `C:\Users\wuwu6\.codex\generated_images\01a164d9-f083-7ce3-b3c9-0570850c7236\exec-7abc23f2-419d-4802-acb2-c0c2aec50836.png`
- Dimensions and native PNG mode: 1254 × 1254, 8-bit RGB (no alpha channel; opaque)
- SHA-256: `1b739736f7c35d859102a87bf7c3f0446f6392e13b10d29786385d61eb7aaf21`
- The project copy has the same SHA-256 as the generated output, confirming that
  its source pixels and PNG bytes were preserved.
- Status: superseded as the paving source. It has small, subdued slate fragments
  over open brown earth, but reads as scattered rocks rather than a cobbled road.
  Retained unchanged as the earlier candidate; it has not been reviewed in a
  repeated in-game composition.

## Buried slate cobbles, denser paving candidate

- Source: `assets/world_v4/ground/buried-slate-cobbles-v4-02.png`
- Prompt: `assets/world_v4/prompts/ground-buried-slate-cobbles-v4-02.txt`
- Generator: built-in `image_gen`; copied byte-for-byte with no post-processing
  or re-encoding
- Original generated output:
  `C:\Users\wuwu6\.codex\generated_images\01a164d9-f083-7ce3-b3c9-0570850c7236\exec-86175614-5fff-4ece-b5ee-e314f3473783.png`
- Dimensions and native PNG mode: 1254 × 1254, 8-bit RGB (no alpha channel; opaque)
- SHA-256: `56c1c0dbcd5d5a6ea1bb88f48572da8c26649bf2b02923fda3b81c7ee7eef3d2`
- The project copy has the same SHA-256 as the generated output, confirming that
  its source pixels and PNG bytes were preserved.
- Visual source inspection suggests roughly 32–34 pavers across a full-width
  course and about 40 staggered courses. It reads as continuous small-sett paving
  and reaches the requested minimum density, though it falls short of the prompt's
  38–40-unit target. Treat this as a provisional source candidate pending the
  gameplay-camera scene review; do not describe it as integrated or accepted.

The existing material manifest still owns runtime texture selection and scale.
Check the paired ground at the 512-world-pixel tile size with the ordinary
gameplay-camera scene before describing either source as integrated or accepted.
No tests or QA suites were run for this source-only work.
