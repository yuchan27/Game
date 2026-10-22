# Godot Architecture & Multi-Interface UI Patterns

## 1. Autoload Responsibilities
- `DataRegistry`: Read-only JSON loader (`equipment.json`, `recipes.json`, `npcs.json`, `quests.json`, `wasteland_routes.json`, `visual_assets.json`).
- `GameState`: Runtime mutable state (HP/EP, inventory, equipped slots, quick slots, weapon levels, active quest, seed) + signals (`stats_changed`, `inventory_changed`, `equipment_changed`, `notification_requested`, `dialogue_requested`).
- `SaveManager`: JSON persistence with schema validation and graceful corruption recovery.
- `SceneRouter`: Scene transitions preserving spawn point (`from_village`, `from_guild`, `from_wasteland`, `saved`).
- `AudioManager`: BGM, SFX, and NPC/Intro voiceover playback.

## 2. Adding a New HUD Modal Interface
1. Create `PanelContainer` in `HUD.gd`, set `z_index = 60`, `mouse_filter = Control.MOUSE_FILTER_STOP`, and add to `"gameplay_input_blocker"`.
2. Add a `_set_<name>_visible(is_visible: bool)` helper that closes competing modals, hides dialogue, refreshes content, and calls `_refresh_overlay_visibility()`.
3. Add a tab button in `_build_modal_switcher()` and `_add_nav_bar()`, plus hotkey handling in `_unhandled_input()`.
4. Size and center the panel inside `_layout()` so it fits both `1280×720` and `1024×768`.
