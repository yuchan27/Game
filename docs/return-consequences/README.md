# Return receipts and ending consent — ordinary presentation record

Historical source snapshot after the subsequent
[arrival-briefing integration](../arrival-briefing/README.md). Its final PNGs,
logs and source hashes remain unchanged; the later changes touch SceneRouter,
SceneEntrance and HUD transition handling.

2026-10-23. The continuation makes the existing expedition result readable after
return and keeps the final account consistent with the City name-publication
choice. Existing art, quests, rewards, ledger and UI are retained. The user
deferred tests/QA. These are staged production views, not gameplay acceptance.

Rules: [GAME_DESIGN.md](../GAME_DESIGN.md). Story:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Final record

Twenty-two final PNGs: 11 each at `1280x720/` and `1024x768/`. Both final Godot
4.6.3 render processes exited 0, with 11 `RETURN_PRESENTATION_FRAME` entries and
image result 0 each. Final logs have no observed ERROR/WARNING lines. Backend is
OpenGL 3.3 Compatibility on Intel Arc 140V. Native camera zoom 1.15/offset is
retained; smoothing is disabled for capture.

[source_snapshot.json](source_snapshot.json) records final images/logs/recipe
hashes and 112 matching listed source/mirror inputs, inherited from the previous
guidance list. This is bounded identity evidence, not an exhaustive manifest.
Test-source hashes identify files; no tests ran. The external mirror retains its
own project settings and `R17-Ordinary-Art-Preview-20261023` user directory. Real
save metadata stayed 1203 bytes / `1792682904815624900` ns. No real-save payload
was read or written for this presentation.

| View | Directly staged state | Presentation scope |
| --- | --- | --- |
| `partial-return` | Highway A escort committed; relay incomplete | Named step receipt and same-outing continuation |
| `empty-return` | No new complete campaign step | No invented step receipt; existing progress is not rolled back |
| `lost-carry` | Highway A banked; Highway B choice/carry only in lost result | Both provisional steps named as needing to be redone |
| `side-return` | Factory side field action recorded in extracted result | Named alarm-node outcome, original hand-in still separate |
| `side-loss` | Rescue relay appears only in lost result | Named relay action marked unextracted |
| `report-journal` | Same partial result assigned as last result | Existing K foldout expands full report, marked as historical state |
| `private-ending` | Completed main IDs plus restricted-family-name choice | Guild-only full names, public districts/lines/household IDs |
| `public-ending` | Completed main IDs plus consented-public-name choice | Public full names/household IDs, same finite-water ending |
| `legacy-ending` | Completed main IDs, no saved consent choice/markers | Neutral archive prose; no fabricated choice acknowledgment |
| `private-journal` | Restricted choice and final chapter markers | K premise shares the actual ending text and consent scope |
| `unsaved-handin` | Completed state; text builder receives `saved = false` | Explicit in-memory-only warning and retry instruction |

The recipe assigns quest/route/completed IDs, choice/field markers and last-result
state in memory. Ending fixtures include the two required City/Facility
discoveries while leaving the first four optional clues unread. These fields are
assigned, not earned through a journey or accepted by loading a save. Simulation
is frozen. Read-only `return_report()`, `action_receipt()`,
`quest_completion_report()` and existing dialogue/K presentation are invoked.
The K foldout is expanded directly. No `settle_expedition()`,
`complete_active_quest()`, mission input, actual choice, reward, extraction,
death, save/load, IO fault, timing/performance or QA scenario is performed.
`unsaved-handin` is a staged message, not an actual storage failure.

## Source integration and review limits

- The existing single `ExpeditionLedger.last_result` remains the storage owner.
  No new save field/version, autoload or growing history log was added. Reading
  the K report does not settle a ledger, grant an item or write a save.
- `CampaignProgress` builds bounded action receipts and partial/full return
  prose from the same quest definitions. `GameState` still owns settlement; only
  successful extraction merges steps and advances an outing. Death keeps prior
  banked steps and discards the current run's steps. These transitions have
  source review only in this continuation.
- `quest_completion_story()` supplies both final hand-in and K premise. The fixed
  text no longer always publishes Liu Qing. A saved City choice supplies its
  exact description; a legacy record without a choice stays neutral.
- Actual hand-in now checks the existing autosave return value. Failure keeps
  the in-memory result and displays the same explicit warning as a failed return
  save. Awarding/deduplication, actual IO failure and retry were not exercised.
- Initial report frames put step names below the visible dialogue area.
  `before-receipt-position-*` retains that layout. Final receipts put the named
  action before general rules, and report footers describe scrolling/closing/K
  rather than an NPC next page. Long reports intentionally use the existing
  scroll container; some content remains below its visible area.
- `before-repeated-empty-summary.png` shows duplicated no-progress prose;
  the final builder avoids that repetition. `before-required-clue-staging.png`
  shows an earlier fixture that omitted required discoveries; this was a capture
  setup correction, not a confirmed game defect.

Parent inspection covered targeted final receipts, side outcomes, public/private/
legacy ending copy, K and the unsaved message at both sizes. The wide partial
receipt and narrow lost-carry frame show their named steps before scrolling.
The narrow expanded K report shows its continuation text. Full dialogue scroll
tails, lower K catalogue, all input/focus/close paths and arbitrary resizing are
unreviewed. Graph indexing/coverage requests failed with `Transport closed`;
current source and literal caller searches supplied the evidence. Existing
workers remained errored with exhausted credits, so final review is parent-only.

## Reproduce

Use an external copy with the separate user directory above. Synchronize the
listed inputs while preserving its isolated `project.godot`. Install
[ReturnConsequencesPreview.gd.txt](ReturnConsequencesPreview.gd.txt) as
`ReturnConsequencesPreview.gd` on a Node scene `ReturnConsequencesPreview.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ReturnConsequencesPreview.gd" id="1"]

[node name="ReturnConsequencesPreview" type="Node"]
script = ExtResource("1")
```

Verify the discovered engine reports 4.6.3. Use absolute paths:

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1200 `
  --log-file C:/absolute/wide.log res://ReturnConsequencesPreview.tscn `
  -- --return-output=C:/absolute/output
```

Repeat at 1024x768 with a separate output/log. Inspect process completion,
expected frames, source identity and actual PNGs. Older guidance, campaign,
draft, expedition, story and City captures retain their historical hashes.

繁體中文：本輪補上返村／死亡行動明細、部分撤離的接續提示、K 上次回報，
並讓結局尊重都心的姓名公開選擇。22 張圖都是預置狀態；沒有實際結算、交付、
領獎、存讀檔或磁碟故障重現，不能視為通關、相容性或 QA 通過。
