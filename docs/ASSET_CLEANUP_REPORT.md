# Project cleanup — 2026-10-23

Current cleanup follows the user's request to simplify the project without
running tests. Inspection covered literal paths, class names, resource UIDs and
Python imports across scenes, scripts, data, documentation and Skills. The graph
service was incomplete/unavailable for these paths, so source inspection supplied
the evidence. This is not an exhaustive dynamic-resource proof.

## Removed files

| Files | Reason |
| --- | --- |
| `scripts/components/Health.gd` and its `.uid` | Unreferenced HealthComponent; live health belongs to existing GameState/enemy owners. |
| `scripts/ui/MiniMapView.gd` and its `.uid` | Unreferenced compatibility wrapper; current HUD instantiates WorldMapView. |
| `docs/automated_playtest_report.json`, `docs/performance_report.json` | Stale generated snapshots; runners already output to external/user QA directories. Ignored to prevent reintroduction. |
| `scripts/tools/build_r17_rigged_atlas.py` | Unreferenced superseded procedural production script that could replace current knight art. |
| `scripts/tools/build_release_candidate_assets.py` | Unreferenced old robot/full-asset generator superseded by current versioned production. |
| `.agents/skills/godot-2p5d-pixel-art-and-animation/scripts/clear_godot_import_cache.py` | Obsolete bulk-cache deletion helper; normal reimport/isolated production previews replace it. Skill and guide references updated. |

34 individual files, 23,605,810 bytes. Every file was copied before removal into
`C:/Users/wuwu6/AppData/Local/WastelandRecycler/cleanup/20261023-production-cleanup/`.
The external `manifest.json` records original relative paths, byte counts and
SHA-256 hashes. Each deletion targeted one confirmed absolute file; no directory
was recursively deleted and no player save was changed by this cleanup.

The additional nine removals are the rejected native-3D mannequin demo sources
(`docs/art-direction/r17_v2/demo/`, four files) and its `rig_proof/` report/four
PNGs (five files). The current character owner explicitly released these paths;
production now uses the reviewed pixel-art `sprite_preview/` workflow. They were
also backed up and each file removed individually. No directory was deleted.

## Deliberately retained

- VillageTileMap is actively instantiated by Village; it is not dead code.
- Legacy player action/split/30-frame art still participates in fallback or source
  contracts. Existing original art and generated v2 sources remain preserved.
- Automated runners remain available for a later verification stage. The user's
  request to defer tests does not imply removing the test infrastructure.
- Historical art/audit documents remain references; AGENTS, GAME_DESIGN and the
  current art-direction index identify current authority.

No tests were run for this cleanup. Current source review and updated references
are not a runtime validation result.

Four further rejected blade sheets (`v001`, `v003`, windup `v012`, impact `v013`)
were released by the active character owner, backed up and removed individually.
Approved concept v002 and all active blade source sheets/configuration remain.

Six superseded firearm/heavy artifacts were subsequently released by their owner,
reference-inspected, copied to the same external archive and individually removed:
firearm ready v001/fire v001, heavy ready v001/impact v001, and heavy impact v001's
native preview/measurement JSON. Their backup hashes were compared before each
single-file removal. Accepted firearm v002, heavy ready v002/windup v001/impact
v002 and their active registrations remain. Exact original paths and hashes are
in the external manifest; rejected-generation prompts remain as provenance.

Six further superseded gait artifacts were then released and archived: the two
failed heavy contact-B source PNGs and v002's preview/measurement/log, plus the
rifle contact-B v001 PNG superseded by accepted v002. Each exact file had its
backup hash checked and was removed individually. Keep accepted heavy passing
v001, rifle contact-B v002/passing v001 and all generation prompts. The current
family manifest uses none of the removed source paths.
