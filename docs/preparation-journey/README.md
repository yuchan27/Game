# Preparation, salvage and recovery presentation

Historical source snapshot: [load-consistency](../load-consistency/README.md)
records later Main/HUD/autoload changes. Preserve these34 images and original
hashes; they do not identify the later transaction implementation.

2026-10-24. Ordinary frozen native presentation, **not QA or a played run**.
[Source snapshot](source_snapshot.json) records bounded inputs, five product-file
changes, final renders, the layout baseline and rejected intermediate results.

## Integrated behavior

- Workshop cards derive their one/two-column widths from the allocated panel,
  margins, borders and scrollbar. Prose/costs wrap; weapon stars and perk levels
  stay on one line. A coalesced resize refresh rebuilds visible workshop content.
- Inventory/workshop/contracts/terminal/notes keep navigation and close outside
  their scrolls. Original lists remain direct SC children; groups/masks/callbacks
  remain. Workshop tab changes reset scroll, same-tab refresh preserves it.
- Resources are labelled non-equippable status cards; gear retains equip buttons.
  Ammo displays usable banked+haul counts; selecting a resource consumes nothing
  and explains the melee fallback. Field workshop says to return to a hub.
- Tool scan queries current-scene uncollected pickups/unharvested resources
  within520 world units, nearest first, max6. Claimed sources are excluded.
  Targets receive a1.8-second native pulse; empty results say so. No loot, claim,
  lore or persistent marker is granted. Its own0.7-second cooldown leaves melee/
  ranged cooldowns alone; the existing0.20-second interaction pose remains.
- Melee/ranged damage pass the actual weapon ID to rank calculation, including
  Space/right-click shortcuts. Existing equipped flat bonuses remain unchanged.
- Failed automatic death travel can be retried from Esc pause through guarded
  clinic travel. Healing/loss settlement still waits for successful arrival.
- Controller obtain text now describes existing T route information/hub supply,
  instead of unsupported remote control/decryption. No save schema changed.

## Evidence

| Native render | Completed process | Output |
| --- | --- | --- |
|1024x768|session70308, observed exit0|17 frames; [narrow.log](narrow.log)|
|1280x720|session87168, observed exit0|17 frames; [wide.log](wide.log)|

No ERROR/WARNING lines were observed. All112 listed source/mirror inputs and
recipe/stub hashes match; this is not every asset. Every final PNG is the full
requested viewport. Independent Luna/max reviewers opened all14 workshop and
all16 inventory/contract/terminal/notes frames. Parent inspected four recovery/
scan frames, narrow Mod/field-tail/terminal and representative baseline defects.
The workshop reviewer later disputed header visibility in four tails. Parent
reopened those exact four full-viewport PNGs at original detail and confirmed
the navigation and close row in each. That direct recheck resolved the report;
no material visible defect was found in the bounded final set.

Ten [baseline frames](baseline/) use the same frozen inventory/workshop setup
before responsive/card/navigation changes, after initial scan/recovery edits.
Their112 hashes differ from the earlier
[onboarding snapshot](../onboarding-journey/source_snapshot.json), which supplies
the five product files' before hashes. Baseline sessions47236/46361 exited0.
Narrow craft/mod/forge/perk horizontal overflow was162/72/74/82px; wide craft42px.
Final images, not disabled horizontal bars alone, establish visible correction.
These are layout measurements, not performance results.

| Before | Final |
| --- | --- |
|[Narrow crafting](baseline/1024x768/workshop-craft-top.png)|[Crafting](1024x768/workshop-craft-top.png)|
|[Forge](baseline/1024x768/workshop-forge.png)|[Forge](1024x768/workshop-forge.png)|
|[Perks](baseline/1024x768/workshop-perks-top.png)|[Perks](1024x768/workshop-perks-top.png)|
|[Rejected badge](rejected/mod-stars-vertical-1024x768.png)|[Weapon ranks](1024x768/workshop-mod.png)|

Four intermediate renders completed but were rejected: perk labels first wrapped
vertically, then weapon stars wrapped and navigation scrolled away. Their
`*-draft-levels.log` / `*-draft-navigation.log` and two selected rejected images
remain separate. Exit0 did not mean visual acceptance. Source review also removed
an invalid remove_child on an unparented scroll before the final renders; that
source draft was not rendered. Recycle deliberately captures the tail, not a tab
entry. Long profile content remains scrollable; terminal retains right-side space.

## Reproduce and limitations

Use a separate project mirror, custom user directory exactly
`R17-Ordinary-Art-Preview-20261023`. Preserve source project.godot and real saves.
Copy [recipe](PreparationJourneyPreview.gd.txt) and
[stub](PreparationJourneyPreview.tscn.txt) into the mirror without `.txt`.
Verify the discovered Godot4.6.3 executable first:

```powershell
& $godot --path $isolatedMirror --rendering-method gl_compatibility `
  --resolution 1024x768 res://PreparationJourneyPreview.tscn -- `
  --prep-output=C:\absolute\new-output\1024x768
```

Default17 views; `--prep-views=baseline` selects five; comma-separated names
select subsets. Use a new output directory for a later source version.

Scenes/actors are disabled before entry; HUD/camera render while paused. Stock,
haul, drafts, legacy marker, HP0 and death_pending are assigned in RAM. Scan uses
only query/draw helpers, not the tool-action/input callback; both sizes stage one
actual alloy node. Recovery shows UI, not a death animation/retry. Tool selection
still uses the baked sword-body fallback; no new raster/action pose is claimed.

No input/focus, crafting/equipment/upgrade/supply, pickup/harvest, combat/cooldown,
actual death/retry/travel/extraction, quest/reward, save/load payload IO/migration,
collision, live resizing, pacing, performance, export or QA ran. Real-save stat
remains1203bytes /1792682904815624900ns; payload unread/unwritten. Asynchronous
load rollback was open at this snapshot; the later load-consistency record now
describes its source correction and deferred IO/fault acceptance. These frames
do not establish that behavior or close the full production ledger.

繁體中文：整備卡片、固定頁籤／關閉、資源說明與實際掃描已接入；34張預置畫面
涵蓋兩種視窗。尚未實際製作、戰鬥、回收或存讀檔，不代表完整遊戲驗收。
