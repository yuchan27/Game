# Field drafts — ordinary presentation record

Historical after the authored campaign integration. Its original images, logs and
source snapshot remain immutable; current presentation is recorded in
[the campaign record](../campaign-presentation/README.md).

2026-10-23. The optional run-only draft is integrated in source. This record
covers presentation in an external isolated mirror, not gameplay or save/load
acceptance. The user deferred tests/QA. No new art was generated.

Rules and status: [GAME_DESIGN.md](../GAME_DESIGN.md). Narrative:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Final record

Fourteen final PNGs: seven in `1280x720/`, seven in `1024x768/`. Both final
Godot 4.6.3 processes exited 0 with seven `DRAFT_PRESENTATION_FRAME` entries
and image result 0. No ERROR/WARNING lines were observed in the final logs.
Backend: OpenGL 3.3 Compatibility on Intel Arc 140V.

[source_snapshot.json](source_snapshot.json) records matching recipe hashes,
108 matching listed source/mirror inputs, final image/log hashes and the panel
geometry printed by the recipe. The manifest inherits the prior expedition
mirror list; it does not cover every project asset. Test-source hashes are
identity records, not executed checks. Real project settings were not written;
the external copy uses `R17-Ordinary-Art-Preview-20261023` as its custom user
directory. Real-save metadata stayed 1203 bytes / `1792682904815624900` ns.
Unchanged metadata is preservation evidence, not a compatibility test.

| View | Manually staged state | Visible presentation |
| --- | --- | --- |
| `first-offer` | Early-site pending ID; no permanent or run perks | Three packages, initial numerical changes, tradeoffs and defer/expiry rules |
| `second-offer` | Permanent arc/pierce Lv.1 plus one earlier arc choice; late-site pending | Existing stack tag, arc damage 24→32 and pierce 2→3 if chosen again |
| `hybrid-inventory` | Arc and salvage choices plus haul assigned directly | Two-package summary separate from permanent equipment and bank/haul |
| `claimed-site-approach` | First cache placed in permanent discoveries; no draft chosen | Claimed cache remains available for tuning, with updated E prompt |
| `claimed-site-map` | Same claimed-cache state; M opened directly | Both authored tuning opportunities remain visible on the route map |
| `legacy-inventory` | Legacy-trip flag and no active ledger | Old trip retains its existing rules; no temporary draft is assigned |
| `expired-report` | Empty active ledger, a result with two old choices and permanent Lv.1 assigned | Report says run tuning is removed; permanent chip level remains |

The recipe assigns pending/selected/permanent state in memory. It does not call
offer/choose, collect loot, fight, extract, recover from death, hand in a quest,
save or load. The ordinary Wasteland scene creates an in-memory run as it loads.
Calling the presentation signal or showing the result dialogue is not execution
of the underlying action. These views do not prove idempotence, effects, expiry,
save migration, guard clearance, route traversal, balance, timing or performance.

Actors are staged near the first highway cache, near the second for its offer,
or at `(1380,970)` in the village. Actor/enemy physics is disabled for capture;
the native camera retains zoom 1.15 and its offset, with smoothing disabled.
No claim about physically reaching these positions follows from a screenshot.

## Reviewed defects and corrections

Initial captures showed an overflowing panel and a repeated-package badge that
wrapped vertically to almost zero width. `before-layout-*` images/logs preserve
that state. The badge now owns a separate wrapped row, and the cards sit in a
clipped, scrollable viewport. Diagnostic output showed the panel retaining a
transient height around 2983 even after its minimum had fallen to 660: wrapped
labels were initially measured before receiving their final width. Two deferred
layout passes after offer/resize clamp the panel to its intended viewport size.

Final cards use three columns at the two reviewed widths, within a 460px-high
panel. At 1280×720 the panel is `(120,130,1040,460)`; at 1024×768 it is
`(20,154,984,460)`. Both first/second offers report these bounds in the logs.
Smaller widths fall back to one scrollable column in source; that fallback and
interactive resizing were not captured or exercised.

The initial world E label also stayed at its old recovery text despite the
point's changed status. `Interactable.prompt` now updates the visible label;
the final approach views show tuning text. No reach or interaction test follows.

The parent inspected offers, hybrid inventory, claimed-site approach/map and
expiry report. Independent review inspected first/second offers at both sizes
plus the narrow approach and expiry report: all three choice buttons, rule text,
effects and tradeoffs fit in those final frames, with no remaining visible
defect identified there. Long inventory content remains scrollable; complete
catalogue/menu coverage, focus navigation, pause ownership, actual selection,
resumption and full gameplay acceptance remain open.

## Reproduce the presentation

Use an external project copy with the dedicated custom user directory named
above. Preserve the real project/save and synchronize the listed inputs.
Install [DraftPresentationPreview.gd.txt](DraftPresentationPreview.gd.txt) as
`DraftPresentationPreview.gd` on a Node scene `DraftPresentationPreview.tscn`.
Discover and verify Godot 4.6.3 before rendering.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1800 `
  --log-file C:/absolute/wide.log res://DraftPresentationPreview.tscn `
  -- --draft-output=C:/absolute/output
```

Repeat at 1024x768 in another output folder. Inspect expected files and logs as
well as process completion; a frame ceiling alone cannot establish success.
Old story/expedition/art snapshots remain immutable historical records.

繁體中文：這批十四張圖檢視三選一調校、疊加、混合搭配、已回收據點標記與卸載
回報。已修正第二次選擇直排、視窗超高和舊 E 提示。所有能力與結果狀態都是手動
設定，沒有實際選取、戰鬥、撤離、死亡或存讀檔；這些仍待之後正式驗收。
