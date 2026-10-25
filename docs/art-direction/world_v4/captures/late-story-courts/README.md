# Late story courts — ordinary production evidence

Historical 2026-10-23 source checkpoint. **Art production review, not QA or release acceptance.**
Implementation: [late_story_courts.md](../../late_story_courts.md).

The later [city-street-block checkpoint](../city-street-block/README.md) changes
shared manifests/routes and adds two original PNGs. Its current control views
supersede this batch's shared-source identity. This directory retains its exact
historical PNG/log/recipe/input hashes.

Thirty-two final PNGs: sixteen at 1280x720 here and the same sixteen at 1024x768
under `1024x768/`. Both actual Godot processes exited 0. `late-wide.log` and
`late-narrow.log` each contain sixteen `LATE_COURT_ART_FRAME` entries and no
observed error/warning lines. Godot is `4.6.3.stable.official.7d41c59c4`, OpenGL
3.3 Compatibility on Intel Arc 140V. These exits establish completed rendering.

| Capture | Staged player world position | Purpose |
| --- | --- | --- |
| `factory-story-approach` | 3727.36,2421.76 | Actual chapter-four E location, furnace hall/turbine court |
| `factory-south-approach` | 3727.36,2600 | Southern spine and connected service frontage |
| `factory-forecourt` | 3900,2500 | Turbine/root close approach and peripheral building crop |
| `factory-map-staged` | 3727.36,2421.76 | Existing M map with authored branches |
| `city-story-approach` | 3712,3072 | Actual chapter-five E location, sanctuary/archive court |
| `city-south-approach` | 3712,3240 | Shared earth/slate ground and service connection |
| `city-archive-forecourt` | 3890,3170 | Archive/root close approach and peripheral sanctuary crop |
| `city-map-staged` | 3712,3072 | Existing M map with authored branches |
| `facility-story-approach` | 3328,2826.24 | Actual chapter-six E location, cistern/vault court |
| `facility-south-approach` | 3328,3000 | Cold ground/slate road and service connection |
| `facility-vault-forecourt` | 3500,2920 | Vault/root close approach and peripheral cistern crop |
| `facility-map-staged` | 3328,2826.24 | Existing M map with authored branches |
| `convoy-control` | 3584,3225.6 | Current Highway coach story composition |
| `marsh-control` | 3061.76,3002.88 | Current Marsh pump/water story composition |
| `crystal-control` | 3456,3650.56 | Current Crystal excavation story composition |
| `guild-active-journey-staged` | Guild 660,470 | Manually staged factory contract/J and corrected Guild hint |

The real HUD and native camera offset/limits/1.15 zoom remain. Only camera
smoothing is disabled. Sixteen physics frames settle presentation before each
state freezes. M is opened through the existing HUD setter; Guild J through its
existing panel setter after assigning `old_factory_core`. No actual keyboard/E,
contract acceptance, hand-in, reward or campaign traversal is executed.

`source_snapshot.json` records all final PNG/log hashes, the matching recipe,
project-setting hashes and 105 matching source/mirror input hashes. Exactly four
listed inputs changed since the regional-courts snapshot: `world_v2.json`,
`world_materials_v3.json`, `wasteland_routes.json` and `GameState.gd`. Existing
source PNGs are reused; no original raster was replaced. The identity boundary
is these listed inputs, not an audit of every legacy/hero PNG. Test source is
hashed as source only. The isolated project intentionally uses dedicated
custom userdata; real project settings and real player saves were not replaced.

On this machine the mirror is
`C:/Users/wuwu6/AppData/Local/Temp/first-game-art-preview/r17_v2_current`, using
custom userdata `R17-Ordinary-Art-Preview-20261023`. On another platform make an
external project copy, give it dedicated userdata, synchronize the listed inputs,
and install [the recipe](../LateStoryCourtsPreview.gd.txt) as `ArtPreviewV4.gd`
on a Node scene. Preserve source project settings and the real save.

```powershell
& $Godot --path $IsolatedProject --rendering-method gl_compatibility `
  --windowed --resolution 1280x720 res://ArtPreviewV4.tscn -- `
  --art-output=C:/absolute/output
```

Repeat with `--resolution 1024x768` and a distinct output directory. Optional
`--art-view=city-story-approach,facility-story-approach` selects a subset.

`before/`, `before.log`, `before_source_snapshot.json` and the retained before
recipe record the actual pre-change three-story-camera baseline. `draft-one/`
contains the first wide arrangement; `draft-narrow/` exposes its left-edge
cropping. `draft-fit/` records the corrected fixed world-width variants and
`draft-guild/` the staged Guild hint. Their logs are retained as drafts, not
current-source or gameplay evidence.

Parent reviewed the sixteen final wide states. Independent review covered all
sixteen final narrow states and nine wide story/south/forecourt comparisons.
Main story views keep the hero, clue and building silhouette visible; the fixed
world-size variants corrected left-edge cropping. Peripheral roofs still pass behind the HUD
in southern approaches, and forecourt cameras naturally crop side buildings.
At the close Factory forecourt stance the hero covers the turbine hub/shaft;
the City equivalent partly covers the archive face. These actual player-centered
occlusions remain documented, rather than hiding them by changing only staging.
Factory reads as a broad court with a long straight material edge, Facility has
a subtle dark road, and distant ground/repeated isolated walls still need
composition. Matching colors, source
identity or clean rendering cannot establish whole-world artistic acceptance.

No tests/QA suite, collision walking, saved-entry/fallback execution, save/load,
comparable performance or export was run. The full production objective remains
open in [the ledger](../../../../PRODUCTION_STATUS.md).
