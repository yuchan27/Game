# Regional courts — ordinary production evidence

Historical 2026-10-23 source checkpoint. **Art review, not QA or release acceptance.**
Detailed implementation and review limits: [regional_courtyards.md](../../regional_courtyards.md).

The later [late-story-courts checkpoint](../late-story-courts/README.md) changes
shared manifests/routes and `GameState.gd`; its Highway/Marsh/Crystal controls
record current story views. This directory and its hashes remain immutable
evidence for the earlier source, not current shared-source identity.

Eighteen final PNGs: nine at 1280x720 in this directory and the same nine at
1024x768 under `1024x768/`. The final two Godot processes exited 0; their logs
contain nine `REGIONAL_ART_FRAME` entries each and no observed error/warning
lines. The renderer is Godot `4.6.3.stable.official.7d41c59c4`, OpenGL 3.3
Compatibility on Intel Arc 140V. These exits prove completion of ordinary
rendering only. They do not prove interactions, gameplay, save compatibility,
performance or whole-world artistic acceptance.

| Capture | Staged player world position | Purpose |
| --- | --- | --- |
| `marsh-story-approach` | 3061.76,3002.88 | Unchanged actual chapter-two E location |
| `marsh-south-approach` | 3061.76,3180 | Service lane, house/valve/shore relation |
| `marsh-pump-forecourt` | 3190,3070 | Valve/root and bank close approach |
| `marsh-map-staged` | 3061.76,3002.88 | Existing M layout with new service forks |
| `crystal-story-approach` | 3456,3650.56 | Unchanged actual chapter-three E location |
| `crystal-south-approach` | 3550,3800 | Excavation loop, scatter and residual sparse ground |
| `crystal-west-approach` | 3175,3720 | Compact outcrop, neighboring walls and partial crops |
| `crystal-map-staged` | 3456,3650.56 | Existing M layout and chapter marker |
| `convoy-control` | 3584,3225.6 | Previous coach-stop story view on current shared source |

The native Camera2D offset/limits/zoom 1.15 and real HUD remain. Only smoothing
is disabled in the capture recipe. Sixteen physics frames settle existing
overlap/occlusion updates before freezing each state; this is not walking or
input. The M state is staged by `HUD.set_fullscreen_map`, not a keyboard action.
Quest state is reset for these art views; it is not a staged campaign playthrough.

`source_snapshot.json` lists 105 input paths with matching source/mirror SHA-256,
recipe hashes, project-setting hashes, final log hashes and all 18 PNG hashes.
The boundary is those listed inputs, including test source identity only and
inactive v4 PNGs. Legacy/hero PNG sources outside that list are not newly audited.
The isolated project differs intentionally by its dedicated custom user dir;
the real project/save configuration was not replaced. Shared source changes
since the preceding coach snapshot are limited to the two world-art manifests,
route data and `WorldBackdrop.gd`, plus the three new v4 PNGs.

The existing isolated mirror on this machine is
`C:/Users/wuwu6/AppData/Local/Temp/first-game-art-preview/r17_v2_current` with
custom userdata `R17-Ordinary-Art-Preview-20261023`. On another machine, make an
external project copy, set a separate custom user directory, synchronize the
listed sources and install [the recipe](../RegionalSitesPreview.gd.txt) as
`ArtPreviewV4.gd` with a Node scene using it. Preserve source project settings.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 res://ArtPreviewV4.tscn -- `
  --art-output=C:/absolute/output
```

Repeat with `--resolution 1024x768` and a distinct output directory. Optional
`--art-view=marsh-story-approach,crystal-story-approach` selects a subset. Never
point this production recipe at the real player userdata.

`draft-before-gl/`, `before-gl.log`, `BeforeRegionalSitesPreview.gd.txt` and
`before_source_snapshot.json` retain the comparable two-camera baseline and its
102-input identity. `draft-before/` used D3D12 Forward+ and is diagnostic only.
Other draft directories/logs record earlier iterations. `draft-parse-error.log`
records the first optional-water adapter's inferred-type parse failure (exit 2);
an explicit bool fixed it before the later successful ordinary renders. Do not
describe that failed attempt as a pass or those drafts as current evidence.

Parent inspected the final paired states. Main story views have clear named
E hints, visible hero and connected scene context. The compact crystal clears
the narrow quest panel at its story location. Other cameras still naturally
crop or hide peripheral parts behind HUD, and sparse/repeated terrain remains.
Independent review covered the baseline and first draft only; final independent
follow-up was unavailable due to workspace credits. Player/world acceptance is
open. No input/E, collision traversal, quest/reward action, saved entry,
save/load, comparable performance, QA suite or export was executed.
