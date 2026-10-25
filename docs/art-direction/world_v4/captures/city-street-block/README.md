# City street block — ordinary production evidence

2026-10-23 preserved source checkpoint. **Art production, not QA or release acceptance.**
Later narrative integration changed Main, GameState, HUD, Village, quest/event/NPC
data and the relay's permitted regions. The immutable captures and hashes below
identify their earlier source state; they do not show the revised story or UI.
Contracts and limitations: [city_street_block.md](../../city_street_block.md).

Twenty final PNGs: ten at1280x720 here and the same ten at1024x768 under
`1024x768/`. Both actual Godot4.6.3 processes exited0; `city-wide.log` and
`city-narrow.log` each record ten `CITY_STREET_ART_FRAME` entries and no observed
error/warning lines. Backend: OpenGL3.3 Compatibility on Intel Arc140V.

| Capture | Staged actor world position | Purpose |
| --- | --- | --- |
| `city-street-frontage` | 4090,4775 | Whole joined dwelling/workshop at fixed world width600 |
| `city-street-main-road` | 3712,4775 | Main-spine/frontage junction; building naturally crops right |
| `city-street-bay-approach` | 4200,4820 | Source-clear foreground stance; upper roof naturally crops |
| `city-street-map-staged` | 4090,4775 | Existing M map reads the ninth path and southern-loop connection |
| `city-story-control` | 3712,3072 | Existing archive/church story composition |
| `factory-control` | 3727.36,2421.76 | Current fine cold-earth source with retained warm tint |
| `facility-control` | 3328,2826.24 | Current cold ground/cistern/vault composition |
| `crystal-control` | 3456,3650.56 | Current fine cold ground/excavation composition |
| `convoy-control` | 3584,3225.6 | Current Highway story control |
| `marsh-control` | 3061.76,3002.88 | Current Marsh story control |

Native camera offset/limits/zoom1.15 and real HUD remain. Only smoothing is
disabled. Sixteen physics frames settle presentation before freezing each state.
The actor is repositioned after population; M is shown through the existing
HUD setter. Neither walking, gameplay input, actual initial/saved entry nor
quest actions are performed. The close frontage stance lies inside the existing
48px grown-foot spawn exclusion; this staged view cannot prove that saved branch.
The bay stance is outside that exclusion by source geometry only.

`source_snapshot.json` records 107 matching source/mirror inputs, matching recipe,
project-setting hashes, final logs and all20 PNG hashes. Since late-story-courts,
the three changed listed inputs are `world_v2.json`, `world_materials_v3.json`
and `wasteland_routes.json`; two source PNGs were added. Test sources are hashes
only; legacy/hero PNGs outside that list are not newly audited. Original PNGs,
engine code, real project settings and real player saves were not replaced.

The source engine is `4.6.3.stable.official.7d41c59c4`. This machine's external
mirror is `C:/Users/wuwu6/AppData/Local/Temp/first-game-art-preview/r17_v2_current`,
using custom userdata `R17-Ordinary-Art-Preview-20261023`. To resume elsewhere,
copy the project externally, configure dedicated userdata, synchronize listed
inputs and install [the recipe](../CityStreetBlockPreview.gd.txt) as
`ArtPreviewV4.gd` on a Node scene. Preserve real settings/userdata.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 res://ArtPreviewV4.tscn -- `
  --art-output=C:/absolute/output
```

Repeat with1024x768 and another output directory. Optional
`--art-view=city-street-frontage,facility-control` selects a subset.

`before/` has two actual City views and three matched cold-ground baselines.
Their two processes exited0; logs and the105-input prechange snapshot remain.
`BeforeCityStreetBlockPreview.gd.txt` is their recipe. `draft-wide/` and
`draft-narrow/` record the first width620 row and new ground; `draft-width620-wide/`
retains that revision's ten wide states/log after provenance synchronization.
The final width600 scales all three feet proportionally and provides more roof
and side margin in the whole-frontage view. Draft `clear-entry` is renamed
`bay-approach` in the final recipe; no saved-entry execution is implied.

Parent inspected all20 final states. Independent final row review covers the three street/frontage/bay views at both
sizes. The whole-frontage view retains full roofs/bases and doors without HUD
overlap (about16px wide/40px narrow top space, reviewer estimate). Bay approaches
still crop the roof, with narrow quest-panel overlap; main-road context crops
the right side and puts some roof under the minimap. A separate independent
comparison of the three matched wide ground drafts found less prominent large
outlined/diagonal plates and subdued chips relative to the hero; no quantitative
seamlessness or pixel measurement was performed. Facility's authored warm grass
and rubble remain a color contrast. Source integration and these bounded art
reviews cannot establish whole-world/player acceptance.

No tests/QA, E/input, collision traversal, saved entry, save/load, rewards,
comparable performance or export ran. Continue the full
[production ledger](../../../../PRODUCTION_STATUS.md).
