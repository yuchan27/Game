---
name: godot-development
description: Implement a Godot gameplay, multi-interface UI, scene, combat, or data feature through clean architecture, with a playable acceptance slice, cache refresh, and automated QA verification.
---

# Godot Development Skill

Trigger: requested feature, multi-interface UI expansion, or confirmed gameplay/combat defect.
Inputs: project root, intended player behavior, resolution targets (`1280×720` and `1024×768`), and constraints.
Output: integrated behavior, reviewed diff, cache-cleared import, and executed QA evidence.

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
     - Fit cleanly inside both `1280×720` and `1024×768` viewports in `_layout()`.
     - Include a unified top tab switcher (`_build_modal_switcher`) and `Esc` close handling.
4. **Clear Import Cache & Validate**:
   - When assets or scenes change, clear `.godot/imported/` and run `--headless --import`.
   - Execute `python scripts/tools/run_qa.py --godot <engine> --profile core` (and `--profile visual` when UI, sprites, or tiles change).
