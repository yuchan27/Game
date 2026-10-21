# Wasteland Recycler — agent entrypoint

Godot 4.6.3, PC-first single-player pixel-art pseudo-3D roguelike. Preserve the
playable loop: village → guild contract → equipment → four wasteland routes →
combat/events/loot → return → rewards/upgrades/save.

## Navigate

This directory is both the Git and Godot root. Verify root/status/branch before
editing; preserve unrelated changes. Read `AI_HANDOFF.md`, `WORKFLOW.md`,
`project.godot` and the files relevant to the task; discover actual paths.

- `scenes/main/`, `scenes/player/`, `scenes/ui/`: application, player and HUD.
- `scenes/levels/{village,guild,wasteland}/`: shared gameplay loop.
- `scripts/autoload/`: state, JSON registry, persistence, routing and audio.
- `scripts/components/`, `scripts/systems/`, `scripts/ui/`: reusable behavior.
- `data/`: gameplay/art contracts; `assets/`: authored art/audio.
- `scripts/tests/`, `scenes/tests/`: runners; `scripts/tools/run_qa.py`: safe QA.

## Engineering and architectural invariants

- Use Ponytail: reuse existing code, native Godot features and standard libraries;
  deliver the smallest complete fix. No speculative refactor or scene rewrite.
- Preserve the five autoloads, signals and data-driven route/scene architecture.
- Keep runtime art under `assets/`, preserve R-17 and current authored animation.
  Art generation is an explicit production operation, not routine QA.
- Retain save Base64/SHA-256 wrapping and legacy compatibility. Validate before
  applying state; distinguish a saved position from a scene entrance.
- One active quest; objective progress belongs to that contract and route;
  rewards are granted once. Resource counters mirror inventory.
- Keep PC keyboard/mouse controls. All player-visible text uses Traditional Chinese.
- Canonical technical instructions/specifications and commit messages use English.
  Traditional Chinese explanations translate them; never create two rule sources.

## Skills and delegation

Read `.agents/skills/<name>/SKILL.md` when its trigger applies. Invoke explicitly
with `$godot-testing`, etc. Skills describe procedures; this file owns policy.

| Skill | Trigger |
| --- | --- |
| `godot-development` | Implement gameplay, UI, scene or data behavior. |
| `godot-testing` | Diagnose failures and produce fresh validation evidence. |
| `godot-visual-review` | Review art/animation, rendered UI, maps or screenshots. |
| `godot-safe-refactor` | Change structure while preserving characterized behavior. |

For structural exploration use the installed `codebase-memory` skill; if there is
no current index, inspect source and disclose the coverage limit. Delegate useful
independent tasks with exclusive file ownership; integrate and test the combined
state. All subagents use `gpt-6-luna` with `max` reasoning. Do not create additional
user chats or change global Codex configuration.

## Validation, safety and Definition of Done

Follow risk-based validation in `WORKFLOW.md`. Discover the installed executable
and verify `--version`. Isolate QA saves/output; never run writing tests against
player progress. Headless rendering cannot prove visual correctness. Record
commands, exit statuses, runtime errors, failures and skipped checks honestly.

Never discard dirty work, expose/commit secrets, rewrite history, force push,
regenerate/overwrite authored assets without authorization, modify other projects,
or recursively delete directories/bulk-delete files. Delete at most one confirmed
absolute file path at a time. Do not push without explicit user instruction and
never rewrite remotes as routine setup. Commit only authorized, verified scoped
changes; required validation failures block committing the affected change.

Done means acceptance criteria satisfied, integrated behavior exercised, relevant
checks executed, no known critical regression, and concise evidence/limitations
in `AI_HANDOFF.md`. A plan or generated code alone is incomplete.

References: `WORKFLOW.md` (lifecycle), `docs/PROJECT_AUDIT.md` (starting evidence),
`docs/GAMEPLAY_ROADMAP.md` (priorities), `docs/RELEASE_READINESS.md` (fresh results),
`docs/DEVELOPER_GUIDE.zh-TW.md` (human guide), `docs/PLAYTEST_CHECKLIST.md` (manual QA).
