# Wasteland Recycler — agent entrypoint

## Project and policy

Wasteland Recycler is a PC-first, pixel-art 2.5D expedition roguelite built with Godot
4.6.3. R-17 prepares in the village and Guild, explores wasteland routes, then returns
to deliver contracts and keep earned progress.

This file is the canonical, concise project policy. Current work and evidence live in
the linked handoff and status documents; do not duplicate dated checkpoints here.

## Start each task

- Find the actual Git root and `project.godot`; verify branch, working-tree status, and
  relevant diffs before editing. Preserve unrelated dirty and untracked work.
- Read `AI_HANDOFF.md` and the design, workflow, or QA reference relevant to the task.
  Rediscover the engine version, shell, tools, and local Skills after a checkout or host
  change; do not assume machine-specific paths or capabilities.
- Trace the current owner and callers before changing behavior. Use repository-relative
  paths and Godot `res://` paths in durable source and documentation.

| Area | Main contents |
| --- | --- |
| `scenes/main`, `scenes/player`, `scenes/ui` | Startup, player, HUD, and screens |
| `scenes/levels` | Village, Guild, and wasteland routes |
| `scripts/autoload` | Shared state, data registry, saves, routing, and audio |
| `scripts/components`, `scripts/systems`, `scripts/ui` | Gameplay behavior and presentation |
| `data` and `assets` | Authored gameplay contracts and runtime art |
| `scripts/tests`, `scenes/tests` | Existing validators and regression runners |
| `docs` | Design, workflow, status, QA evidence, and handoff |

## Engineering and compatibility

- Apply Ponytail: make the smallest complete change. Reuse current scenes, signals,
  services, data contracts, and native Godot features. Avoid speculative refactors, duplicated
  behavior, scene rewrites, and routine regeneration or overwriting of authored art.
- Preserve the five autoload owners and the data-driven route/scene architecture. Keep
  PC-first keyboard and mouse behavior unless the user requests otherwise; preserve
  R-17's established identity and art direction.
- Preserve quest, outing, and action IDs; prerequisites; campaign states; reward
  quantities; and one-active-quest behavior. Rewards and expedition progress must follow
  current transaction rules. Do not change these contracts to improve copy or
  presentation.
- Preserve the existing save format and legacy behavior. `SaveManager` wraps JSON
  payloads in Base64 with a SHA-256 checksum, and `GameState` validates payloads before
  applying them. Any format change requires backward compatibility or an explicit
  migration plan.
- Player-facing text is Traditional Chinese. Canonical technical rules, specifications,
  and developer instructions are English; add Traditional Chinese explanations when
  useful without creating a competing policy source.
- Derive controls from the current `InputMap`. Read viewport settings from
  `project.godot`; keep the screen/state inventory in `docs/SCREEN_STATE_MATRIX.md`
  current when UI changes. Record reachability, input paths, viewport coverage,
  evidence, and open gaps. A screenshot alone does not prove interaction or adaptation.

## Skills and AI tools

- Check the current host's available-Skill catalog, then inspect and follow the
  applicable `.agents/skills/<name>/SKILL.md`. Repository Skills are procedures, not
  proof that another host auto-discovers or supports them.
- For structural exploration, use the `codebase-memory` Skill when available: search the
  graph, check exact-path coverage, and inspect current source directly if coverage is
  stale or incomplete. If the tool is unavailable, continue with local source
  inspection.
- Use in-session subagents for independent, delegable work. Assign distinct file
  ownership and use `gpt-6-luna` with `max` reasoning when task-level selection is
  available. Do not create extra user chats or change global model/tool settings.
- Do not send project content to external AI services, including Gemini or Antigravity,
  unless the user explicitly authorizes that transfer.

## Validation and evidence

- Choose checks by risk. For documentation-only work, review the diff and linked
  references, and run `python scripts/tools/run_qa.py --profile docs` or the specific
  docs/Skill-frontmatter validator. Full Godot QA is not required for prose-only
  changes.
- For data, scenes, scripts, or assets, run the relevant existing validators and QA
  profiles after edits settle. Inspect logs and reports even when the process exits
  successfully.
- The QA launcher uses an isolated project mirror and user-data directory. Never run
  writing checks against the player's real `user://save_game.json`; do not overwrite
  repository reports or authored assets during validation.
- Verify the installed Godot version before engine checks. For visual acceptance, open
  and inspect full-resolution captures and exercise the real player path. Headless
  output or a staged UI preview cannot prove visual correctness or reachability.
- Report exact commands, runtime, result, and limitations. Distinguish source review,
  automated interaction, visual review, and release evidence. Never claim a check passed
  if it did not run.

## Safety and Definition of Done

- Preserve dirty and untracked work; do not reset, clean, or discard it. Do not expose
  secrets, rewrite Git history, force-push, alter unrelated projects, or change global settings to work around missing
  tools.
- Commit only reviewed, authorized paths. Do not push without explicit user
  authorization. Avoid irreversible operations without authorization. For requested
  cleanup, confirm references and delete only one confirmed
  absolute file per operation; never bulk-delete files or directories.
- A task is done when its acceptance criteria are implemented, relevant checks have run
  in isolation, changed outputs and diffs have been reviewed, and handoff/status records
  match actual behavior and remaining limitations. Do not label the full game complete
  or release-ready while required work remains unverified.

## Canonical references

- [Development lifecycle](WORKFLOW.md)
- [Current handoff](AI_HANDOFF.md)
- [Production status and priorities](docs/PRODUCTION_STATUS.md)
- [QA evidence](docs/QA_REPORT.md)
- [Game design and campaign rules](docs/GAME_DESIGN.md)
- [Story and scenes](docs/STORY_AND_SCENES.md)
- [Screen/state acceptance inventory](docs/SCREEN_STATE_MATRIX.md)
- [Release readiness](docs/RELEASE_READINESS.md)
- [Art direction](docs/art-direction/README.md)

### 繁體中文摘要

本文件是精簡的英文技術規範入口；目前進度、流程與驗證證據請看連結文件。
修改前先確認專案根目錄、Git 狀態與相關來源，保留其他未提交工作。
維持現有玩法、資料契約、存檔相容性與繁體中文玩家文案；測試使用隔離副本。
只依實際執行的檢查與可查看的證據回報結果，不把未驗收內容描述成完成。
