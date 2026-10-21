# Development lifecycle

Inspect → Understand → Plan → Implement → Validate → Review → Commit → Handoff.
`AGENTS.md` is canonical project policy; this document describes execution.

## Inspect and understand

Verify Git root/status/branch/recent commits and installed Godot version. Read the
handoff, relevant scenes/scripts/data and current diff. Trace observable behavior
to the shared owner and callers. Distinguish a product defect, stale test,
environment problem and unverified hypothesis.

## Plan and implement

State intended player behavior, acceptance criteria, affected files, invariants
and required evidence. Use small reversible slices; demonstrate a defect before
fixing it when practical. Reuse current scenes, runners, signals and JSON. Avoid
speculative abstraction, asset regeneration and unrelated cleanup. Give parallel
writers separate file ownership; one lead coordinates APIs and integrated checks.

## Validate proportionately

Use a matching Skill for details. From the project root, prepare dependencies if
needed. Pass a discovered executable with `--godot` or `GODOT_BIN`; verify 4.6.3.

```powershell
python -m venv .godot/qa-venv
& .godot/qa-venv/Scripts/python.exe -m pip install -r requirements-qa.txt
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile core
```

The launcher isolates project/user data and keeps per-check logs outside the source
checkout. It reuses existing runners without rebuilding art. Do not run a writing
test against real `user://save_game.json`, authored assets or historical reports.

| Change | Required evidence |
| --- | --- |
| Documentation only | Diff, references and terminology; Skill YAML if changed. No full game run. |
| Script/gameplay/save | Import/parse, affected regression, core runners and data references. |
| JSON | Parse, types/ranges/ids and cross-file references; affected gameplay. |
| UI/map/art references | Relevant core, asset checks, rendered captures and actual PNG inspection. |
| Performance-sensitive code | Equivalent representative baseline/after workload and environment. |
| Release candidate | Core, rendered visual, performance, export/build/runtime capability and manual checklist disposition. |

```powershell
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile visual
& .godot/qa-venv/Scripts/python.exe scripts/tools/run_qa.py --godot $env:GODOT_BIN --profile performance
```

Inspect logs even for exit 0. Headless visual output is not a pass. Synthetic
physics cadence is not rendered FPS. Compare equivalent timing definitions and
avoid speed claims from one noisy sample. Export presets do not prove templates
exist or that an exported package runs.

## Review and commit

Review combined diff; rerun checks affected by later edits. Confirm acceptance,
save compatibility, Traditional Chinese text, preserved art and no staged cache or
secrets. Required validation failures block committing that implementation. Fix
them or leave the affected change uncommitted with evidence. An independently
verified documentation stage may be committed without claiming the game baseline
is fixed. When authorized, stage exact reviewed paths, inspect staged diff and
whitespace, and use an English message. Do not alter remotes, rewrite history or
push without explicit authorization.

## Handoff

Replace the bounded current snapshot in `AI_HANDOFF.md`: status, latest verified
changes, known issues, decisions, evidence and next action. Detailed results go in
`docs/RELEASE_READINESS.md`; future priorities in `docs/GAMEPLAY_ROADMAP.md`. Do not
append an endless historical log or label unexecuted checks passed. Summarize
changed files, behavior, failures and limitations at each stage boundary.
