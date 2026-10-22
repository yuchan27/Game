# QA Runner Suite Reference

| Runner / Script | Purpose | Mode |
| :--- | :--- | :--- |
| `scripts/tools/validate_project_data.py` | Validates JSON schemas, item/quest/NPC IDs, and cross-references | Python CLI |
| `scripts/tools/verify_visual_assets.py` | Validates SHA-256, dimensions, 576 player frames, weapon overlays, audio, and UTF-8 | Python CLI |
| `scenes/tests/VerticalSliceVerifier.tscn` | Verifies scene loading, autoload initialization, and core vertical slice | Headless Godot |
| `scenes/tests/AutomatedPlaytestRunner.tscn` | Simulates full village → wasteland → combat → guild → save/load loop | Headless Godot |
| `scenes/tests/GameplayRegressionRunner.tscn` | Tests melee/ranged combat, EP sprint/regen, equipment, quests, and UI blockers | Headless Godot |
| `scenes/tests/CollisionRegressionRunner.tscn` | Verifies obstacle, station, and world boundary collisions | Headless Godot |
| `scenes/tests/VisualReviewRunner.tscn` | Captures 29 screenshots and runs 32 live UI/HUD bounds & input checks | Rendered GUI Godot |
| `scenes/tests/PerformanceRunner.tscn` | Benchmarks frame time across scenes and projectile/enemy stress | Headless/GUI Godot |
