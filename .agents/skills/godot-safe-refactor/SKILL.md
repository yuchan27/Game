---
name: godot-safe-refactor
description: Refactor a bounded Godot subsystem while preserving scene paths, signals, collision behavior, saved data and characterized player behavior.
---

# Godot safe refactor

Trigger: a specific structural repair or duplicated behavior. Inputs: bounded
symbols/files, motivation, consumers and baseline. Output: incremental compatible
diff and before/after evidence.

1. State the maintenance problem; skip speculative abstraction. Inspect status,
   preserve other work, and trace scene/signal/JSON/save consumers. Use graph tools
   only with verified coverage; otherwise read/search source and disclose the limit.
2. Characterize public behavior with existing runners or a focused regression.
   Record paths/UIDs, classes, input actions, node paths, signals, collision masks
   and serialized fields that consumers rely on.
3. Choose the smallest shared seam. Separate structural and behavior changes.
   Agree shared APIs and exclusive file ownership before parallel work.
4. Change one reversible slice; update consumers/references. Retain legacy defaults
   or provide an explicit save migration before applying a new format.
5. Run characterization and the project's QA. Here: `python scripts/tools/run_qa.py
   --godot <engine> --profile core`; add rendered checks if presentation can change.

Validation: characterized behavior and compatibility execute after the refactor;
every replaced reference has a consumer check. Failure: stop broadening, localize
and repair the regression without discarding others' work or weakening tests.
