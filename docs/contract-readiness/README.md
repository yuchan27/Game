# Contract requirements — ordinary presentation record

Historical snapshot. The newer [chapter-resolution record](../chapter-resolution/README.md)
includes later GameState/HUD/router/story-data edits. This record's hashes and
captures remain unchanged and do not validate those changes.

2026-10-24. Active requirements now have one read-only source in
`GameState.active_quest_requirements()`. `is_active_quest_ready()`, the J checklist,
and G's displayed active main contract use these rows. The prior G count display
read only banked inventory/counters, unlike J's run-inclusive numbers; this is a
source-confirmed mismatch. The new rows expose stock plus haul and current-run
kills. Optional discoveries remain nonblocking and are listed separately.

J shows the current quest name, actionable shortfall, checklist and delivery
button before long outing details. Final-outing guidance checks remaining
mandatory goals before directing return; early extraction is still allowed.
No original objective amount/reward, save format, marker or hand-in mutation was
changed. Required field actions still depend on the old acceptance marker;
authored outings still depend on the optional campaign marker. A lost-but-read
required clue still needs successful extraction on its original route.

## Evidence

Sixteen staged PNGs, eight each at 1280x720 and 1024x768:

| State | Staged presentation |
| --- | --- |
| `city-bank-short` | Two outings banked; one of two required chips missing |
| `city-provisional` | Last outing done in field; 3 banked + 2 run kills, 1 banked + 1 haul chip; return still needed |
| `city-atlas` | Same provisional main-contract numbers through G |
| `city-clue-pending` | Required clue read but uncommitted at the hub |
| `factory-boss` | Outings and other goals done; Boss missing; optional clue unread |
| `legacy-ready` | Old active Highway quest without field/campaign marker; original goals met |
| `city-ready` | Authored outings and original goals banked; delivery button enabled |
| `city-last-outing-short` | Final outing done in field; a chip still missing before return |

Both final Godot 4.6.3 Compatibility processes exited 0, eight frame records and
image result 0 each, with no observed ERROR/WARNING lines. The
[source snapshot](source_snapshot.json) records the listed source/mirror inputs,
recipe, logs and images. The inherited list is bounded, not all assets. Parent
inspection covered selected checklist, provisional/atlas, Boss and legacy states
at both sizes. Native scroll areas retain longer descriptions below the viewport;
lower catalogue content and actual scrolling/input are unreviewed.

The recipe assigns quest/run/inventory/discovery state directly, instantiates
Village or Wasteland with simulation paused, and opens existing J/G presentation.
Wasteland initialization reuses the staged ledger and creates scene nodes. Logs
include read-only readiness/hint text for those fixtures. No action, choice,
hand-in, reward, extraction, death, save/load, migration, collision, pacing,
performance or QA suite ran. `legacy-ready` is not an old save loaded from disk.
Readiness extraction has source review and these staged observations, not full
behavioral or compatibility acceptance. User-deferred QA remains pending.

The mirror uses `R17-Ordinary-Art-Preview-20261023` user data; its project settings
are separate. The real save payload was not read/written; metadata stayed
1203 bytes / 1792682904815624900 ns. Initial graph calls failed with `Transport closed`. Reindexing later returned
indexed, but final coverage still flags `metadata_changed` for all seven cited
source/data paths; current source/caller reads remain authoritative. Existing workers have
exhausted credits; current integration/review is parent-only. No new art, cleanup,
commit or push was performed.

## Reproduce

Use an isolated mirror, preserving its project settings. Synchronize listed
inputs and install [ContractReadinessPreview.gd.txt](ContractReadinessPreview.gd.txt)
as `ContractReadinessPreview.gd` attached to a Node in
`ContractReadinessPreview.tscn`. Verify the discovered engine version, then run:

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1200 `
  --log-file C:/absolute/wide.log res://ContractReadinessPreview.tscn `
  -- --contract-output=C:/absolute/output
```

Repeat at 1024x768 with distinct output/log paths. Previous
[arrival](../arrival-briefing/README.md) and
[return](../return-consequences/README.md) snapshots retain historical hashes.
Continue from [AI_HANDOFF.md](../../AI_HANDOFF.md).

繁體中文：J/G 的目前主線條件與交付判定共用資料，分清庫存、本趟成果及選讀
線索；最後一趟完成後會提示仍缺的必需項目。十六張圖均為預置狀態，未實際
交付、領獎、載入舊存檔或執行 QA，不能當成完整通關與相容性驗收。
