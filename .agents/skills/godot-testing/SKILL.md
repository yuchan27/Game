---
name: godot-testing
description: Run and diagnose Godot parsing, data, gameplay, persistence and performance checks while isolating player saves and preserving fresh validation evidence.
---

# Godot testing

Trigger: regression investigation, validation or release readiness. Inputs:
checkout/revision, changed behavior, engine path and dependencies. Output:
per-check command, exit code, log/report location, result and coverage limits.

1. Read runner sources before execution: identify every save/report write,
   dependency and required backend. Never use asset generators as validation.
2. Verify engine/Python. Here run `python scripts/tools/run_qa.py --godot <engine>
   --profile core`; read its `--help`. It isolates project/user data and reuses
   ValidationRunner, AutomatedPlaytestRunner and GameplayRegressionRunner.
3. Start with a focused failing regression; distinguish baseline failures from
   regressions. Check JSON types, ids/references, scene/script loading, state
   transitions and production load APIs. Test corruption and legacy defaults.
4. Add `visual` or `performance` profiles based on risk. Images require a real
   renderer; timing comparisons require equivalent workload/settings/environment.
5. Inspect logs even for exit 0. Script errors, missing output, timeouts and skipped
   screenshots cannot be passes. Preserve individual results and rerun after repair.

Validation: fresh reproducible evidence covers acceptance criteria. Failure:
report the failed check/cause; never weaken assertions just to turn green. For stale
tests show current data/source evidence and retain equivalent checks. Manual play,
exports and runtime packages are distinct from runner success.
