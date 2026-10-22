# Refactor Safety Checklist for Godot 4

1. **Autoload & Signal Stability**:
   - Do not rename autoload singletons (`GameState`, `DataRegistry`, `SaveManager`, `SceneRouter`, `AudioManager`) or their signals without updating every caller and test runner.
2. **Reflection & Test Runner Seams**:
   - Check `VisualReviewRunner.gd`, `GameplayRegressionRunner.gd`, `AutomatedPlaytestRunner.gd`, and `CollisionRegressionRunner.gd` for `.get("property")` and `.call("method")` usage before renaming variables or functions on `Player.gd`, `HUD.gd`, `Main.gd`, or `Enemy.gd`.
3. **Save File Compatibility**:
   - Always provide default fallback values when reading new keys in `SaveManager.gd` so existing user saves load cleanly.
