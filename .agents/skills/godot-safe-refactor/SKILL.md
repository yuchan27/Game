---
name: godot-safe-refactor
description: Refactor a bounded Godot subsystem while preserving scene paths, node groups, signals, collision footprints, saved data compatibility, and characterized player behavior.
---

# Godot Safe Refactor Skill

Trigger: structural cleanup, deduplication, or subsystem modularization in a Godot 4 project.
Inputs: target scripts/scenes, consumer list, and baseline regression status.
Output: reversible, behavior-preserving diff verified by characterization tests.

## Workflow
1. **Map All Consumers First**:
   - Grep for `preload(`, `load(`, group names (`get_nodes_in_group`), signal names, `.tscn` script attachments, and `get(` / `call(` reflection sites (especially in `scripts/tests/*.gd`).
2. **Preserve Contracts**:
   - Keep node names, group memberships (`player`, `enemy`, `boss`, `interactable`, `dialogue_npc`, `equipment_panel`, `tutorial_panel`, `minimap_panel`, `gameplay_input_blocker`), signal signatures, and `SaveManager` JSON keys backward-compatible.
3. **Incremental Verification**:
   - Apply one bounded step at a time, run affected characterization checks, then run `python scripts/tools/run_qa.py --godot <engine> --profile core` after integration.

## Acceptance and failure handling

Require unchanged characterized behavior, valid scene/resource paths, compatible
serialized data and a reviewed consumer diff. Use before/after measurements for
performance claims. If a contract breaks, repair the current step before widening
scope; preserve unrelated changes and never reset the checkout to hide failures.
When characterization is insufficient, add an observable test before extracting
the behavior. The group names above are project configuration, not portable rules.
