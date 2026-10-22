---
name: godot-testing
description: Run and diagnose Godot parsing, data schema, gameplay regression, collision, persistence, and performance checks while isolating player saves and preserving reproducible QA reports.
---

# Godot Testing & QA Automation Skill

Trigger: feature verification, regression investigation, or release readiness check.
Inputs: project root, Godot console binary path, and Python QA environment.
Output: per-suite pass/fail status, JSON reports, and zero unhandled script errors.

## Workflow
1. **Verify Environment & Read Runner Help**:
   - Run `python scripts/tools/run_qa.py --help` to inspect available profiles (`core`, `visual`, `performance`, `all`).
2. **Execute Isolated QA Profiles**:
   - **Core Suite**:
     `python scripts/tools/run_qa.py --godot "C:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe" --profile core`
     Runs:
     - `validate_project_data.py` & `verify_visual_assets.py`
     - `VerticalSliceVerifier.tscn`
     - `AutomatedPlaytestRunner.tscn`
     - `GameplayRegressionRunner.tscn`
     - `CollisionRegressionRunner.tscn`
   - **Visual Suite**:
     `python scripts/tools/run_qa.py --godot <engine> --profile visual`
   - **Performance Suite**:
     `python scripts/tools/run_qa.py --godot <engine> --profile performance`
3. **Diagnose & Fix Root Causes**:
   - Inspect both stdout/stderr and the generated JSON reports.
   - Never weaken valid assertions or skip failing checks to turn a suite green.
