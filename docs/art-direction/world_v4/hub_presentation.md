# Hub material, frontage and cistern checkpoint

2026-10-23. Ordinary art production; gameplay QA remains deferred.

This is the historical 40-frame hub source contract. The later
[`entrance/readability pass`](entrance_readability.md) changes Village's Guild
source, east gate position, east-quarter ground and optional interaction hint
presentation. Refer there and to `captures/gate-entrances/` for current evidence;
keep the original hub snapshot intact.

## Acceptance slice and source selection

Village and Guild should use the same small-course slate, aged oak, dull iron,
oblique planes and worn earth as the current wilderness. Existing service IDs,
rewards and save fields remain. Full-camera review uses the native player camera,
its limits/1.15 zoom and visible HUD at 1280x720 and 1024x768.

Three original RGBA outputs are active under `assets/world_v4/props/`:

| Source | Registered uses | SHA-256 |
| --- | --- | --- |
| hub-workstations-v4-02.png | Forge, craft, shop, mod, recycling, repair/save | b92959854992c1c8b7047525fa4d59814c260538b5ea05c86828f577e257c082 |
| hub-guild-fixtures-v4-02.png | Open gateway, Guild contract board, Guild reward counter | 266ca5c0ce9ef9180f29303c8a1103a7c9fbc57b48e15a01a99ee5be78b4e8a4 |
| hub-residences-cisterns-v4-01.png | Village house, Guild lodge, dry/restored cistern | befbeda65608c9ac7907d27aed2d3b71b13b5336e976e525df16d7c595fd6ef9 |

Built-in imagegen produced these assets; exact prompts are in
`assets/world_v4/prompts/`. No source PNG pixels were edited. Dense earlier
workstation/fixture candidates were not activated. The residence output did not
obey a uniform quadrant grid, so inspected disjoint rectangles replace that
assumption. `visual_assets.json` records actual rectangles, absolute source feet,
world widths, dimensions and source hashes. Native alpha cutoff 0.7 discards the
faint colored transparent fringe without adding a rectangular backing plate.

`RuntimeAssetLoader.world_presentation_source` selects an optional scene override;
`apply_world_presentation` validates its dimensions/crop/foot and returns rendered
bounds. The original `path` remains available to UI/fallback loaders. The Guild
uses the old guild-gate ID for its board and save-station ID for its reward desk;
`world_presentation_by_scene.guild` makes those actual roles distinct.

## Continuous materials and placement

Village/Guild now use `WorldBackdrop` with separate `hubs.*.lanes/plazas` in the
existing schema-3 manifest. These world-pixel marks add no collision and do not
inherit Wasteland basins or route geometry. Village retains `VillageTileMap` when
the optional material setup is unavailable; Guild retains its legacy floor path.
Placed feet wear road coverage back into the same earth, once after population.

`WorldProp.world_source_material` reuses the existing native cutout/root shader
for the hub sprites. The ground texture, region tint and contrast are sampled in
world coordinates within the existing 3–6-world-pixel contact band. It adds no
oval shadow or opaque platform. Source feet remain unscaled local pixels because
`MODEL_MATRIX` already includes Sprite2D scale. Saturation/exposure default to 1,
preserving other prop presentation; hub fixtures select 0.60/0.80, the forge
0.67/0.86, and residences/cisterns 0.80/0.90 to reduce the first draft's gold glare.

Two Village houses frame service streets at (940,580) and (1610,850); a Guild
lodge at (1040,285) completes its northern frontage. Entries live in the hub
manifest, with explicit small ground footprints. If a new footprint enlarged by
48 pixels contains the saved player position, that new building is omitted for
that entry rather than trapping the older save. Existing decorative blockers use
`preserve_legacy_collision`; station collision dimensions remain original.

The new open Village guild entrance and Guild travel gates replace their solid
old footprint with two edge piers, each 18% of the old width and inside its old
rectangle. Other counters remain solid. Village route gates remain nonblocking.
The Guild board moved from (330,275) to (330,390), with title/E prompt at its foot,
to avoid the west HUD. World interaction prompts draw above actors via z-index
10 while the HUD retains its own canvas layer. Physical traversal is unverified.

## Visible story consequence

The compact cistern stays at the former ending feature's (1510,940), nonblocking.
It is dry before `facility_memory` and uses the same stone/pipe composition with
water afterward. It adds no rewards, timer, interaction or persistent field. The
old native ending drawing remains a missing-art fallback. The matched screenshots
manually seed completion; they prove the appearance, not earning the ending or
persisting/reloading it.

## Review boundary

See `captures/hubs/README.md` and its source snapshot. Intermediate ordinary
renders exposed and led to fixing Rect2/typed-variable compilation errors, a
double-scaled foot calculation and an art-recipe route-index error. These failed
drafts are not acceptance evidence. Final logs record selected station atlas
rectangles/contact binding and actual Wasteland route identities.

Remaining: repeated gate silhouettes, sparse hub circulation, occasional secondary
world labels behind fixed HUD areas and whole-route composition. Neither source
selection nor screenshots prove walking clearance, save compatibility, reward
behavior, frame time, an export or release readiness. No QA suites ran.

繁體中文：本批將村莊、公會的石木設施、地面、住宅與水槽接入同一套材質系統。
先修正金色高光和腳邊硬接縫，再看完整遊戲鏡頭；入口重複、動線稀疏與全世界
構圖仍待改善。乾槽與回流水槽畫面為手動設定的美術狀態，不能當成主線通關測試。
