# Transactional load and feedback

Historical source snapshot. [Story continuity](../story-seams/README.md) records
later runtime-generation/preflush and NPC changes; its exact checkpoint adds one
transient field (36 now). Preserve these original eight images and hashes.

2026-10-24. Source-integrated correction for the load/scene consistency P1.
Gameplay, real payload IO and fault acceptance remain deferred by user scope.
[Snapshot](source_snapshot.json) identifies five product-file changes,112 matching
listed source/mirror inputs, the recipe and eight ordinary presentation PNGs.

## Problem and resulting behavior

Previously SaveManager applied the save before queuing scene travel. Router
restored scene/spawn alone on a reported scene error; loaded inventory, route,
quest and run state remained against the old runtime. Main also freed its title
and HUD closed pause as soon as the request returned. This was confirmed in
source, not an observed player-loss or reproduced fault.

| API | Contract |
| --- | --- |
|`SaveManager.load_game(true, show_notice, path)`|Parse/checksum/schema validation first. True means the load request was accepted; live state has not yet been applied. Immediate false is a rejection and does not emit completion.|
|`SaveManager.load_finished(succeeded)`|Eventual outcome after native scene request and curtain. Main/pause recover their controls on failure; F9 and load_or_new use the same default routed path.|
|`SaveManager.load_game(false, ...)`|Existing synchronous data-only apply/notification remains for compatibility. It performs no scene transaction. Production Main now uses the routed path.|
|`GameState.capture_runtime_state` / `restore_runtime_state`|Trusted internal exact-state checkpoint, separate from the serialized save schema. No validation/migration/normalization is replayed during restore.|

Router's load-specific queue bypasses extraction travel gates without cancelling
the old run/death state. After pause and cover it checkpoints, silently applies,
then chooses the normalized destination (HP0 still means Village clinic). There
is no await between checkpoint/apply/native request. Destination `_ready` sees
loaded state. A returned native error restores the checkpoint before releasing
the cover and original pause state; it does not save, extract or publish candidate
scene/state signals.

All35 mutable GameState fields are covered, plus the existing expedition object's
four raw fields: active, last_result, legacy_trip and uncommitted_clues. Death
generation/death_pending, exact ammo-spend bookkeeping and derived counters are
included. Containers are deeply copied and the expedition object is retained.
`load_save_data(..., false)` also suppresses HP0 loss-settlement signals.

On success, Router awaits native scene_changed, republishes the loaded state to
the new scene, performs the existing non-title autosave, finishes the entrance,
then releases its transition and emits completion. Campaign choice/draft sync
retains its existing transition-finished ordering. The successful-load notice
does not overwrite an autosave-failure warning. Base64/SHA256 wrapping, v1-v4
migration, v5 fields/normalization and all five autoloads remain.

Main keeps its title until scene replacement and disables continue/new-game
while pending. Pause keeps its panel with inline status and disables its actions
until failure restores them; success replaces the old scene/HUD. Display helpers
are free of payload IO. An early draft connected Router from SaveManager._ready;
review removed that later-autoload dependency before rendering. Connection is
now lazy, immediately before the accepted request is queued.

## Evidence and boundary

Two final native Godot4.6.3 renders completed: narrow command chunk a46e24 exit0;
wide session45332 exit0. Each log has four successful frame records and no
observed ERROR/WARNING lines. [Narrow](narrow.log) / [wide](wide.log).
Parent directly opened all eight full-viewport PNGs: title720x600 and pause480x520
fit both supported viewports; status text and controls remain inside the panels.
Independent Luna/max source review covered destinations, signal/pause/death-timer
ordering, checkpoint fields and returned-error branches; no remaining source
blocker was identified in that bounded scope.

| Staged UI |1024x768|1280x720|
| --- | --- | --- |
|Title pending|[Image](1024x768/title-load-pending.png)|[Image](1280x720/title-load-pending.png)|
|Title failed|[Image](1024x768/title-load-failed.png)|[Image](1280x720/title-load-failed.png)|
|Pause pending|[Image](1024x768/pause-load-pending.png)|[Image](1280x720/pause-load-pending.png)|
|Pause failed|[Image](1024x768/pause-load-failed.png)|[Image](1280x720/pause-load-failed.png)|

Fixture [script](LoadConsistencyPreview.gd.txt) and [stub](LoadConsistencyPreview.tscn.txt)
run only in the isolated custom user directory R17-Ordinary-Art-Preview-20261023,
using an absolute `--load-output=` and Compatibility rendering. Copy without
`.txt` to a separate mirror; do not change source project.godot or overwrite this
historical output. Main/Village actors are disabled before entry; local pending/
failure and cached has-save flags are staged in RAM. Title's ordinary isolated
file-existence lookup is metadata only. No load request/completion/checkpoint/
rollback/real payload, input, travel, settlement, migration, autosave fault,
gameplay, performance, export or QA ran. Rendering parses/loads the current
autoloads, but does not exercise their transaction branches. Real-save stat
remains1203bytes/1792682904815624900ns; payload unread/unwritten.

**Boundary:** rollback handles native scene-request error returns. If the request
returns OK but destination `_ready` throws or has arbitrary partial side effects,
there is no separate readiness/recovery protocol. Do not claim that case covered.
Deferred acceptance still needs v5 same-run/custom-path success; v1-v4/HP0
normalization; native missing/invalid scene error with exact original state and
pause; invalid payload without mutation; autosave failure warning; and actual
Main/pause/F9 input. The full production objective remains open.

繁體中文：已接入讀檔請求／完成區分、失敗狀態回復與可重試介面；八張圖只驗看
預置呈現，未實際存讀檔或注入錯誤。原生換場景回報失敗與場景內程式例外的範圍不同。
