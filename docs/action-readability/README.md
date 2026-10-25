# Field-action readability and truthful terminal

Historical snapshot. The subsequent
[UI label composition record](../ui-label-composition/README.md) integrates
world-label/HUD occlusion and full-map priority/callouts. Preserve this record's
original22 PNGs, logs and source identity; its remaining issues below describe
the source at capture time.

2026-10-24, Asia/Taipei. Ordinary presentation production; no tests/QA.

The HUD now shows the current outing's first ready/active action through the
read-only `CampaignAction.presentation_state()` adapter. It keeps wait reasons
and progress visible together, with a bounded four-Hz refresh. The HUD card hides
under modals, during transitions/death, outside the field and after completion.
The escort's floating label follows its actual actor rather than the start site.
This changes presentation, not action timers, wave scans, rewards or persistence.

T now reads all six main contracts and their real route data. It displays current
quest status, recommended level, deduplicated resources and enemies; locked
catalogue entries do not reveal action outcomes or story revelations. Missing
controller materials come from the current recipe. Map and notes buttons use
existing panels; supply retains the hub-only 20 scrap -> 16 ammo + 1 alloy plate
exchange and checks successful consumption. Invented scan percentages, satellite
claims and conflicting old setting paragraphs were removed.

## Recorded output

- Eleven PNGs per size, 22 total: escort following/waiting, carry ambush,
  defense pressure, channel progress, terminal top/locked/scroll tail, map,
  contract modal and outing finished. See [1280x720](1280x720/terminal.png) and
  [1024x768](1024x768/terminal.png).
- Godot `4.6.3.stable.official.7d41c59c4`, Compatibility/Intel Arc140V.
  Final wide process session51938 and narrow session13266 both exited0; each log
  has eleven successful frame records and no observed error/warning lines.
- [Source identity](source_snapshot.json):112 listed source/mirror inputs match;
  recipe, log and22 PNG hashes are recorded. The mirror keeps its separate custom
  user directory. Real save metadata remains1203 bytes/1792682904815624900ns;
  its payload was not read or written.
- Gemini3.8 Flash medium authored the [recipe](ActionReadabilityPreview.gd.txt).
  Lead review rejected an invented `equipped_tool` field; the corrected fixture
  uses the actual `equipment.tool` gate. CLI receipts are recorded in the snapshot.
  Parent inspected nine targeted final images, including both terminal tops,
  narrow locked/scroll-tail, escort follow/wait, defense, map and contract modal.

## Boundary and remaining work

The recipe assigns runtime/wait/quest fields directly, disables scene simulation,
resets the camera and existing architecture occlusion, hides the entry notice,
and sets terminal scroll positions. The escort fixture moves its actor900 world
pixels from the original site. This shows native presentation of staged values;
it does not establish actual escort movement, enemy pauses, channel input, button
activation, crafting, supply delivery, settlement, quest completion, collision,
save/load, frame-time or whole-campaign behavior. Fixture quest/lore states are
not a naturally progressed playthrough.

The floating world label can still run behind the HUD (visible in escort-follow)
and does not share every HUD modal/death guard. That presentation issue and the
full map's dense label spacing remain open; this is not whole-interface or
whole-world composition approval. Earlier [story captures](../story-continuation/README.md)
retain their original hashes and are historical.

繁體中文：現場提示會同時顯示等待原因與進度，護送標籤跟隨隊員；終端改讀
真實六路線資料及工坊配方。22張預置畫面已輸出，沒有操作通關、領獎、存檔
或跑測試；漂浮標籤與HUD重疊等問題仍須接續處理。
