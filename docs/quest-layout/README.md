# J Contract Layout

Updated 2026-10-25. This increment reshapes the existing J contract panel while
preserving the current GameState readiness, accept/deliver callbacks, and native
modal/navigation structure.

## Delivered

- Put the active contract, route, current next step, mandatory checklist,
  separate optional reading, return/delivery condition, reward and existing
  claim button in one first-screen card.
- Keep the selected contract out of the other-contract catalogue. Group the
  remaining catalogue by available, waiting, completed and locked status; show
  its existing details behind native disclosure controls.
- Keep the story summary, full briefing, field notes, current outing guide and
  complete delivery/evacuation rules behind expandable rows. The ordinary rules
  row was opened in a separate capture to review its long copy and scrolling.
- Keep close and tab navigation above the scroll container. The active
  requirements retain their existing `ContractRequirements` name and readiness
  source; optional objectives remain informational.
- When all goals are ready in the field, the J card now directs the player to
  evacuate through the M return gate and use the visible delivery button after
  returning. The shared journey hint and delivery backend were not changed.
- When the ready contract is open in town, its next-step line also points to the
  visible delivery button below, avoiding a redundant instruction to press J
  while that panel is already open. Button enablement still uses existing
  readiness and location guards.
- Add a frozen, isolated native-scene preview recipe. It absorbs window input,
  stops HUD polling/input processing, and disconnects button callbacks before
  capture while retaining their appearance. The view states are staged directly
  in memory.

## Visual review

Engine: Godot 4.6.3. Native screenshots use the existing village scene, or the
wasteland scene for the in-field case. The comparison HUD is the exact earlier
source hash recorded below. The frozen final images represent the HUD at their
capture-time source; later edits mean they are historical layout evidence, not a
snapshot of every current-source detail.

| Capture | 1280x720 | 1024x768 |
| --- | --- | --- |
| Previous layout, no active contract | [image](baseline/1280x720/no-active-hub.png) | [image](baseline/1024x768/no-active-hub.png) |
| Previous layout, provisional city return | [image](baseline/1280x720/city-provisional-field.png) | [image](baseline/1024x768/city-provisional-field.png) |
| No active contract | [image](final/1280x720/no-active-hub.png) | [image](final/1024x768/no-active-hub.png) |
| First highway outing | [image](final/1280x720/highway-first-outing.png) | [image](final/1024x768/highway-first-outing.png) |
| City outing awaiting safe return | [image](final/1280x720/city-provisional-field.png) | [image](final/1024x768/city-provisional-field.png) |
| City chapter ready to deliver | [image](final/1280x720/city-ready-hub.png) | [image](final/1024x768/city-ready-hub.png) |
| Unmarked legacy contract | [image](final/1280x720/legacy-ready-hub.png) | [image](final/1024x768/legacy-ready-hub.png) |
| Catalogue scroll end | [image](final/1280x720/catalogue-bottom.png) | [image](final/1024x768/catalogue-bottom.png) |
| Expanded complete rules | [image](final/1280x720/expanded-rules.png) | [image](final/1024x768/expanded-rules.png) |

The lead opened and reviewed all 14 final images and the four baseline images;
the ready-in-town wide and narrow frames were reopened after the final copy edit.
The current task and checklist are immediately visible; optional clues are
separate from required progress; return state and the existing button are
readable. No horizontal text/button clipping was observed. Longer rules and
catalogue entries remain in the native scroll region; the tab/close row stays
outside it at both tested viewport sizes.

The later isolated current-source visual profile also captures the same active
`old_factory_core` state at1280x720 and1024x768, plus live resize/open views at
800x600 and960x600. Its fixture stages the same route, enemy progress and carried
core before the full-size captures and asserts that state at the narrower size.
The current automated Guild flow verifies E-to-open, keyboard accept/claim, and
at800x600 expands the completed group, focuses the final row into view, expands
its details and closes with Escape. The 2026-10-25 integrated visual-profile QA
also verifies the J entry state after ordinary open, cold launch and reopen:
focus stays on the fixed `ModalTab_contract`, and `ContractScroll` starts at 0.
The lower catalogue remains scrollable; wheel and PageDown use were exercised.
Traversal of every entry and full modal focus cycling remain unverified. See the
current run in [`../QA_REPORT.md`](../QA_REPORT.md).

## Latest integrated task-screen verification

The latest 2026-10-25 integrated visual-profile QA run
`20261024T205213Z-af013aa7` records 71/71 captures and 290/290 runtime checks
with zero errors. It checks the J contract page at 1280x720 and after a live
resize to 800x600, including active-task typography and both catalogue groups.
When logical content is downscaled, task labels compensate using the physical
output scale, clamped at 0.75; the 1280x720 base font sizes do not change. At
800x600 output, the active-task label renders at 14.1px and catalogue text at
15.6px. A separate cold 800x600 startup confirms 11/11 captures and 45/45
checks with zero errors, while retaining a 1024x768 logical viewport. Reports:
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated\20261024T205213Z-af013aa7\artifacts\visual\visual_review_report.json`
and
`C:\Users\wuwu6\AppData\Local\Temp\first-game-qa-adaptivity-800-integrated\20261024T205213Z-af013aa7\artifacts\visual\cold_narrow\visual_review_report.json`.

The same current-source pass exercises J wheel scroll (`0→69`, maximum 84) and
PageDown (`0→84`, maximum 84). The checks confirm content remains reachable
through the scroll container after a resize. Opening J now fixes initial focus
to `ModalTab_contract` and resets the scroll region to the top; the entry state
is asserted on ordinary open, cold open and reopen. These checks do not establish
complete keyboard focus traversal or a minimum supported window size. The cold
800x600 process keeps the 1024x768 logical viewport, so it is not evidence of
true 800x600 logical reflow. Frozen preview PNGs above remain historical images.

The integrated `story_site_scrap_highway.png` capture also confirms the Scrap
Highway bus landmark is fully visible in the play view after its walk-up anchor
was reframed. The same run passed CollisionRegressionRunner 52/52 and
WorldExpansionRunner 192/192, including the corrected road-clearance sampler.
See the QA report for complete scope; a bounded physical first-outing walk still
suppresses the actual return scene replacement and uses a progress fixture for
later Guild hand-in, so the end-to-end journey remains open.

## Capture and verification boundary

Four engine processes produced four baseline frames and fourteen final frames.
Each frame saved with result `0`; all four observed process exits were `0`.
The final process logs report the HUD input guard and disconnected-button
callback counts. This is an ordinary visual presentation pass, not a gameplay
or QA run.

The preview freezes native scene actors, pauses the tree, absorbs input, and
removes button callbacks. It stages example quest/campaign/expedition values in
RAM; it does not accept or complete quests, deliver rewards, settle an outing,
exercise keyboard/mouse focus, or call SaveManager. `legacy-ready-hub` checks
the old unmarked quest-requirement path; it does not stage the legacy in-field
expedition banking branch. The real save payload was not read or written.

The 113 root/mirror input hashes in the snapshot describe the render-time source.
The six main-quest descriptions and Ada's final NPC response were edited after
those captures. They are listed as post-capture deltas; quest background rows
were collapsed in all captured J views and no NPC dialogue was staged, so the
screenshots verify J layout rather than those new story lines.

The original frozen preview did not run a test or QA suite. Later current-source
QA covers the bounded Guild keyboard path and selected window sizes. The direct
165/165 playtest also verifies a bounded first Scrap Highway walk through
physical return-gate E activation and safe settlement. Its runner suppresses the
gate's actual SceneRouter replacement and uses a campaign fixture before Guild
delivery, so it is not a complete return-to-Village or hand-in persistence
check. Mouse clicking, save/load compatibility, arbitrary window resizing and
full release acceptance remain unverified.

## Portable capture recipe

`QuestLayoutPreview.gd.txt` and `QuestLayoutPreview.tscn.txt` are source-only
fixtures. Copy them into an isolated full-project mirror as
`QuestLayoutPreview.gd` and `QuestLayoutPreview.tscn`; never place the fixture
in the production project. Preserve its custom user-directory guard and pass an
absolute `--quest-output=` path. The complete seven-view matrix runs by default;
`--quest-views=` can select a comma-separated subset. See
[`source_snapshot.json`](source_snapshot.json) for source hashes, process logs,
view states, output hashes and the metadata-only save boundary.

## 繁體中文摘要

J 任務頁先顯示目前委託、下一步、必要進度、選讀線索、返村／交付條件
與原有交付按鈕；故事、完整說明、現場紀錄、章節指引及完整規則收在可展開
區域。田野待撤離時會提示先走 M 返村門；返村且達成交付條件後，下一步會提示
使用卡片下方的按鈕。已接取委託不會重複出現在委託清單；導覽列和關閉按鈕
固定在捲動區外。

已用 1280x720 與 1024x768 檢視 14 張新版畫面。原始預覽是隔離場景的靜態呈現；
後續整合視覺 QA 在一般開啟、冷啟動與重新開啟時確認 J 頁固定聚焦
`ModalTab_contract`，且委託捲動從頂端開始；滑鼠滾輪和 PageDown 也都能捲動目錄。
800×600 輸出下冷啟動畫面另通過 11/11 張截圖和 45/45 項檢查，但邏輯畫面仍為
1024×768，不能據此宣稱支援 800×600 邏輯重排。公車地標已完整入鏡，道路碰撞與
世界範圍檢查分別通過 52/52 與 192/192。直接自動玩法步行到首趟廢鐵公路撤離閘，
但它抑制實際返村切場，後續交付仍用進度 fixture；真實返村交付、存檔相容與完整
出征仍待驗收。
