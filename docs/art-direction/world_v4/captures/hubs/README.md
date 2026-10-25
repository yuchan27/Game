# Hub and material-contact camera checkpoint

Historical source snapshot: later shared Player/HUD/Interactable, ground/map and
Village entrance/layout changes are recorded at
[`../gate-entrances/README.md`](../gate-entrances/README.md). Preserve this batch's
40 frames and source hashes; they do not verify the current working tree.

2026-10-23. **Ordinary isolated art rendering, not QA or release acceptance.**
This batch supersedes the earlier hub diagnostic images, not their historical
source records. Runtime contracts/provenance: `../../hub_presentation.md`.

- 20 views at each of 1280x720 and 1024x768: 17 Village/Guild service, route,
  frontage and dry/restored-cistern views plus 3 representative Wasteland controls.
- Godot 4.6.3 (`7d41c59c4`), Compatibility/OpenGL 3.3 on Intel Arc 140V.
  Final wide/narrow processes exited 0; their complete saved logs contain no
  observed script/engine errors. A successful exit alone was not acceptance:
  earlier failed draft renders were discarded as evidence after source repair.
- Native Camera2D remains enabled, including its limits, 1.15 zoom and player
  offset. Each art state settles four physics frames before pausing/rendering.
  The HUD remains visible. Positions/states are deliberately staged, not played.
- 101 matching source inputs, exact frame dimensions/hashes, recipe and isolated-project
  settings are in `source_snapshot.json`. Hashing a test script proves identity
  only. No tests, QA runner, validator, interaction or field action was executed.
- Dedicated userdata: `R17-Ordinary-Art-Preview-20261023`. No real saves loaded
  or written. The completed-cistern frame manually sets `facility_memory`.

## Portable rendering

Copy `../HubPreview.gd.txt` to an isolated project as `ArtPreviewV4.gd`, attached
to a Node scene. Preserve the original project settings apart from a dedicated
custom userdata directory. Sync source files/PNG bytes without overwriting that
isolation. Launch the ordinary scene with:

```text
<godot> --path <isolated-project> --rendering-method gl_compatibility
  --audio-driver Dummy --resolution 1280x720 --log-file <absolute-log>
  res://ArtPreviewV4.tscn -- --art-output=<absolute-directory>
```

Use 1024x768 for the narrow batch. Optional `--art-view=guild-contract` or a
comma-separated list selects views. The runtime station diagnostics show the
actual AtlasTexture rectangles and contact binding; the controls log actual
route IDs, preventing a filename from masquerading as route evidence.

## Review and remaining defects

Parent inspected the wide camera set during production and representative narrow
frames; a separate reviewer inspected all 20 narrow frames before the final
Guild prompt placement correction. That review found moderate improvement in
the golden highlights and sprite/earth contact, stronger residential context,
and clear dry/restored water states. It did **not** approve complete cohesion.
The review found the contract prompt crossing the hero; the final correction
moves it to the board's right, with parent and reviewer reinspection in both sizes.

Open at this historical checkpoint: identical nearby Village guild/east gates, some bright yellow base
tufts/debris, sparse circulation/repeated paving, and secondary gate labels or
frontage corners behind the fixed HUD or viewport edge. These are known further
composition/UI tasks. A whole-world or player acceptance claim is unsupported.

No walking/collision clearance, quest completion/reward, save migration/reload,
frame time, memory growth, Windows export or release behavior was verified.
The remaining full production ledger stays active in `docs/PRODUCTION_STATUS.md`.

繁體中文：本批共 40 張一般遊戲鏡頭，保留完整 HUD 與原生鏡頭限制。金色高光、
腳邊接地和聚落感有改善，但入口重複、地面單調與部分邊角遮擋仍未解決。水槽
完成狀態是美術設定，沒有實際通關、存讀檔、碰撞或效能測試。
