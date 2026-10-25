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
   - Run `python scripts/tools/run_qa.py --help` to inspect the current profiles, engine discovery, timeout, and output behavior. Do not assume a previous host's profiles or dependencies.
2. **Execute Isolated QA Profiles**:
   - **Core Suite**:
     `python scripts/tools/run_qa.py --godot <discovered-engine> --profile core`
     Runs:
     - `validate_project_data.py` & `verify_visual_assets.py`
     - `ValidationRunner.tscn` (invokes `VerticalSliceVerifier.gd`)
     - `AutomatedPlaytestRunner.tscn`
     - `GameplayRegressionRunner.tscn`
     - `CollisionRegressionRunner.tscn`
     - `WorldExpansionRunner.tscn`, `DirectionalPresentationRegression.tscn`,
       `WorldAtlasRegression.tscn`, `SceneEntranceRegression.tscn`
   - **Visual Suite**:
     `python scripts/tools/run_qa.py --godot <engine> --profile visual`
   - **Performance Suite**:
     `python scripts/tools/run_qa.py --godot <engine> --profile performance`
3. **Diagnose & Fix Root Causes**:
   - Inspect both stdout/stderr and the generated JSON reports.
   - Never weaken valid assertions or skip failing checks to turn a suite green.

## Acceptance and failure handling

Require process exits, the runner's completion/report contract and empty runtime
error lists together. Record the source fingerprint, run ID, engine, command and
report paths. Distinguish baseline failures, regressions and missing capabilities.
After an intentional contract change, replace obsolete assertions with checks of
the new observable behavior; preserve coverage. A timeout or absent report fails
the run. Inspect its isolated Godot log, fix the cause and rerun the affected check.
Never use player saves, regenerate art or mark an unexecuted export as passed.

This repository's launcher is the project adapter; in another Godot project,
discover its runner scenes and output switches before reusing this procedure.
