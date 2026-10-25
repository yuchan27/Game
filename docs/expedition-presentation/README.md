# Expedition ledger — historical ordinary UI presentation record

Historical 2026-10-23 source snapshot, captured before optional expedition
drafts were integrated. The recorded source included the v5 run ledger,
route-gate settlement, death-loss boundary and legacy-trip compatibility. This
record covers UI presentation in an external isolated mirror for that earlier
state. Preserve its screenshots and hashes unchanged. Gameplay and save/load
acceptance remain unverified; the user deferred tests/QA. No new art was
generated.

The current source now includes an optional draft panel and two run-local draft
opportunities at the first two authored exploration sites on each route. This
historical capture does not include that panel. The separate [current draft
presentation record](../draft-presentation/README.md) contains fourteen staged
frames; it is presentation evidence only and does not exercise draft selection
or gameplay. No new render evidence is claimed for this historical record.

Canonical rules: [GAME_DESIGN.md](../GAME_DESIGN.md). Narrative:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Recorded output and identity

Eighteen final PNGs: nine in `1280x720/` and nine in `1024x768/`. Both final
Godot 4.6.3 processes exited 0, each with nine `EXPEDITION_PRESENTATION_FRAME`
entries and image result 0. No ERROR/WARNING lines were observed in those final
logs. Backend: OpenGL 3.3 Compatibility on Intel Arc 140V.

[source_snapshot.json](source_snapshot.json) records hashes of logs, all images,
the matching recipe, and 108 matching listed source/mirror inputs. The list
inherits the earlier 107-input story mirror and adds `ExpeditionLedger.gd`; it
does not cover every asset in the project. Included test source hashes identify
files only: those tests were not run. The isolated project settings differ by
the dedicated custom user directory and a trailing blank line. The real project
settings and real save were not written. Save size and modification time stayed
1203 bytes / `1792682904815624900` nanoseconds; this is preservation evidence,
not save/load compatibility evidence.

The first render attempt exposed a GDScript type-inference error in the result
dialogue's `extracted` variable. The parent stopped that attempt, specified its
bool type, then completed the captured renders. J also displayed the pending
relay wording after a staged completion; its card now describes the action's
purpose. Both sizes were rendered again after that final source correction.
The final logs and images identify the corrected source state.

## Manually staged views

| View | State placed in memory | Presentation scope |
| --- | --- | --- |
| `new-run-hud` | First active marked contract, empty haul | Field-action name, next step, expedition status |
| `haul-inventory` | 18 scrap, 9 ammo, 2 coils, 1 hammer in haul; 3 provisional kills and relay complete | Separate bank/haul, usable combined ammo and hub-service rules near panel top |
| `ready-to-extract` | Same haul, 5 kills and relay complete | Safe-exit guidance; no automatic contract reward |
| `field-contract` | Same ready state, J opened directly | Provisional counts, action purpose, disabled field hand-in, return instruction |
| `pending-clue-journal` | Manifest in journal and uncommitted clue list | Retained lore versus original-route extraction credit |
| `legacy-inventory` | Legacy-trip flag; no active ledger | Old immediate-bank rules through first return |
| `extracted-report` | Bank, counters and field state assigned directly; result dialogue shown | Returned haul, preserved steps and separate J hand-in |
| `lost-report` | Baseline bank; empty mission progress; retained pending lore; lost result shown | Loss boundary, retained character/journal, used ammo rule |
| `unsaved-report` | Extracted presentation with `saved=false` passed directly to dialogue | Prominent warning that disk has not been updated; close and retry through pause menu |

These scenes do not perform extraction, death recovery, hand-in, rewards or
save/load. `unsaved-report` does not simulate a filesystem failure. The normal
Wasteland scene creates an in-memory run as it loads; the recipe then assigns
the displayed fields without player actions or settlement. Resource layout is
constructed by the ordinary scene, but pickup claims and restored layouts were
not exercised. The actor is staged at `(3500,3510)` in the highway or
`(1380,970)` in the village; no traversal follows from these positions.

The native camera keeps zoom 1.15 and its offset. Only smoothing and staged
actor physics are disabled. Sixteen physics frames settle presentation before
capture; this is not timing/performance evidence. All result states are stopped
before any player interaction. Old story/art records remain immutable history.

## Review and limits

The parent inspected the new/ready HUD, wide and narrow haul panel, both contract
sizes, pending-clue journal, loss/return reports and the warning. An independent
review inspected six narrow views: haul, legacy, contract, pending clue, loss
and unsaved reports. It found no visible clipping in those frames; the parent
then shortened J's contradictory pending-action text and re-inspected the final
contract frames. Long inventory/journal content continues vertically below the
visible frame. Scrolling interaction, every equipment card, arbitrary resizing,
all scene/dialogue states and whole-game UI acceptance remain open.

Source review for this snapshot also corrected a ledger indentation error,
constrained provisional counters to declared objectives, and added a story-Boss
run source. The latter travels through the existing enemy-death callback, with
no new stats polling. Router save failures are surfaced after transitions.
Subsequent source added the field-draft flow; neither this capture nor its
render evidence covers the newer draft UI or exercises gameplay, reload,
duplicate reward or failure scenarios.

## Reproduce the presentation on another platform

Use an external project copy with a dedicated custom user directory named
`R17-Ordinary-Art-Preview-20261023`. Keep the real project and player save intact.
Synchronize the listed runtime inputs. Install
[ExpeditionPresentationPreview.gd.txt](ExpeditionPresentationPreview.gd.txt) as
`ExpeditionPresentationPreview.gd` on a Node scene named
`ExpeditionPresentationPreview.tscn` in that isolated copy.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1800 `
  --log-file C:/absolute/wide.log res://ExpeditionPresentationPreview.tscn `
  -- --expedition-output=C:/absolute/output
```

Verify the engine version before use. Repeat with 1024x768 and a separate output
directory. Confirm expected image files and logs as well as process completion;
the frame ceiling can also end a broken recipe. Never treat these staged states
as completed player journeys or executed QA.

繁體中文：這批十八張圖檢視出征介面的實際排版。收穫、返村、死亡和存檔失敗
回報均由記憶體設定呈現，沒有實際操作這些流程，也沒讀寫真實存檔。截圖對應的
舊來源尚無戰地調校介面；新來源已接入局內選擇，但目前來源的呈現擷取、舊檔相容、
任務完整性、遊玩節奏與存檔驗收仍待確認。不能把目前六份委託說成已完成十二趟
完整劇情。
