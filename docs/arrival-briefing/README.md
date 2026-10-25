# Arrival context — ordinary presentation record

Historical after the [contract readiness integration](../contract-readiness/README.md).
Preserve these images/logs/source hashes; the shared journey hint and HUD changed.

Rendered 2026-10-23; record updated 2026-10-24 (Asia/Taipei). Arrival now states the current outing and next action, sharing the
existing HUD/J journey hint. Matching-route checks prevent showing a campaign
outing as though it belonged to another route. Village/Guild titles likewise
show the next step after the existing router settlement. No new state, rewards,
save format, scene or autoload was introduced.

`SceneEntrance.gd` keeps the native curtain and existing skip keys, expands the
subtitle to a wrapped 112px area at 18px font, and clamps dwell to 0.65–3.0s
according to text length, plus 0.25s reveal/fade. `HUD.gd` hides notices and
defers polled/unhandled hotkeys while `SceneRouter.is_transition_pending()`.
This preserves source ordering; actual pause/input and travel are unexercised.

## Presentation evidence

Ten final PNGs, five each at 1280x720 and 1024x768:

- `highway-start`: first outing, escort next.
- `highway-carry`: second outing, staged covered-route choice and active carry.
- `wrong-route`: Highway contract while entering the marsh.
- `facility-reserve`: last outing, supply test/defense staged complete, choice next.
- `village-continue`: partial Highway A return state, escort already banked.

Both final Godot 4.6.3 Compatibility renders exited 0; each logged five frame
records with image result 0. No ERROR/WARNING lines were observed. Parent review
inspected targeted frames at both sizes. This supports the inspected text/layout,
not all twelve outing titles or arbitrary resolutions.

[source_snapshot.json](source_snapshot.json) records images/logs/recipe and 112
matching listed source/mirror inputs. This is bounded identity, not an exhaustive
asset manifest. The external mirror retains its separate project settings and
`R17-Ordinary-Art-Preview-20261023` user directory. The real save's metadata is
unchanged (1203 bytes / 1792682904815624900 ns); its payload was not read/written.

The recipe directly stages quest/outing/run state and the transition-active flag,
instantiates the destination scene while simulation is paused, then calls the
read-only router text builder and native `arrive()`. The tween is paused at full
reveal for capture. Wasteland initialization reuses the staged ledger and creates
ordinary scene nodes. No router travel, player input, action completion, reward,
settlement, save/load, collision, performance, QA or timed animation acceptance
was performed. No claim of a successful load/migration follows from the fixtures.

Post-capture copy correction: the wrong-route guidance now says quest kills on
that route do not count while recovered salvage can still return to storage. The
`wrong-route` images and source snapshot above preserve the earlier wording as
historical evidence; they do not show this updated sentence.

`before-transition-notice-staging.png` preserves the earlier composition with
a floating notice behind the title. That early fixture omitted the router's
active flag; it is not a recording of actual travel. Source inspection also found
HUD notice/polled-input paths did not consult the router. Both the source guard
and fixture were corrected. The earlier log is retained separately.

Graph indexing/coverage failed with `Transport closed`; current source/caller
reads supplied the evidence. Workers remain unavailable due to exhausted credits;
this integration and visual review are parent-only. No new art, cleanup, commit
or push was performed. User-deferred QA remains pending.

## Reproduce

Copy [ArrivalBriefingPreview.gd.txt](ArrivalBriefingPreview.gd.txt) into an
isolated mirror as `ArrivalBriefingPreview.gd`, attach it to a Node in
`ArrivalBriefingPreview.tscn`, and synchronize the listed inputs without
overwriting isolated `project.godot`. Verify the discovered engine version.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1200 `
  --log-file C:/absolute/wide.log res://ArrivalBriefingPreview.tscn `
  -- --arrival-output=C:/absolute/output
```

Repeat at 1024x768 with separate output/log paths. Preserve earlier
[return/consequence evidence](../return-consequences/README.md), which is now
historical. Continue from [AI_HANDOFF.md](../../AI_HANDOFF.md); rules remain in
[GAME_DESIGN.md](../GAME_DESIGN.md).

繁體中文：進場交代已接上趟次和當前行動，並處理通知遮蔽與轉場快捷鍵。
十張圖是隔離副本的預置畫面；未執行實際轉場、操作、存讀檔或 QA。
