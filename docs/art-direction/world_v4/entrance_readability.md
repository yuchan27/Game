# Village entrances and connected trade-court composition

2026-10-23. Ordinary art-production checkpoint; full-world acceptance remains open.
The user's pasted-object objection remains the governing visual requirement.
Matching palettes, source selection and a clean render are insufficient.

## Composition and source contract

The previous Village Guild entrance and adjacent east route gate used the same
small generic arch. The Guild now uses an original tall slate/oak gatehouse with
crossed salvage hooks and muted pennants. The east route keeps its existing kit
and moves from (2260,900) to (2260,540), separating the destinations. Its existing
nonblocking behavior, route ID, trigger dimensions and transition callback remain.

Active source: `assets/world_v4/architecture/guild-entrance-v4-03.png`, unchanged
1254x1254 RGBA output from built-in imagegen. SHA-256:
`87bb631791ba5e90b4bf2175cb12bbb5c5afc8d17f8b067d2a55baf7cc034db9`.
Exact prompts and rejected-candidate decisions are in
`assets/world_v4/prompts/guild-entrance-v4-03.txt`.

| Registration | Value |
| --- | --- |
| Source rectangle | `[8,52,1240,1136]` |
| Absolute source foot | `[630,1150]` |
| World width | 250 pixels |
| Native alpha cutoff | 0.7 |
| Saturation / exposure | 0.80 / 0.90 |
| Contact | Authored ground debris; shared world-space root binding |

The first candidate's unequal pier baselines and the second candidate's squat
opening were rejected before activation. The current equal-foot piers retain
the existing two-edge collision contract; appearance is not proof of clearance.
The `world_presentation_by_scene.guild` board override is preserved. Reusing the
Guild asset ID does not replace its board with an arch inside the Guild scene.

## Ground that connects the district

An intermediate full-camera review still found isolated prop islands on a broad
dirt field. A smaller rubble halo did not address the missing circulation.
Village `hubs.village` layout in the existing
`data/art/world_materials_v3.json` now connects these approaches:

- A compact worn court at (1885,940), radii (140,90), joins the east main road.
- Market, house and repair branches reach their existing anchors at (1810,650),
  (1610,850) and (1760,1130); the southeast continuation joins the repair branch.
- Four 72-pixel branches connect that court to those frontages and the Guild.
  The Guild approach passes through (2060,900) and returns to the main road at
  (2060,970), instead of ending below the threshold.
- An 88-pixel east leg connects the existing road to the relocated factory gate.

WorldBackdrop samples the same fine paving and earth across this layout, with
broken shoulders and registered-foot wear. Final review of the intermediate
frames found that the broad wear multiplier still separated streets into patches.
Optional `paving_continuity` is now 0.8 for Village: it retains the lane's central
paving while shoulders still break into earth. The shader default is 0; Guild
and Wasteland retain their previous patch rule. No per-frame masks are added.

Two existing-kit `scrap_wall` scenery entries at (1785,865) and (1920,890) frame
the house's east flank and Guild's left pier as a broken frontage. These use the
148-pixel wall source and existing footprint `[-73,-19,145,35]`, rather than a
new image or a solid apron. The house doorway, main street and Guild opening are
outside their footprint rectangles in source. As with the existing houses, an
entry is omitted if its 48-pixel-expanded collision bounds contain an older saved
position. This is source clearance, not a walking test. Existing station/gate
collision contracts, services and central/north plazas remain; the two new wall
segments add their own small registered blockers. No new persistent state.

## Readable context without another overlay panel

Village station/gate badges were redundant with their E prompts. Their permanent
world labels were removed; map metadata remains. Optional
`Interactable.set_screen_safe_prompt()` now supplies target text to the HUD's
existing controls-hint row. The separate experimental context panel was removed
after screenshots showed it covering lower arches even at reduced opacity.
There is one footer line, no new rectangular overlay or per-target CanvasLayer.

`Player.get_nearest_interaction_target()` mechanically extracts the former E
selection loop: same group order, eligibility/dialogue filters, squared distance
and strict-less-than tie behavior. E uses that helper and retains its visible
dialogue-panel guard. The HUD queries the same selected target. An eligible NPC
can therefore take priority without an unrelated gate hint claiming the action.
Default world/NPC labels remain available outside the optional Village mode.
The selected nearby target keeps its hint even when a tall visual center is
outside the camera; visual-anchor clipping no longer suppresses an available E.

HUD's existing modal visibility hides the hint on M and other blocking panels.
The footer stays at viewport height minus 126, centered after a text-size change;
context text uses 14 pixels and the ordinary controls hint uses 12. Reach,
collision, rewards, dialogue and transition logic were not redesigned here.
Selection preservation was reviewed from source; no interaction was executed.

## Tactical map follows the drawn streets

`WorldBackdrop.get_map_road_segments()` returns the loaded lane segments.
WorldMapView uses these for Village/Guild M maps instead of drawing an unrelated
cross. Original cross fallback and Wasteland's route path branch remain. This
depicts visual ground, not a navigation mesh or a walkability guarantee.

## Evidence and remaining work

[`captures/gate-entrances/README.md`](captures/gate-entrances/README.md) records
26 ordinary frames: thirteen at each supported window size, 102 matching source
inputs and two final render exits 0. Final logs have no observed engine/script
errors. Native camera limits, 1.15 zoom and HUD are retained. Positions and map
states are staged, not played. The original highway-convoy location is included
as a current-source control at both sizes. Exact hashes and recipe are recorded there.

Parent and independent review found the final walls attached to the house and
left pier, a readable lane core, no visible doorway obstruction and a clear footer.
The wall footprints are x=1712..1857/y=846..881 and x=1847..1992/y=871..906;
their 10x10 overlap forms an intentional continuous flank, partly overlapping the
house footprint. The east gate camera still exposes broad open ground between
the wider district's focal props. The convoy control likewise remains isolated.
These source/static observations are not proof of collision traversal.

The Guild silhouette, connected approaches and footer presentation are locally
improved. Full cohesion is still open: other routes/hub quarters retain isolated
props and sparse circulation, generic route gates repeat, some source tufts are
too bright, and fixed HUD/native viewport edges can obscure peripheral scenery.
The new broken left frontage is a local frame, not a fully enclosed settlement.
Continue composing bounded districts and encounter spaces before adding more
scattered assets. Hero action/facing, full UI and campaign acceptance remain in
`docs/PRODUCTION_STATUS.md`.

No tests/QA suites, collision walking, quest/reward actions, save/load, comparable
performance, Windows export or release acceptance were performed. Real user data
and original source art were preserved. No commit, push or cleanup deletion.

繁體中文：這批先把東側市場、住宅、公會與維修站接成有道路和作業前庭的小街區，
不是只調色或補一圈陰影。公會入口已有獨立輪廓，E 提示回到原本底部提示列，
M 地圖沿用實際街道。整體「拼貼感」尚未全面驗收；其他區域的空地、重複入口與
孤立物件仍需逐個完整鏡頭整理。這些是一般美術渲染，沒有實際遊玩或 QA。
