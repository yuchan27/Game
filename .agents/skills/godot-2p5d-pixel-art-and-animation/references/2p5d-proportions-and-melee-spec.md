# 2.5D Proportions, Turnaround & Melee Slash Reference

## 1. Atlas Geometry (`recycler_player_multiaction_8dir_preview.png`)
- **Total Atlas Size**: `8064 × 1024` RGBA PNG
- **Frame Cell**: `112 × 128` px
- **Actions (9 columns of 8 frames = 72 columns)**:
  1. `idle` (cols `0..7`)
  2. `walk` (cols `8..15`)
  3. `shoot` (cols `16..23`)
  4. `draw_sword` (cols `24..31`)
  5. `slash` (cols `32..39`)
  6. `swap_tool` (cols `40..47`)
  7. `interact` (cols `48..55`)
  8. `hit` (cols `56..63`)
  9. `dead` (cols `64..71`)
- **Directions (8 rows)**:
  - `0`: `right` (East)
  - `1`: `down_right` (South-East)
  - `2`: `down` (South)
  - `3`: `down_left` (South-West)
  - `4`: `left` (West)
  - `5`: `up_left` (North-West)
  - `6`: `up` (North)
  - `7`: `up_right` (North-East)

## 2. Melee Weapon Overlay & Slash Math
- **Overlay Canvas**: `96 × 64` px RGBA (`assets/sprites/player/weapons/*_overlay.png`)
- **Orientation**: Pointing horizontally RIGHT (`0 rad`), hilt at `(20, 32)`, blade tip at `(86, 32)`.
- **Pivot Offset (`Sprite2D`)**: `centered = true`, `offset = Vector2(26, 0)` (places pixel `(22, 32)` at rotation origin `(0, 0)`).
- **Combo Swing**:
  - Hit 0 (Forehand): `-108°` to `+78°` (`combo_sign = +1.0`)
  - Hit 1 (Backhand): `+108°` to `-78°` (`combo_sign = -1.0`)
  - Easing: `eased = 1.0 - pow(1.0 - progress, 3.0)`
