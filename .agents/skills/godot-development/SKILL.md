---
name: godot-development
description: Implement a Godot gameplay, UI, scene, combat, or data feature with a playable acceptance slice, isolated import, and automated QA verification.
---

# Godot Development Skill

Trigger: requested feature, multi-interface UI expansion, or confirmed gameplay/combat defect.
Inputs: project root, intended player behavior, current project-derived viewport profiles, and constraints.
Output: integrated behavior, reviewed diff, fresh isolated import, and executed QA evidence.

## Workflow
1. **Discover & Inspect**:
   - Locate `project.godot`, inspect `scripts/autoload/` (`GameState.gd`, `DataRegistry.gd`, `SceneRouter.gd`, `SaveManager.gd`, `AudioManager.gd`), and check `data/` JSON schemas.
   - Verify the Godot binary with `--version` and Python QA venv dependencies.
2. **Trace the Full Seam**:
   - Trace `Input` → `Scene / Entity (Player, NPC, Station, Enemy)` → `Autoload State / DataRegistry` → `HUD / Audio / VFX Feedback`.
   - Preserve existing group contracts (`player`, `enemy`, `boss`, `interactable`, `dialogue_npc`, `equipment_panel`, `tutorial_panel`, `minimap_panel`, `gameplay_input_blocker`, `hotbar_slot`).
3. **Multi-Interface UI & Responsive Layout Rules**:
   - Every modal panel (`InventoryPanel`, `WorkshopPanel`, `ContractPanel`, `CodexPanel`, `TutorialPanel`, `DialoguePanel`, `PausePanel`) must:
     - Register in group `"gameplay_input_blocker"` and update `set_meta("gameplay_input_blocked", visible)` in `_refresh_overlay_visibility()`.
     - Suppress global floating notices (`NoticeLabel`) while open so text never overlaps.
     - Fit every viewport profile declared in `docs/SCREEN_STATE_MATRIX.md`; derive profiles from the current `project.godot` and keep cold narrow launch separate from live resize.
     - Include a unified top tab switcher (`_build_modal_switcher`) and `Esc` close handling.
4. **Import & Validate**:
   - Use the QA launcher's fresh isolated mirror/import when assets or scenes change. Preserve the checkout's `.godot/` directory and existing player saves; do not bulk-delete cache files.
   - Execute `python scripts/tools/run_qa.py --godot <engine> --profile core` (and `--profile visual` when UI, sprites, or tiles change).

## Acceptance and failure handling

Write player-observable acceptance criteria before editing. Completion requires
the integrated interaction, relevant tests, compatible saves, rendered review for
visible changes and a bounded handoff. If a dependency or baseline fails, preserve
the current diff, diagnose the first failure and report what was actually run.
Use existing project contracts above as this repository's adapter; discover the
corresponding owners and groups before applying the procedure elsewhere.
