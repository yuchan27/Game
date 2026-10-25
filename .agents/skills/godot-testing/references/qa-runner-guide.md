# QA Runner Suite Reference

| Runner / Script | Purpose | Mode |
| :--- | :--- | :--- |
| `scripts/tools/validate_project_data.py` | Validates JSON schemas, item/quest/NPC IDs, and cross-references | Python CLI |
| `scripts/tools/verify_visual_assets.py` | Validates the current manifests, source hashes, dimensions, frame metadata, overlays, audio, and references | Python CLI |
| `scenes/tests/VerticalSliceVerifier.tscn` | Verifies scene loading, autoload initialization, and core vertical slice | Headless Godot |
| `scenes/tests/AutomatedPlaytestRunner.tscn` | Simulates full village → wasteland → combat → guild → save/load loop | Headless Godot |
| `scenes/tests/GameplayRegressionRunner.tscn` | Tests melee/ranged combat, EP sprint/regen, equipment, quests, and UI blockers | Headless Godot |
| `scenes/tests/CollisionRegressionRunner.tscn` | Verifies obstacle, station, and world boundary collisions | Headless Godot |
| `scenes/tests/VisualReviewRunner.tscn` | Uses the current `REQUIRED_CAPTURES` list and runtime UI/HUD checks; read actual counts from the report | Rendered GUI Godot |
| `scenes/tests/PerformanceRunner.tscn` | Collects rendered frame-time and scene/entity stress metrics; inspect the report for sample definitions | Rendered GUI Godot |

Run `python scripts/tools/run_qa.py --help` on the current checkout to discover
profile names, arguments, dependencies, and output rules. `visual` includes the
core checks; `all` also requests docs and performance. The launcher copies the
current tracked, modified, and untracked project files into an isolated mirror
and creates a per-run Godot user directory. Reports belong outside the checkout.

Do not infer cold narrow-launch support from live resize captures. Record logical
viewport size, physical window size, rendered output size, and whether the case
started cold or resized; see `docs/SCREEN_STATE_MATRIX.md` for the player-facing
state contract.
