# Current technical handoff

Updated: 2026-10-25 (Asia/Taipei). Read `AGENTS.md` before editing.

## Goal and workspace

The user wants a coherent story and enjoyable, playable expedition loop before the next broad art pass. Preserve the existing Godot game and complete the current plan incrementally. A final GitHub upload is explicitly authorized, but only after the changed scope and validation are reviewed; never force-push.

- Git/Godot root: `C:\Code\Game\first-game` (`C:\Code\Game` is only the parent workspace).
- Branch: `codex/story-and-scene-pass`; starting HEAD: `4ab05f086f720273fc78db34d50d423997deb301`.
- Verified engine: Godot `4.6.3.stable.official.7d41c59c4`.
- The tree contains extensive existing modifications, deletions, untracked game assets and visual-review history. Preserve it; do not reset, clean, or stage everything with `git add .`.
- Never read or write the real player save. All journeys use Temp profiles.
- User project instructions require task subagents to use `gpt-6-luna` / `max`; do not use Gemini or create user-facing side chats.

## Design contracts

- Six contracts and twelve authored outings. Chapters 1–4 are available in free order; Chapter 5 follows the first four; Chapter 6 follows Chapter 5.
- Keep quest/action IDs, prerequisites, reward amounts, one-active-contract behavior, save shape, and settlement rules stable. Preserve optional, discovery-gated evidence.
- First outings bank haul only on safe extraction; Guild hand-in completes the contract and prevents duplicate rewards.
- Current story centers on rationed village water, staged sample evidence, Alan's consent-limited archive decision, and a finite-water ending. Do not reveal optional findings before discovery.
- Continue story/gameplay acceptance before broad art replacement. Do not call target expedition pacing measured.

## Latest verified evidence

- Current Godot 4.6.3 `visual` QA: **29/29 steps**, source-tree SHA-256 `01b5f899e0f433a7c806eb1b2bcfe38b236fe169dc9c5a25ec316584bf172711`. Visual review **77/77 captures, 320/320 checks**, 0 failures/errors. Cold-narrow output **11/11 captures, 53/53 checks**. Pause and staged death recovery were live-resized from 1280×720 to 800×600; original-size captures reviewed. 800×600 remains candidate physical-window evidence; its content viewport is 1024×768. Report and captures are linked from `docs/SCREEN_STATE_MATRIX.md`.
- Latest docs/Skills profile before the Chapter 4 wording clarification: `20261025T021833Z-cb858328`, **3/3 steps**, tool tests **25/25**, project-data tests **35/35**, documentation/Skill frontmatter **0 issues**. Report is in `C:\Users\wuwu6\AppData\Local\Temp\first-game-qa\20261025T021833Z-cb858328\qa-report.json`; the later wording and driver bookkeeping edits have not been rerun per the no-new-tests instruction.
- First-contract isolated GUI journey `FirstChapterCurrentCopy-20261025T002852Z-40e59065`: **109/109 checks** for both Scrap Highway trips, extraction, one-time Guild delivery, isolated checksummed save reload and duplicate-reward prevention. It is an older source snapshot, covers only the covered-long route, and is not human playtesting.
- Chapter 2 isolated GUI journey `20261025T025900Z-rerun`: **50/50 checks, zero failures**. It completed two outings, the physical purge-air choice, E-held actions, both extractions, return to Guild, optional-ledger readiness without revealing its result, exact hand-in rewards, isolated checksummed save reload, and duplicate-reward prevention. Report: `C:\Users\wuwu6\AppData\Local\Temp\chapter2-journey\20261025T025900Z-rerun\chapter2-journey-report.json`; source-tree hash `67b7cce96b9c60c31ff8ae1144d530e1b1ba5deb43438a2688dd1314f9b939b7`. It used an isolated Temp profile; the real player save was untouched. The report's derived `unverified_branches` field conflicts with the passing optional-ledger checks; that metadata bookkeeping is corrected in the current tree but has not been rerun. The alternate settle-sample choice remains untested.
- The Chapter 4 factory contract description now explicitly marks its black-box discovery as optional; the required order-reading action remains separate. This player-facing wording edit has not been validated in a fresh run.
- Detailed current QA and chronological evidence: `docs/QA_REPORT.md`; release limits: `docs/RELEASE_READINESS.md`; current screen coverage: `docs/SCREEN_STATE_MATRIX.md`.

## Current architecture and safety

Data-driven JSON defines route, action and story progression. `GameState` owns campaign transactions and persistence; `SceneRouter` owns scene transitions; the HUD exposes journal, contract, inventory, workshop, terminal, map and recovery panels. `SaveManager` checksums the encoded JSON payload. Preserve those owners and compatibility while fixing only demonstrated behavior.

`assets/world_v3/` is not used as current runtime data, but current art-direction documents and source snapshots reference it as provenance; retain it unless those records are deliberately migrated. QA copies now skip PNGs and `.png.import` files under `docs/` only; runtime `assets/` PNGs remain included.

## Next actions

1. Continue end-to-end journeys for Chapters 3–6, alternate outcomes, death/partial-return behavior and legacy saves; make further changes only against source evidence.
2. When tests are authorized again, rerun the Chapter 2 report-bookkeeping correction and Chapter 4 story-copy change, then cover the remaining gameplay and save/IO paths.
3. Keep full campaign acceptance, human pacing, Windows export, supported-size policy, comparable performance and broad art acceptance open. This is a development checkpoint, not release-ready.
