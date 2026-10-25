# Authored campaign — ordinary presentation record

**Historical snapshot.** Later action guidance, field notes and NPC changes are
recorded in [journey-guidance/README.md](../journey-guidance/README.md). Preserve
this set's images, logs and source hashes as evidence of its captured state.

2026-10-23. Twelve outings and 25 ordered actions now extend the six existing
main quest IDs in source. This record covers manually staged presentation in an
external isolated project. The user deferred tests/QA. It is not a completed
player journey, gameplay test, save/load acceptance or release approval.

Rules: [GAME_DESIGN.md](../GAME_DESIGN.md). Story:
[STORY_AND_SCENES.md](../STORY_AND_SCENES.md). Resume:
[AI_HANDOFF.md](../../AI_HANDOFF.md).

## Scope and final record

Twenty final PNGs: ten at `1280x720/`, ten at `1024x768/`. The two final Godot
4.6.3 render processes exited 0, with ten `CAMPAIGN_PRESENTATION_FRAME` entries
each and image result 0. Final logs contain no observed ERROR/WARNING lines.
Backend: OpenGL 3.3 Compatibility, Intel Arc 140V. The recipe retains native
camera zoom 1.15/offset and disables camera smoothing for capture.

[source_snapshot.json](source_snapshot.json) records the recipe, 110 matching
listed source/mirror input hashes, final logs/images and printed layout bounds.
This inherits the prior 108-input mirror list plus the two new campaign scripts;
it is not an exhaustive asset manifest. Test-source hashes identify files only.
The real project settings are not overwritten: the mirror retains custom user
directory `R17-Ordinary-Art-Preview-20261023`. Real-save metadata remains
1203 bytes / `1792682904815624900` ns, which is preservation evidence only.

| View | State assigned in memory | Presentation scope |
| --- | --- | --- |
| `highway-escort` | First outing; escort started at checkpoint zero | Reused NPC, nearby action text, compact journey HUD |
| `highway-action-map` | First outing, no completed actions | Current outing sites and return gate in the M map |
| `highway-contract` | First outing, contract page opened directly | Ordered actions alongside original kill/material/clue/field goals |
| `highway-route-choice` | First outing committed; second outing choice pending | Short exposed versus longer covered carry route, ambush/resource tradeoff |
| `marsh-flush-choice` | Sampling outing committed; flushing choice pending | Two herbs versus four ammo, safe extraction requirement |
| `crystal-defense` | Carry provisionally complete; defense at 8/18 seconds | Existing relay object, floor range cue, time/wave text |
| `city-record-choice` | Map outing committed; archive copy provisionally complete | Consented names versus restricted full-name copy; districts remain public |
| `facility-reserve-choice` | Earlier sensor outing and bypass/defense preassigned | Clinic herbs versus cistern scrap; finite rationing remains |
| `village-followup` | First outing committed; return text emitted directly | Next outing briefing and separate chapter hand-in explanation |
| `ending-records` | Completed chapter/clue IDs and two choice records assigned | K shows finite supply, six recorded clues and retained local choices |

The recipe calls no interaction, campaign completion, choice, quest hand-in,
loot, extraction/death settlement, save or load API. It creates the ordinary
Wasteland/Village scene, directly assigns temporary state, freezes scene/action
processing and actor/enemy physics, and opens UI or emits presentation signals.
The escort actor is created directly for its frame. No actual escort movement,
wave, timed action or choice is performed. The ending view has completed quests, clues and choices assigned directly; it
is not evidence that this state was reached through play.

## Review and corrections

Initial launch exposed two new script parse errors: an inferred bool from a
Variant in HUD and an indented fallback inside a `match` in CampaignAction.
Both were corrected before the final captures. `before-parse-wide.log` and
`before-action-parse-wide.log` retain those unsuccessful attempts; an exit 0 from
the frame timeout on a failed attempt is not acceptance.

Initial defense frames contained only floating text. The three defense actions
now reuse registered relay/isolation mechanisms and show a subtle native 2D
range cue. `before-cue-*` PNGs/logs preserve the prior presentation. No images
were generated or existing art overwritten. The action processor also observes
the existing gameplay-input blocker contract, suspending action advancement
while a visible modal blocks gameplay; that behavior has source review only.

The initial narrow HUD also placed the quickbar too low and left a one-column
contract card at half width. The quickbar now uses its actual combined minimum
height with an 8px bottom margin; navigation/hints follow its top edge, and
contract cards expand horizontally. `before-bars-*` and `before-card-*` preserve
the prior frames/logs. Final bar geometry is printed in both final logs: wide
quickbar `(380,646,564,66)`, narrow `(252,694,564,66)`, each with an 8px bottom
margin. Parent and independent final review found all quickbar buttons inside
both viewports. The narrow contract card is wider with some remaining right
whitespace; no visible text clipping was found in its captured portion.

The parent inspected the highway world/map/contract, defense and selected story
panels at both sizes. Independent review covered all four wide choice panels,
the wide contract/journal, and targeted narrow choice/contract/journal/defense
frames. J/K are scrollable; lower offscreen catalogue content was not reviewed.
Pause ownership, keyboard focus traversal, arbitrary resizing, actual route
traversal/collision, all twelve outings, death/partial extraction/reload and
choice reward idempotence remain unexercised. Defense values 18/24/30 seconds
and expedition minute targets are initial design values, not measured pacing.

## Reproduce the presentation

Use an external copy with the dedicated custom user directory above; synchronize
the listed inputs and preserve the real player save. Install
[CampaignPresentationPreview.gd.txt](CampaignPresentationPreview.gd.txt) as
`CampaignPresentationPreview.gd` on a Node scene `CampaignPresentationPreview.tscn`.
Verify the discovered Godot executable reports 4.6.3.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 --quit-after 900 `
  --log-file C:/absolute/wide.log res://CampaignPresentationPreview.tscn `
  -- --campaign-output=C:/absolute/output
```

Repeat at 1024x768 with a separate output/log. Inspect expected frame records,
logs, input identities and actual PNGs. Older story, expedition and draft capture
sets remain historical immutable records of their earlier sources.
