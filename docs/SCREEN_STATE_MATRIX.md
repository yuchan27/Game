# Screen and State Matrix

## 螢幕與狀態盤點

This is the canonical inventory of player-facing screens and their evidence. It
tracks reachability, exit paths, controls, scroll/focus behavior, viewport
coverage, and open acceptance. A listed image does not prove that a player can
reach the state or use its controls.

## Evidence baseline / 證據基準

- Latest passing isolated Godot 4.6.3 `visual` profile: run
  `20261025T020943Z-87d60cad`, report
  `C:\Users\wuwu6\AppData\Local\Temp\viewport-wide-to-800-20261025-1010\20261025T020943Z-87d60cad\qa-report.json`.
  It passed **29/29 QA steps**. VisualReviewRunner passed **77/77 captures and
  320/320 runtime checks** with 0 errors; the separate cold-narrow profile passed
  **11/11 captures and 53/53 checks**. In the after-start review, pause and the
  staged death-recovery modal were open at 1280×720, resized live to 800×600,
  and checked for in-bounds panels, reachable primary actions, retained focus,
  and restored focus. These captures are separate from the cold 800×600 title
  launch and do not show death recovery opened during cold startup. Source tree
  SHA256: `01b5f899e0f433a7c806eb1b2bcfe38b236fe169dc9c5a25ec316584bf172711`;
  full-resolution PNGs are under that run's `artifacts/visual/` directory.
  This evidence keeps 800×600 as a candidate physical window size; it does not
  establish a declared or enforced minimum or full-gameplay/release readiness.
- Earlier passing isolated Godot 4.6.3 `all` profile: run
  `20261025T003334Z-4f3daac4`, report root
  `C:\Users\wuwu6\AppData\Local\Temp\wasteland-release-qa\20261025T003334Z-4f3daac4\`.
  It passed **33/33 QA steps**. VisualReviewRunner passed **75/75 captures and
  308/308 runtime checks** with 0 errors; the cold physical 800x600 title launch
  passed **11/11 captures and 53/53 checks**. The title capture shows I/C/J/T/K/
  G/M/H village controls. This does not declare 800x600 a supported minimum or
  establish full-gameplay/release readiness.
- Adaptive atlas coverage uses actual windows 1280x720, 1024x768, 760x900 and
  560x900. Integrated WorldAtlasRegression passed 300/300; the standalone
  focused atlas run passed 308/308. Narrow maps stack, and route/marker/detail
  content remains scroll-reachable. The 800x600 cold visual still uses a
  1024x768 logical viewport.
- The existing-save new-journey confirmation was opened through the actual
  title input path, then live-resized from 1280x720 to 800x600. Runtime checks
  confirmed the Cancel button retained focus, the initial dialog measured
  480×115 logical pixels (≤160px assertion), and it stayed within the tested
  width. Its full-resolution capture is
  `new_game_existing_save_confirmation_resize_800x600.png`.
- The locked terminal was live-resized from two columns at 1280x720 to one at
  800x600 and restored to two columns. Its capture is
  `terminal_locked_resize_800x600.png`; the recipe and journey content now align
  to the top at natural height instead of stretching to fill the modal.
- The field minimap remained visible and inside the same Wasteland HUD at
  1280x720 and 800x600. At 800x600 it did not overlap the status or quest panel.
  `field_minimap_resize_800x600.png` records the narrow output. The full-screen
  map and map view also stayed visible and in bounds while open through the same
  1280x720→800x600 resize; see `full_map_resize_800x600.png`.
- The focused title path clicks New Game with an existing save, cancels with
  Escape, reopens and confirms with Enter, keeps the save unchanged through the
  prologue, then reaches Village through the real SceneRouter before replacing
  it. J input checks report mouse wheel `0→69` (maximum 84) and PageDown `0→84`.
  At an 800x600 output, active-task and catalogue text render at 14.1px and
  15.6px respectively; 1280x720 base sizes remain unchanged. Screenshots include
  `new_game_existing_save_confirmation`, `contract`, `contract_resize_800x600`,
  `story_site_scrap_highway` and `intro` under `artifacts/visual/`; cold narrow
  captures are under `artifacts/visual/cold_narrow/`.
- Project: Godot 4.6.3, PC-first. `project.godot` sets a 1024×720 logical
  viewport, a 1280×720 window override, `canvas_items` stretch, and `expand`
  aspect behavior.
- This integrated run passed 33/33 QA steps. AutomatedPlaytestRunner
  passed 165/165; CollisionRegressionRunner passed 52/52; WorldExpansionRunner
  passed 192/192. Full scope and limitations are in [QA_REPORT.md](QA_REPORT.md).
- The cold process's first capture is the real initial 800×600 title window.
  After that, the runner calls the prologue helper directly, instantiates Village,
  and sends keyboard events to open HUD panels. These captures verify each
  staged panel's bounds/focus after a cold narrow launch; they do not prove the
  new-game route or all player-reachable states. At 800×600 output, the content
  viewport remains 1024×768 under the configured stretch mode. This is candidate
  physical-window evidence, not a declared minimum or proof of 800×600 logical
  reflow. The 960×768 inventory capture uses a 1024×819 content viewport and
  passes the stacked-orientation assertion.
- The current 800×600 and 960×600 J-panel live-resize captures were taken after
  the runner started wide; they remain separate from the cold-window evidence.
- The integrated profile captures the J task hierarchy, inventory, expedition
  draft, campaign choice, six field routes and story sites. The Scrap Highway
  bus is now fully visible in the story-site frame and does not obstruct the
  authored road. A separate bounded first-outing walk passed 165/165 and reached
  the physical return gate, confirming E activation and settlement. That runner
  disables enemies during traversal, suppresses scene replacement and stages
  later hand-in progress; this is not a complete journey.

Evidence labels:

- **Runtime (snapshot):** the runner executed assertions on the recorded source
  snapshot. This does not transfer to later source edits.
- **Capture:** a PNG exists; the state may have been staged by calling methods,
  setting game data, teleporting the player, or emitting a signal.
- **Source reviewed:** current code shows a path or layout, but this turn did not
  establish it through current runtime input.
- **Open:** required behavior or visual acceptance has no sufficient evidence.

## Shared navigation contract / 共用操作

Current source routes the HUD hotkeys as follows: I opens equipment/inventory,
C the workshop, J contracts, T the terminal, K the journal, G the world atlas,
M the regional map, H help, and Esc closes the active reading panel or toggles
pause. Opening a modal assigns an initial focus target; Tab uses Godot's normal
focus-next navigation. The inventory check confirms one Tab press advances focus
without closing it, but full traversal and confinement to each modal are not
verified. E is the field/NPC interaction key. These labels and their
InputMap/source owners need a drift check whenever bindings change. Mouse
activation is present on many controls, but mouse reachability has not been
broadly exercised.

## Player-facing inventory / 玩家畫面盤點

| Surface / state | Reach and exit path in current source | Evidence and viewport | Status / remaining acceptance |
| --- | --- | --- | --- |
| Title, new-journey confirmation, continue failure | Start opens the new-journey path; existing-save replacement asks for confirmation; Continue loads a save; Esc/back returns to the prior title state. | Current `main_title`, `continue_load_failure`, `new_game_existing_save_confirmation`, and `new_game_existing_save_confirmation_resize_800x600`; cold 800×600 title capture. | Current capture visibly lists the in-village I/C/J/T/K/G/M/H controls. Input opens the existing-save prompt, Escape cancels, Enter confirms, and stale Continue error copy clears. The 1280→800×600 live resize kept Cancel focus and the dialog within the tested window width. The fixture save remains unchanged until new-game entry reaches Village; SceneRouter performs the actual transition. This does not declare 800×600 as minimum support. |
| Prologue / intro | New journey shows the prologue; Enter or the visible village-entry button proceeds. | Current `intro`, plus cold 800×600 output. | Current-source title flow reaches prologue and Village by player input; the save changes only on Village entry. Cold narrow panel setup is separately staged. Logical viewport remains 1024×768. |
| Village HUD and services | Enter Village through the scene flow; walk to a service/NPC/route gate and press E. Services include workshop/save/repair paths; gates enter a route. | Current `village_hud` at 1280×720 and `quest_progress_1024x768`; additional 1280×720/1024×768 HUD evidence. | Current capture; full player-walk service and gate navigation remain open. |
| Guild HUD, board, counter, route gate | Enter Guild; walk to a board, counter, or gate and press E. Return gate leads back to Village. | Current `guild_hud` at 1280×720; older staged `docs/story-presentation/1024x768/guild-contract.png`. | Current HUD capture and automated board/contract assertions. QA places the test player by the board; walking to the board, all services and physical return gate remain open. |
| J contracts: active, ready, completed, optional clues, catalogue | J opens; Esc closes. Current-source runner exercises PageDown, mouse wheel, focus scrolling, keyboard accept/claim and disclosure. | Current `contract`, `contract_1024x768`, live resize at 800×600/960×600 and cold `contract_cold_800x600`; integrated `artifacts/visual/visual_review_report.json`. | Opening J focuses fixed `ModalTab_contract` and resets `ContractScroll` to 0; full, cold, and reopen checks verify the initial view. Scroll checks: wheel `0→69` (max 84); PageDown `0→84` (max 84). At 800×600 output, active-task text is 14.1px and catalogue text 15.6px. Full modal focus traversal remains open; cold panel content is staged. |
| Inventory and equipment | I opens; Esc closes. Initial focus is assigned; one Tab press advances focus without toggling the inventory. Equipment slots and bag rows are source-built; item actions are button-driven. | Current `inventory`, `inventory_1024x768`, `inventory_resize_960x768`, and `cold_narrow/inventory_cold_800x600`; 1280×720, 1024×768 and 960×768 content/output evidence. | The 960×768 capture passes the stacked-orientation assertion (content viewport 1024×819). Cold check opens by I and confirms first focus inside the visible panel. Empty-bag feedback, item-use/equip input, full Tab traversal and modal confinement remain open. |
| Workshop: craft, forge, mod, perk, recycle | C opens; Esc closes. Visible tabs switch workshop modes. | Current `workshop`, `workshop_1024x768`, and `cold_narrow/workshop_cold_800x600`. | Cold input opens by C and checks first focus plus bounds. Tab selection, crafting/recycling outcomes, failure/empty states and mouse-wheel behavior remain open. |
| Terminal: locked and unlocked supplies | T opens; Esc closes. Terminal cards depend on progression and supply state. | Current `terminal`, `terminal_1024x768`, `terminal_locked_resize_800x600`, and `cold_narrow/terminal_cold_800x600`; cold input opens by T. | Locked cards reflow from two columns at 1280×720 to one at 800×600, then restore after resizing back; the full-resolution frame confirms top-aligned natural-height content. First focus and modal bounds pass. Unlocked stock, empty-stock, failed transaction and actual transaction input remain open. |
| K journal / codex: unknown, discovered, completed | K opens; Esc closes. Journal owns a reading pause. | Current `story_journal`, `story_journal_1024x768`, and `cold_narrow/journal_cold_800x600`; cold input opens by K. | Current runtime assertions check hidden revelations and pause release; cold check verifies bounds and initial focus. Populated discovery/completion states, long-entry scroll and mouse-wheel behavior remain open. |
| G world atlas and route details | G opens; Esc closes. Route buttons change the detail pane; route launch remains a separate world interaction. | Current `world_atlas`, `world_atlas_1024x768`, and `cold_narrow/atlas_cold_800x600`; WorldAtlasRegression at four actual sizes. | Integrated atlas regression passed 300/300; focused four-size regression passed 308/308. At 760x900 and 560x900, the map and route details stack; all six route buttons, markers, details and footer are scroll-reachable. The atlas tests activate controls through the runner; real mouse and arrow/Enter navigation and full Tab order remain open. |
| M regional map and always-visible minimap | M toggles the full regional map; Esc closes it. Minimap is part of the field HUD. | Current `full_map`, `full_map_1024x768`, `full_map_resize_800x600`, `cold_narrow/map_cold_800x600`, and `exploration_crystal`. Physical 800x600 renders a 1024x768 logical viewport. Cold input opens by M. | Same field minimap and full-screen map are checked through live 1280x720→800x600 resize while visible, then restored; both map panel and map view stay in bounds. Minimap avoids the status/quest panels at 800. Click/zoom/navigation and live marker interaction remain open. |
| H help / tutorial | H opens or toggles help; Esc, H, or the close button exits. Content uses a scroll region. | Current `tutorial`, staged controls/journey captures at `docs/onboarding-journey/1024x768/`, and targeted cold report `C:\Users\wuwu6\AppData\Local\Temp\first-game-tutorial-interaction-qa\diagnostic-mouse-click-02\visual-attempt19-keyboard-close-clean\visual_review_report.json`. | Targeted cold review passed 11 captures/53 checks: H open, initial focus, Tab remains inside, wheel 0→62/518, Enter activates the close button and releases the reading pause, H reopens, Esc closes. OS mouse-click delivery and complete focus traversal remain open. This is not a full QA rerun. Key labels should match InputMap/source. |
| NPC dialogue and reports | Approach an NPC and press E; E advances/ends pages; Esc closes. Leaving interaction range resets ownership. | Current `dialogue` and `dialogue_1024x768`; older staged dialogue pages are in `docs/story-seams/`. | Current capture and source review. Runner invokes NPC interaction directly. E page flow, interrupt/range exit, repeated interaction, long Traditional Chinese text at narrow widths and mouse/focus behavior remain open. |
| Esc pause and save/load feedback | Esc toggles pause. Resume, save/load, title and quit are visible actions. Pending load disables conflicting actions; Esc exits the pause view. | Current `pause`, `pause_resize_800x600`, save/load feedback captures and 1024×768 counterparts; `cold_narrow/pause_cold_800x600` opens by Esc and confirms initial focus. | After-start review opens pause at 1280×720, then live-resizes to 800×600; the panel and Continue action remain in bounds, enabled and focused, with focus restored after resizing back. This is separate from the cold 800×600 pause capture. Staged feedback does not prove real save success/failure, pending-load IO or rollback. Full focus traversal and real IO remain open. |
| Death / recovery | On death the recovery panel offers E or a button to retry; Esc can open pause. Automatic recovery is also source-defined. | Current `death`, `death_1024x768` and `death_resize_800x600`; 1280×720, 1024×768 and after-start 800×600. | The staged recovery modal is opened in the wide review, then live-resized to 800×600. Its panel and retry action stay in bounds; the enabled retry action keeps focus and focus restores after resizing back. This does not prove the natural HUD death transition, E/button activation or recovery transaction. Recovery IO and player-visible timing remain open. |
| Expedition draft and campaign choice | A cleared, claimable cache offers the run-local draft. E at a ready authored campaign choice opens its modal. Esc defers either choice; selecting a card applies the run-local result and returns to play. | Current captures `expedition_draft`, `expedition_draft_960x768`, `campaign_choice`, `campaign_choice_960x768`; 1280×720 and 960×768. | Current captures verify presentation and bounds. Player selection/reopen, actual consequence, save/resume, cold narrow startup and input acceptance remain open. |
| Six field routes, combat HUD, boss, landmarks, exploration prompts | Enter a route from a village gate; move, attack, interact with the nearest target and reach the return gate to extract. | Current `route_*` for six regions, `boss`, four `landmark_*`, `exploration_scrap`, `exploration_crystal`, `story_site_*` for six sites and `player_walk/slash/shoot`; latest full visual profile at 800×600 physical / 1024×768 logical. Full map also has a 1024×768 capture. | The 109/109 first-contract journey verifies two Scrap Highway outings, actual departure/extraction gates, active combat, Guild hand-in and save reload via the covered-long route. WorldExpansionRunner passed 192/192 and CollisionRegressionRunner 52/52. Other routes, the exposed-short option, later chapters, death and human combat balance remain open. **P1 gameplay gap.** |
| Physical extraction, village return, settlement and debrief | Walk to and activate the route exit; return to Village; review extracted/lost work and submit the matching contract once. | Route data places each of six return gates at the far-side terminal road. The direct first-outing run confirms Scrap Highway walking, physical gate E activation, settlement and objective retention. | The test suppresses SceneRouter replacement after the real gate signal and later uses a campaign fixture for hand-in. Village departure/return, an unstaged delivery, duplicate reward protection and resulting story state in one player journey remain open. **P1 gameplay gap.** |
| Scene entrance transition | Triggered by scene routing/arrival; entrance UI should return control after its transition. | Current `scene_entrance` at 1280×720; SceneEntranceRegression passed 12 checks including real scene replacement. | Current capture and transition regression. No narrow capture or interrupted-transition input test. |
| Story discovery, journal progress, chapter ending | Discover authored sites through a route and resolve chapter actions through return/hand-in. | Current `story_discovery`, `story_ending`, six `story_site_*` and fresh-game journal captures; 1280×720 except journal 1024×768. | Current staged captures. Runner assigns quest completions and directly invokes site setup, so it does not demonstrate a player-earned story arc or persistence. Populated journal and branching consequence review remain open. |

## Priority gaps / 優先缺口

These are evidence and acceptance gaps, not confirmed product defects:

1. **P1 — complete player-controlled outing:** the direct runner moves the
   first Scrap Highway outing to the far-side gate with automated input and confirms gate E
   activation and settlement. It creates Wasteland directly after contract
   acceptance, disables enemies during the walk, suppresses the real scene
   replacement and stages hand-in progress. Village gate travel, real return and
   unstaged delivery have not been run as one player path.
2. **P2 — real interaction coverage:** atlas keyboard navigation, full panel
   focus order/confinement and several choice states are source-backed or
   captured but not exercised through player inputs. Current checks cover
   initial focus, one Tab advance, and J mouse-wheel/PageDown scrolling.
3. **P2 — responsive window boundary:** the 800×600 output profile captures
   the field route/minimap and the separate cold launch captures 11 staged
   screens. The same field minimap, full-screen map, pause modal and staged death
   recovery modal now pass live resize bounds/reachability checks while open.
   The 800×600 content viewport remains 1024×768 under canvas stretch. The game's
   minimum supported window and true logical reflow boundary remain undecided;
   800×600 is candidate output evidence, not a release support claim.
4. **P3 — content-state completeness:** inventory empty state, discovered and
   completed journal content, unlocked terminal stock and several workshop
   failure states need explicit review if reachable under normal game rules.

## Next work / 下一步

The current visual run adds wide-to-800 live-resize coverage for pause and the
staged death-recovery modal, alongside the existing-save confirmation, locked
terminal, in-field minimap and full-screen map. Its cold-narrow run separately
captures 11 screens, including the title and pause; it does not cold-open death
recovery. The first contract still has a separate 109/109 player-input journey
through Village, Guild, both Scrap Highway outings, actual extractions and
one-time delivery; other chapters and route journeys remain open. Screen
acceptance still needs map click/zoom/navigation, complete modal focus
order/confinement, broad mouse reachability, and reachable empty/error/success
states. Decide and record the minimum supported viewport using cold and
live-resize runs; 800×600 remains a candidate. Preserve quest IDs and save
compatibility. Do not turn staged screens into reachability evidence or
historical counts into a current pass.

繁體中文摘要：最新隔離 Godot 4.6.3 `visual` QA（`20261025T020943Z-87d60cad`）通過 29/29 階段；畫面檢視通過 77/77 張截圖及 320/320 項檢查，冷啟動窄視窗通過 11/11 張及 53/53 項。Pause 與 staged death recovery 先在 1280×720 開啟，再 live-resize 至 800×600；面板、主要按鈕邊界與焦點檢查通過。這和 cold 800×600 標題及 pause 證據分開，並未在冷啟動時打開 death recovery。先前 `all` QA（`20261025T003334Z-4f3daac4`）為 33/33。圖鑑在 1280×720、1024×768、760×900、560×900 皆通過回歸。首章另有 109/109 項鍵盤輸入旅程，完成兩趟、實體撤離、公會交付、存檔重載與防重複發獎；其他章節與路線仍待實玩。800×600 實際視窗仍使用 1024×768 邏輯畫布，僅列為候選視窗尺寸，尚未宣告為最低規格或由視窗設定強制。地圖滑鼠／鍵盤導覽、完整焦點循環、其他章節與可達的空／錯誤／成功狀態仍待驗收。
