---
name: godot-development
description: Implement a Godot gameplay, UI, scene or data feature through existing architecture, with a playable acceptance slice and focused validation.
---

# Godot development

Trigger: requested feature or confirmed gameplay/UI defect. Inputs: project root,
intended player behavior and constraints. Output: integrated behavior, reviewed
diff and executed acceptance evidence.

1. Find `project.godot`, read applicable AGENTS/handoff, inspect Git status and
   verify the actual engine with `--version`. Discover runners and dependencies.
2. Trace input → scene/component → state/data → feedback. Check callers, signals,
   collision layers, resource ids and persistent data at that seam.
3. Define one playable acceptance slice and a focused reproduction. Preserve
   scene/autoload ownership; use JSON for route variants where possible.
4. Implement the smallest complete slice. Separate restored coordinates from
   scene entrances; preserve equipment ownership and single-grant rewards.
5. Execute affected regressions and the project's safe QA entrypoint. Here:
   `python scripts/tools/run_qa.py --godot <engine> --profile core`. Add `visual`
   profile and inspect PNGs for UI/art changes. Read current `--help` first.
6. Review integrated diff and report exact evidence/limitations; update handoff.

Validation: observable input-to-feedback path executes and saves/scenes remain
usable. Failure: classify environment, stale-test and product faults; fix the
cause. Do not regenerate art, disable valid assertions or call a partial slice done.
