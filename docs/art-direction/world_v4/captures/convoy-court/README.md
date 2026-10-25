# Coach-stop composition camera checkpoint

Historical shared-source checkpoint: later regional court data, shader and art
are recorded in [regional-courts](../regional-courts/README.md), including a
current coach story control. This folder retains its original snapshot identity.

2026-10-23. **Ordinary isolated art rendering, not QA or release acceptance.**
Contracts/review: [`../../convoy_courtyard.md`](../../convoy_courtyard.md).

- Seven staged views at each of 1280x720 and 1024x768: old northwest overview,
  actual story approach, south/west/north approaches, shelter forecourt and M map.
  Total 14 PNGs. No movement or interaction inputs are sent.
- Godot 4.6.3 (`7d41c59c4`), Compatibility/OpenGL 3.3 on Intel Arc 140V. Both
  final processes exited 0; each log records seven frames and no observed
  script/engine error lines. Clean rendering is not artistic acceptance.
- `source_snapshot.json` records 102 source inputs matching the isolated copy,
  recipe/frame/log hashes and intentionally different custom-user settings.
  Test-source hashes are identity only. Legacy PNGs are outside this record;
  included v4 PNGs may be inactive historical candidates.
- Native Camera2D limits/offset and zoom 1.15 remain. Sixteen physics frames
  settle the existing 0.2-second occlusion cadence before freezing the art state.
  Old overview records coach alpha 0.32; clear story approach records 1.0.
- Dedicated userdata: `R17-Ordinary-Art-Preview-20261023`. Real saves are not used.
  Saved-position fallback is not staged/executed by this recipe.

## Reproduce

Copy `../ConvoyCourtyardPreview.gd.txt` to an isolated project as `ArtPreviewV4.gd`,
attached to a Node scene. Keep explicit dedicated custom-user settings while
syncing source/asset bytes. Launch:

```text
<godot> --path <isolated-project> --rendering-method gl_compatibility
  --audio-driver Dummy --resolution 1280x720 --log-file <absolute-log>
  res://ArtPreviewV4.tscn -- --art-output=<absolute-directory>
```

Repeat at 1024x768. Optional `--art-view=convoy-story-approach` or a comma-separated
list selects views. Logs record route, actor/camera, coach source scale/bounds,
nearby architecture, fade alpha and effective HUD hint visibility.

## Review boundary

Parent inspected paired story/forecourt/map frames and the old overview;
independent review inspected both sizes and rechecked corrected E/wall framing.
The local story approach reads as a coach stop with clearer proportions,
shoulder and forecourt. Other views frame only part of the stop with peripheral
or HUD cropping; this is not all-angle or whole-world acceptance.

Earlier `gate-entrances/` (26), `hubs/` (40), `road-and-convoy/` (28),
`chapter-sites/` (42) and `current-production/` (24) are immutable historical
source snapshots and do not cover this coach/route/runtime state.
No QA, collision walking, saved entry/save-load, quest/reward, comparable
performance or exported build was verified. Full production remains open.

繁體中文：本批 14 張一般鏡頭確認巴士比例、路肩、驛站前庭與提示的局部呈現。
未操作 E、移動、任務或存讀檔；主要調查鏡頭的改善不代表所有角度或整體遊戲完成。
