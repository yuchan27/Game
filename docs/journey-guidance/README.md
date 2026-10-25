# Journey guidance and field notes — ordinary presentation record

**Historical source snapshot.** The later receipt, last-report and ending-consent
continuation is recorded in [return-consequences/README.md](../return-consequences/README.md).
Preserve these captures/logs/hashes as evidence of their earlier source state.

2026-10-23. This continuation aligns the existing twelve-outing campaign's NPC
briefings, action instructions, carried items and returned field records. It
uses existing art and UI. The user deferred tests/QA; these are manually staged
production frames, not a completed player journey or release approval.

Rules: [GAME_DESIGN.md](../GAME_DESIGN.md). Narrative:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Captured source and output

Twenty-six final PNGs: 13 at `1280x720/` and 13 at `1024x768/`. Both final Godot
4.6.3 render processes exited 0, with 13 `GUIDANCE_PRESENTATION_FRAME` entries
and image result 0 each. Final logs contain no observed ERROR/WARNING lines.
Backend: OpenGL 3.3 Compatibility, Intel Arc 140V. Native camera zoom 1.15/offset
is retained; camera smoothing is disabled for capture.

[source_snapshot.json](source_snapshot.json) records final PNG/log hashes, the
recipe and 112 matching listed source/mirror inputs. The list inherits the prior
110 campaign inputs and adds the existing `broken_coil` and `precision_chip`
icons. It is not an exhaustive asset manifest. Included test-source hashes
identify files; no test was executed. Runtime/data sources match the isolated
mirror; its project settings deliberately retain a separate user directory,
`R17-Ordinary-Art-Preview-20261023`. Real-save metadata remained 1203 bytes /
`1792682904815624900` ns. No real-save payload was read or written for capture.

| View | State assigned directly | Presentation scope |
| --- | --- | --- |
| `first-hub` | First outing active; Ada dialogue requested | Neutral NPC line plus current journey fallback, dry village |
| `second-hub` | Highway A committed; Highway B current | Alan says crew is back and R-17 carries the coupling alone |
| `cleanup-hub` | Both outings committed, old defeat goal incomplete | Forge/J guidance checks remaining contract goals without redoing outings |
| `active-escort` | Escort started at checkpoint 1 | Existing NPC actor, compact progress label and active HUD instruction |
| `coupling-carry` | Covered route selected directly, carry started at checkpoint 1 | Small registered coil icon, one field mechanism, M waypoint guidance |
| `relay-carry` | Crystal A committed, carry started at checkpoint 1 | Registered chip icon and compact active progress |
| `field-notes` | Marsh's first sample provisionally done | Expanded K notes marked `本趟待帶回` |
| `banked-notes` | Marsh A committed | Expanded K notes marked `已帶回` |
| `chapter-notes` | Highway complete with completion marker and saved choice | Expandable completed-chapter notes in J |
| `completed-npc-record` | Same completed chapter and covered-route choice | Mia's first line plus the shared returned-choice record |
| `legacy-journal` | Highway complete without optional completion marker | No invented field-note section; queried note length is zero |
| `final-hub` | Facility A committed; B current | Ada distinguishes comparison/flagging from the upcoming pressure test |
| `order-notice` | Factory A actions provisionally done | Short completion notice directs full record to K |

The recipe assigns quest/route/choice/runtime/completion fields in memory. It
freezes scene/action processing and actor/enemy physics, opens existing UI and
expands the notes toggle. Escort actor and carry sprite are created directly.
Dialogue presentation composes `story_dialogue_for_npc()` plus
`campaign_npc_record()`, matching the real first-line composition in
`DialogueNpc._talk()`. It does not call the real talk path or exercise E input,
gifts, dialogue page reset or close behavior. The short notice is emitted
directly. No mission action, actual choice, reward, hand-in, extraction, death,
save/load, traversal, pacing, performance or QA scenario was performed.

## Corrections and review limits

- NPC copy follows twelve outings plus six post-outing cleanup states. Highway
  B carries no crew; Facility A does not claim a pressure test already happened.
  Water still changes only at the original first/final chapter hand-ins.
- Started/checkpoint changes refresh journey guidance. Full action instructions
  remain in HUD/J; full results appear in collapsible J/K notes. Completed legacy
  quests without the optional v5 marker receive no reconstructed action history.
- Both NPC entry paths share the same returned-choice record. Authored campaigns
  avoid stale generic advice; an unmatched NPC uses its neutral repeat line and
  the current journey hint. These selection and signature paths have source
  review, not a real conversation-input result.
- `before-duplicate-relay.png` shows a second legacy relay/green label at the
  carry site. Matching current action prop and normalized position now suppresses
  that duplicate. Different props/positions and old unmarked quests retain their
  source paths. Future data that moves the shared site must preserve the match.
- `before-long-notice.png` shows full result prose over the hero. The final short
  notice keeps the long text in K instead. `before-long-world-label.png` shows
  the active carry instruction crossing into the narrow HUD. Final world labels
  retain name/progress/M guidance; full instructions remain in HUD/J.
- The two carried icons render at 22x22 world pixels in the staged frames, within
  a 24x22 maximum. The fixed attachment `(20,-46)` has no multi-angle/animation
  acceptance. No new art was generated or original asset overwritten.

The parent inspected targeted final world, notice, NPC and note frames at both
sizes. Final narrow escort/relay labels no longer cross the HUD in their captured
positions. Notes and dialogue fit in the inspected portions. J/K are scrollable;
lower offscreen notes/catalogue, arbitrary camera positions/resizing, all NPC
branches, keyboard focus and modal ownership were not exhaustively reviewed.
An earlier worker reviewed source boundaries; credit exhaustion prevented an
independent final review of the last shared-NPC/compact-label edits. The final
render and PNG review are parent evidence only.

## Reproduce the presentation

Use an external copy with the separate user directory above. Synchronize the
listed inputs while keeping its isolated `project.godot`. Install
[JourneyGuidancePreview.gd.txt](JourneyGuidancePreview.gd.txt) as
`JourneyGuidancePreview.gd` on a Node scene `JourneyGuidancePreview.tscn`:

```ini
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://JourneyGuidancePreview.gd" id="1"]

[node name="JourneyGuidancePreview" type="Node"]
script = ExtResource("1")
```

Verify the discovered engine reports 4.6.3. Run using absolute output/log paths:

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 1200 `
  --log-file C:/absolute/wide.log res://JourneyGuidancePreview.tscn `
  -- --guidance-output=C:/absolute/output
```

Repeat at 1024x768 with a separate output/log. Inspect process completion, expected
frame records, source identity and actual PNGs. The older campaign, draft,
expedition, story and City capture sets remain historical snapshots with their
original hashes; do not rewrite them as evidence for later source.

繁體中文：這是兩種視窗尺寸、13 種預置狀態的畫面紀錄，涵蓋分趟交代、搬運、
現場手記與已帶回的處置。完整劇情旅程、實際選擇、撤離、死亡與存讀檔仍未驗收；
不能把這 26 張圖或兩次正常結束的繪製程序當成測試通過。
