# Story bridge — historical ordinary presentation record

Historical snapshot captured 2026-10-23. This immutable record describes the
source state before the v5 expedition-ledger integration and subsequent source
changes. Its 20 PNGs, two renders and 107-input identity record are not evidence
of the current source or UI. Keep the images, logs and `source_snapshot.json`
unchanged as historical evidence. The newer bounded staged UI record is
[here](../expedition-presentation/source_snapshot.json): 18 PNGs across two
resolutions, with staged HUD, inventory, journal and outcome-report states.
Those frames do not record player actions, settlement, save/load, disk-fault
reproduction or QA. This record is not gameplay, QA or release acceptance.
Narrative/gameplay owners: [GAME_DESIGN.md](../GAME_DESIGN.md),
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md), and [AI_HANDOFF.md](../../AI_HANDOFF.md).

## Recorded output

Twenty PNGs from that historical source snapshot: ten each in `1280x720/` and
`1024x768/`. The two snapshot Godot
4.6.3 processes both exited 0 and each logged ten `STORY_PRESENTATION_FRAME`
entries with image result 0. No ERROR/WARNING lines were observed in their logs.
Backend: OpenGL 3.3 Compatibility on Intel Arc 140V. `source_snapshot.json` records
the engine, final logs/images, matching recipe, project-setting distinction and
107 matching source/mirror inputs. Source hashes that include tests do not mean
tests were executed; the identity list is inherited from the preserved art mirror
and does not cover every legacy/hero PNG.

| State | What was manually staged | Presentation reviewed |
| --- | --- | --- |
| `title` | Main shown without new-game input | New premise and menu copy |
| `prologue` | Presentation-only `_show_intro`, no reset/intro-save/scene transition | Alan recognition, first action and readable wrapped text |
| `village-dry` | No completed main quests | Dry source, water label and first-contract guidance |
| `village-trickle` | First main ID placed in completed list | Small static flow on preserved dry art; rationing label |
| `village-stable` | Six main IDs placed in completed list | Existing restored art, final supply/next-action label |
| `highway-bypass-pending` | First contract and existing field-action marker placed in memory; actor moved to `(3500,3510)` | Reused relay, matching E/field/HUD names and visible approach |
| `guild-contract` | First active contract staged; J opened directly | Goals, one-time reward wording, field action and actual stock |
| `journal-city` | Five completed main IDs and five discoveries staged; K opened directly | Five-of-six evidence, partial supply, wrapped story cards |
| `journal-ending` | Six completed main IDs and six discoveries staged; K opened directly | Ending recap and finite stable supply |
| `alan-opening` | Opening dialogue emitted directly, without NPC interaction/gift | Recognition and readable dialogue at both sizes |

Native gameplay camera offset/zoom 1.15 remain. Only smoothing is disabled.
Village actor stance is `(1380,970)`. Sixteen physics frames settle presentation
before freezing. Nothing follows from those staged completions about acceptance,
repair, hand-in, rewards, safe traversal or save behavior. No E/input, gameplay
actions, real NPC gifts, save/load, pacing, performance or QA runs were performed.
The real save's size and modification time remained unchanged; this does not
constitute save/load compatibility testing.

## Review and corrections

The parent inspected title/prologue, water states, first-action composition,
contract, both dialogue sizes and city/ending journals. Independent review first
inspected six contract/journal/dialogue frames across both sizes and found a
horizontal overflow in the narrow journal. The fixed final narrow city/ending
frames were then independently re-inspected: their right edge, close button and
wrapped story text remain visible, with vertical scrolling for long content.

The historical render review found a narrow journal overflow. The source fix
then used an expanding journal list, disabled horizontal scrolling, wrapped
equipment text and two equipment columns below 1180 viewport pixels (three above).
The column count updates when the viewport changes. Resize interaction and the
whole equipment catalogue were not exercised. The two `journal-before-width-*`
PNGs and `before-width-*.log` preserve the earlier nine-state render, not the
current source identity. No whole-game UI acceptance is implied.

Review also corrected optional-clue assumptions, missing sampling mechanics in
NPC instructions, a stale ending journal premise and contradictory factory
release wording. Required field actions now precede optional reading in guidance.
Unknown locked late-chapter journal entries suppress their location/goal detail
in source; this lock state is not separately captured here.

During integration a worker mistakenly deleted NPC data and restored a HEAD copy.
The parent reconciled it against the pre-story mirror whose hash matches the
earlier 107-input checkpoint, recovered `voice_enabled: false`, and confirmed all
six NPC non-dialogue fields match that baseline. New dialogue remains. No real
save or original art was overwritten.

## Resume on another platform

Copy the project to an external presentation-only directory and configure a
dedicated custom user directory. Keep the real `project.godot` and save untouched.
Install [StoryPresentationPreview.gd.txt](StoryPresentationPreview.gd.txt) as
`StoryPresentationPreview.gd` on a Node scene named `StoryPresentationPreview.tscn`.
Synchronize the listed inputs and preserve the isolated project settings.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --log-file C:/absolute/wide.log `
  res://StoryPresentationPreview.tscn -- --story-output=C:/absolute/output
```

Repeat with 1024x768 and another output directory. Engine version must be verified
before rendering. The recipe intentionally stages in-memory state; never run it
as a player journey or treat its screenshots as executed tests.

繁體中文：這是 2026-10-23 舊來源狀態的劇情與介面呈現紀錄，共二十張圖；
其後已接入 v5 出征收穫／撤離結算來源，因此這些圖不代表目前版本。原有圖片、
記錄與 107-input 來源清單保持不變，作為歷史證據。新版的限定狀態介面呈現已另存為
[18 張出征畫面紀錄](../expedition-presentation/source_snapshot.json)，不包含實際遊玩、結算、讀寫存檔、
故障重現或 QA。
當時供水、任務與線索都是手動設定，沒有實際接任務、按 E 修理、打怪、交付或讀寫存檔。
當時窄視窗手記右側裁切已修正；完整流程、存檔相容與時間長度仍未驗證。
