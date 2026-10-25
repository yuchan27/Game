# Village entrance and trade-court camera checkpoint

Historical source snapshot: later coach scale, Wasteland/WorldBackdrop behavior
and highway-road changes are recorded at
[`../convoy-court/README.md`](../convoy-court/README.md). Preserve this batch's
26 images and hashes; they do not verify the current working tree.

2026-10-23. **Ordinary isolated art rendering, not QA or release acceptance.**
Runtime/source contracts and the review boundary:
[`../../entrance_readability.md`](../../entrance_readability.md).

- Thirteen staged views at each of 1280x720 and 1024x768: Guild approach and east
  clearing; six route gates; nearest forge context; Village M map; unchanged
  Guild contract board, Guild M map and original highway-convoy control. Total: 26 PNGs.
- Godot 4.6.3 (`7d41c59c4`), Compatibility/OpenGL 3.3 on Intel Arc 140V.
  Both final ordinary processes exited 0. Their complete logs each record thirteen
  frames and contain no observed script/engine error lines.
- `source_snapshot.json` records 102 source inputs matching the isolated copy,
  exact frame/log hashes, recipe identity and intentionally isolated project
  settings. A test script's hash records source identity only, not execution.
  Legacy PNGs are outside this input record; all v4 PNGs include inactive sources.
- Native Camera2D limits, zoom 1.15 and player offset remain. The scene settles
  four physics frames before the capture is frozen. HUD remains visible except
  for its normal fullscreen-map/modal visibility. No gameplay input is sent.
- Dedicated userdata: `R17-Ordinary-Art-Preview-20261023`. No real save is loaded
  or written. Quest/map conditions are staged in memory.

## Reproduce on another platform

Copy `../GateEntrancePreview.gd.txt` into an isolated project as
`ArtPreviewV4.gd`, attached to a Node scene. Preserve project settings apart from
an explicit dedicated custom-user directory. Sync source/asset bytes without
overwriting those isolation settings.

```text
<godot> --path <isolated-project> --rendering-method gl_compatibility
  --audio-driver Dummy --resolution 1280x720 --log-file <absolute-log>
  res://ArtPreviewV4.tscn -- --art-output=<absolute-directory>
```

Repeat at 1024x768. Optional `--art-view=east-gate-approach` or a comma-separated
list selects views. `ENTRANCE_SOURCE` logs actual crop/contact selection;
`ENTRANCE_CONTEXT` logs the existing HUD hint's text and effective visibility.

## Review scope

The first iterations exposed equal generic Guild/east gates, an unused road
endpoint below the threshold, duplicate world badges, E text over piers/the hero,
and a context panel covering lower architecture. Final source uses the tall Guild
arch, separated east route, connected trade-court ground and existing HUD hint
row. Village paving continuity now keeps a central street spine; two registered
wall segments frame the house-to-Guild frontage. Their source rectangles leave
the opening/main road clear, and existing saved-position escape applies. This
does not establish physical traversal. Parent inspected complete final Guild/east and map frames, with independent
review of both sizes. This is a bounded local improvement, not acceptance of the
whole world's composition. Final independent review found the attached broken
frontage and lane core clearer at both sizes, with no visible aperture blockage;
the larger east quarter and convoy still show isolated focal props and broad
empty ground. Generic route gates, empty/sparse quarters, bright
base tufts and peripheral HUD/edge occlusion remain.

No walking/collision, transition input, quest completion/reward, save migration,
frame-time/memory comparison, Windows export or release verification. Earlier
`hubs/`, `road-and-convoy/`, `chapter-sites/` and `current-production/` snapshots
remain immutable historical evidence and do not cover these shared code changes.

繁體中文：本批 26 張一般遊戲鏡頭紀錄公會入口、東側街區與底部互動提示的修改，
不是通關、碰撞、存讀檔或效能測試。能順利渲染不代表整體美術已經驗收。
