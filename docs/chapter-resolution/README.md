# Chapter debriefs, ending consent and restored choice — ordinary presentation record

Historical presentation. The newer [story-continuation record](../story-continuation/README.md)
contains later source and copy changes. No contemporaneous source-hash manifest
was saved for these eighteen frames; keep their original PNGs/logs without
attributing current source or real travel/input behavior to them.

2026-10-24. This record details the staged visual presentation of authored chapter debriefs,
read-only K chapter replay, NPC campaign responses, and restored story-choice / field-draft
modals upon scene arrival with pause ownership. Existing art, quests, rewards, and UI are retained.
Tests/QA were deferred per explicit user direction. These are staged production views, not gameplay acceptance.

Rules: [GAME_DESIGN.md](../GAME_DESIGN.md). Story:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Final record

Eighteen final PNGs: 9 each at `1280x720/` and `1024x768/`. Both Godot 4.6.3 render processes
exited 0, with 9 `CHAPTER_PRESENTATION_FRAME` entries, two `CHAPTER_STAGED_CURTAIN` checks,
two `CHAPTER_STAGED_RESTORE` checks, and image result 0 each. Logs show no observed ERROR/WARNING lines.
Backend is OpenGL 3.3 Compatibility on Intel Arc 140V GPU.

| View | Directly staged state | Presentation scope |
| --- | --- | --- |
| `chapter-2` | Chapter 2 (Toxic Marsh) completed; debrief with Mia | Authored chapter debrief dialogue |
| `ending` | Chapter 6 (Facility) completed; Mia final report | Ending narrative with restored water |
| `ending-consent` | Scrolled to public/restricted name choice section | Ending reflects recorded family name consent |
| `ending-tail` | Scrolled to footer | Dialogue footer guides scrolling and [K] journal |
| `journal` | Completed chapter in K Codex list | Foldout chapter notes toggleable in K |
| `journal-chapter` | Expanded Crystal Scar chapter notes | Read-only field notes with choice records |
| `alan` | Alan (Wasteland Survivor) in Village | Inter-chapter NPC response acknowledging Alan/R-17 connection |
| `restored-story` | Scene arrival with active pending story choice | Choice panel acquires pause after curtain (`story_owner=true`, `draft_owner=false`) |
| `restored-draft` | Scene arrival with active pending field draft | Draft panel acquires pause when no story choice is pending (`story_owner=false`, `draft_owner=true`) |

## Pause ownership and arrival invariants

- **Transition curtain release**: When a scene transition succeeds (`error == OK`), `SceneRouter` releases its transition pause (`get_tree().paused = false`) before emitting `transition_finished`.
- **Restored panel pause ownership**: Restored story-choice and field-draft modals in `HUD.gd` listen for `SceneRouter.transition_finished`. When a pending choice exists, `campaign_choice_panel` opens and acquires `_campaign_choice_paused_tree = true` and `get_tree().paused = true`.
- **Priority**: Story choice takes precedence over optional field draft (`draft_owner=false` while story choice is pending).
- **Source intent, still pending gameplay acceptance**: `_refresh_overlay_visibility()` releases owned pause when a panel closes. These fixtures do not exercise real selection, `[Esc]`, scene travel or disk loading.
