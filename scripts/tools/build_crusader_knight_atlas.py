"""
Crusader Knight 2D Pixel-Art Character Atlas Builder.

Generates the complete 8-direction x 9-action x 8-frame player animation atlas
for the authentic 2D pixel-art Medieval Crusader Knight Automaton matching Reference Picture 2.

Features:
- Authentic 2D hand-crafted pixel art (no 3D capsules or procedural sweeps).
- Flat-top bucket Crusader greathelm with golden cross faceplate and dark eye slit.
- Slate-blue steel plate cuirass, thick gold pauldron trims, and flowing crimson velvet cape.
- Broad double-edged steel greatsword, golden-trimmed knight heater shield, overhead heavy warhammer,
  and mechanical arbalest crossbow.
- Ample canvas padding in all 112x128 cells to guarantee zero truncation or edge clipping.
"""

from __future__ import annotations

import hashlib
import math
from collections import deque
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
PLAYER_DIR = ROOT / "assets" / "sprites" / "player"
FRAMES_DIR = PLAYER_DIR / "frames"
ACTIONS_DIR = PLAYER_DIR / "actions"
DOCS_DIR = ROOT / "docs"

FRAME_W, FRAME_H = 112, 128
FRAMES_PER_ACTION = 8
DIRECTIONS = 8
ACTIONS = ["idle", "walk", "shoot", "draw_sword", "slash", "swap_tool", "interact", "hit", "dead"]

# Direction angles and names:
# 0: right (East)
# 1: down_right (South-East)
# 2: down (South)
# 3: down_left (South-West)
# 4: left (West)
# 5: up_left (North-West)
# 6: up (North)
# 7: up_right (North-East)

DIR_NAMES = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
DIR_TO_ROW0_INDEX = {0: 2, 1: 1, 2: 0, 3: 7, 4: 6, 5: 5, 6: 4, 7: 3}


def extract_and_clean_source_sheet(source_path: Path) -> Image.Image:
    """Loads source sheet, removes exterior dark background via BFS flood-fill, and scrubs watermark artifacts."""
    img = Image.open(source_path).convert("RGB")
    arr = np.array(img, dtype=np.int32)
    h, w = arr.shape[:2]

    # Target background color ~ (23, 31, 40)
    bg_target = np.array([23, 31, 40], dtype=np.int32)
    diff = np.abs(arr - bg_target).max(axis=-1)

    # BFS from all four outer image borders
    visited = np.zeros((h, w), dtype=bool)
    q = deque([(0, 0), (0, w - 1), (h - 1, 0), (h - 1, w - 1)])
    for y, x in q:
        visited[y, x] = True

    while q:
        cy, cx = q.popleft()
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if diff[ny, nx] <= 24:
                    visited[ny, nx] = True
                    q.append((ny, nx))

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = img
    rgba[:, :, 3] = 255
    rgba[visited, 3] = 0

    # Clean stray watermark text and isolated edge artifacts
    for y in range(h):
        for x in range(w):
            if rgba[y, x, 3] > 0:
                r, g, b = int(rgba[y, x, 0]), int(rgba[y, x, 1]), int(rgba[y, x, 2])
                # Bright white watermark lettering
                if r > 210 and g > 210 and b > 210:
                    rgba[y, x, 3] = 0
                # Light grey box / ground watermark near feet of row 0 / row 1 / row 3
                elif 85 < r < 145 and 95 < g < 145 and 110 < b < 155:
                    if (178 <= y <= 200) or (365 <= y <= 380) or (730 <= y <= 750):
                        rgba[y, x, 3] = 0

    return Image.fromarray(rgba, "RGBA")


class ExtractedKnightAssets:
    def __init__(self, cleaned_sheet: Image.Image) -> None:
        self.sheet = cleaned_sheet
        arr = np.array(cleaned_sheet)

        # 1. Row 0: 8 turnaround poses
        row0_xs = [
            (52, 166),   # 0: S (down)
            (214, 333),  # 1: SE (down_right)
            (379, 499),  # 2: E (right)
            (545, 664),  # 3: NE (up_right)
            (710, 828),  # 4: N (up)
            (877, 996),  # 5: NW (up_left)
            (1043, 1160),# 6: W (left)
            (1206, 1324) # 7: SW (down_left)
        ]
        self.row0_sprites = [self._crop_sprite(arr, 31, 197, sx, ex) for sx, ex in row0_xs]

        # 2. Row 1: 4 walk cycle frames
        row1_xs = [(134, 269), (447, 602), (771, 932), (1098, 1233)]
        self.walk_sprites = [self._crop_sprite(arr, 213, 376, sx, ex) for sx, ex in row1_xs]

        # 3. Row 2: 4 slash attack combo frames
        row2_xs = [(133, 321), (366, 707), (763, 1027), (1062, 1261)]
        self.slash_sprites = [self._crop_sprite(arr, 398, 558, sx, ex) for sx, ex in row2_xs]

        # 4. Row 3: Action poses
        # Action 0: Warhammer slam
        self.hammer_sprite = self._crop_sprite(arr, 576, 750, 121, 270)
        # Action 1: Crossbow aim & shoot
        self.crossbow_sprite = self._crop_sprite(arr, 576, 750, 459, 643)
        # Action 2: Hurt recoil with sparks
        self.hurt_sprite = self._crop_sprite(arr, 576, 750, 770, 946)
        # Action 3: Collapsed defeat pose
        self.dead_sprite = self._crop_sprite(arr, 576, 750, 1090, 1290)

    def _crop_sprite(self, arr: np.ndarray, sy: int, ey: int, sx: int, ex: int) -> Image.Image:
        sub = arr[sy:ey, sx:ex]
        alpha = sub[:, :, 3]
        y_idx = np.where(alpha > 0)[0]
        x_idx = np.where(alpha > 0)[1]
        if len(y_idx) == 0:
            return Image.new("RGBA", (10, 10), (0, 0, 0, 0))
        ymin, ymax = int(np.min(y_idx)), int(np.max(y_idx))
        xmin, xmax = int(np.min(x_idx)), int(np.max(x_idx))
        cropped = Image.fromarray(sub[ymin : ymax + 1, xmin : xmax + 1], "RGBA")
        return cropped


def draw_sword_north(canvas: Image.Image, frame: int) -> Image.Image:
    draw = ImageDraw.Draw(canvas, "RGBA")
    if frame in (0, 1):
        draw.line([(62, 70), (74, 28)], fill=(75, 90, 110, 255), width=5)
        draw.line([(63, 69), (73, 29)], fill=(210, 225, 240, 255), width=2)
        draw.line([(56, 66), (68, 72)], fill=(240, 190, 50, 255), width=4)
        draw.point((61, 74), fill=(240, 190, 50, 255))
    elif frame in (2, 3):
        draw.line([(56, 62), (56, 14)], fill=(75, 90, 110, 255), width=6)
        draw.line([(56, 60), (56, 16)], fill=(225, 240, 255, 255), width=3)
        draw.line([(56, 58), (56, 18)], fill=(255, 255, 255, 255), width=1)
        draw.line([(48, 64), (64, 64)], fill=(240, 190, 50, 255), width=4)
        draw.arc([(32, 8), (80, 56)], 180, 360, fill=(255, 230, 100, 230), width=4)
        draw.arc([(36, 12), (76, 52)], 190, 350, fill=(255, 255, 220, 255), width=2)
    elif frame == 4:
        draw.line([(50, 68), (38, 26)], fill=(75, 90, 110, 255), width=5)
        draw.line([(50, 67), (39, 27)], fill=(210, 225, 240, 255), width=2)
        draw.line([(44, 70), (56, 66)], fill=(240, 190, 50, 255), width=4)
        draw.arc([(30, 20), (66, 58)], 140, 270, fill=(240, 180, 50, 160), width=2)
    else:
        draw.line([(58, 68), (68, 36)], fill=(75, 90, 110, 255), width=5)
        draw.line([(58, 67), (67, 37)], fill=(200, 220, 235, 255), width=2)
        draw.line([(52, 66), (64, 70)], fill=(240, 190, 50, 255), width=4)
    return canvas


def draw_sword_south(canvas: Image.Image, frame: int) -> Image.Image:
    draw = ImageDraw.Draw(canvas, "RGBA")
    if frame in (0, 1):
        draw.line([(56, 58), (56, 16)], fill=(75, 90, 110, 255), width=5)
        draw.line([(56, 56), (56, 18)], fill=(225, 240, 255, 255), width=2)
        draw.line([(48, 60), (64, 60)], fill=(240, 190, 50, 255), width=4)
    elif frame in (2, 3):
        draw.line([(56, 60), (56, 108)], fill=(75, 90, 110, 255), width=6)
        draw.line([(56, 62), (56, 106)], fill=(225, 240, 255, 255), width=3)
        draw.line([(56, 64), (56, 104)], fill=(255, 255, 255, 255), width=1)
        draw.line([(48, 62), (64, 62)], fill=(240, 190, 50, 255), width=4)
        draw.ellipse([(44, 102), (68, 112)], outline=(255, 220, 80, 240), width=2)
        draw.arc([(38, 50), (74, 108)], 0, 180, fill=(255, 240, 150, 200), width=3)
    elif frame == 4:
        draw.line([(56, 62), (56, 98)], fill=(75, 90, 110, 255), width=5)
        draw.line([(56, 64), (56, 96)], fill=(210, 225, 240, 255), width=2)
        draw.line([(48, 64), (64, 64)], fill=(240, 190, 50, 255), width=4)
    else:
        draw.line([(56, 68), (68, 38)], fill=(75, 90, 110, 255), width=5)
        draw.line([(56, 67), (67, 39)], fill=(200, 220, 235, 255), width=2)
        draw.line([(50, 68), (62, 72)], fill=(240, 190, 50, 255), width=4)
    return canvas


def place_tight_slash(
    sprite: Image.Image,
    crop_box: Tuple[int, int, int, int],
    target_h: int,
    is_left: bool,
    offset_x: int = 0,
) -> Image.Image:
    """Tightly crops to knight and greatsword, scaling so the entire blade and tip fit inside the 112px canvas with zero cut off."""
    cropped = sprite.crop(crop_box) if crop_box is not None else sprite
    scale = target_h / float(max(1, cropped.height))
    new_w = int(cropped.width * scale)
    new_h = target_h

    # Ensure width never exceeds 108px so margins are always >= 2px
    if new_w > 108:
        scale_w = 108.0 / new_w
        new_w = 108
        new_h = max(1, int(new_h * scale_w))

    scaled = cropped.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))

    # Center cleanly within 112px canvas so margins on both sides are >= 2px
    paste_x = (FRAME_W - new_w) // 2 + (offset_x if not is_left else -offset_x)
    paste_y = 108 - new_h

    # Clamp safely inside canvas with guaranteed margin
    paste_x = max(2, min(FRAME_W - new_w - 2, paste_x))

    canvas.paste(scaled, (paste_x, paste_y), scaled)
    if is_left:
        canvas = ImageOps.mirror(canvas)
    return canvas


def draw_footstep_dust(img: Image.Image, foot_x: int, foot_y: int, intensity: float = 1.0) -> Image.Image:
    """Draws authentic 2D pixel-art wasteland footstep dust puff at foot contact point."""
    draw = ImageDraw.Draw(img, "RGBA")
    w = int(7 * intensity)
    h = int(3 * intensity)
    dust_alpha = int(160 * intensity)
    draw.ellipse((foot_x - w, foot_y - h, foot_x + w, foot_y + h), fill=(168, 142, 108, dust_alpha))
    draw.ellipse((foot_x - w + 2, foot_y - h + 1, foot_x + w - 2, foot_y), fill=(215, 190, 150, int(dust_alpha * 0.85)))
    draw.point((foot_x - w - 1, foot_y - 1), fill=(145, 120, 90, dust_alpha))
    draw.point((foot_x + w + 1, foot_y - 2), fill=(145, 120, 90, dust_alpha))
    draw.point((foot_x - 2, foot_y - h - 1), fill=(205, 180, 140, dust_alpha))
    draw.point((foot_x + 3, foot_y - h - 2), fill=(205, 180, 140, dust_alpha))
    return img


def place_in_frame(
    sprite: Image.Image,
    target_h: int = 84,
    anchor_x: int = 56,
    anchor_y: int = 108,
    max_w: int = 96,
    offset_x: int = 0,
    offset_y: int = 0,
) -> Image.Image:
    """Scales a sprite to target height and centers it safely within the 112x128 canvas."""
    scale = target_h / max(1, sprite.height)
    new_w = int(sprite.width * scale)
    new_h = target_h

    # If wider than max_w, scale down proportionally so margins are preserved
    if new_w > max_w:
        scale_w = max_w / new_w
        new_w = max_w
        new_h = max(1, int(new_h * scale_w))

    scaled = sprite.resize((new_w, new_h), Image.LANCZOS)
    canvas = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))

    x = anchor_x - new_w // 2 + offset_x
    y = anchor_y - new_h + offset_y

    # Clamp safely inside canvas to guarantee zero clipping
    x = max(3, min(FRAME_W - new_w - 3, x))
    y = max(3, min(FRAME_H - new_h - 3, y))

    canvas.paste(scaled, (x, y), scaled)
    return canvas


def generate_frame(
    assets: ExtractedKnightAssets,
    action: str,
    direction: int,
    frame: int,
    loadout: str = "blade",
) -> Image.Image:
    """Generates a single 112x128 frame according to action, direction, frame index, and loadout."""
    # Base directional turnaround sprite from Row 0
    base_idx = DIR_TO_ROW0_INDEX.get(direction, 0)
    base_sprite = assets.row0_sprites[base_idx]

    # Normalized progress [0, 1)
    progress = frame / max(1, FRAMES_PER_ACTION - 1)
    cycle = (frame / FRAMES_PER_ACTION) * 2.0 * math.pi

    if action == "idle":
        # Subtle armor respiration & cape bob
        bob_y = int(round(math.sin(cycle) * 1.2))
        return place_in_frame(base_sprite, target_h=84, offset_y=bob_y)

    elif action == "walk":
        # 8-direction walking locomotion with authentic wasteland footstep dust VFX
        if direction == 2:  # Down (South) - articulated walk cycle with alternating sabaton footfalls & dust
            bobs = [1, 0, -1, 0, 1, 0, -1, 0]
            sways = [-1, -1, 0, 1, 1, 1, 0, -1]
            bob_y = bobs[frame % 8]
            sway_x = sways[frame % 8]
            frame_img = place_in_frame(base_sprite, target_h=84, offset_x=sway_x, offset_y=bob_y)
            draw = ImageDraw.Draw(frame_img, "RGBA")
            if frame in (0, 1):  # Left foot forward / plant
                draw.rectangle((41, 105, 47, 108), fill=(75, 95, 115, 230))
                draw.rectangle((41, 108, 47, 109), fill=(180, 150, 70, 240))
            elif frame in (4, 5):  # Right foot forward / plant
                draw.rectangle((65, 105, 71, 108), fill=(75, 95, 115, 230))
                draw.rectangle((65, 108, 71, 109), fill=(180, 150, 70, 240))
            # Dynamic ground dust puffs on footfall impacts
            if frame == 1:
                draw_footstep_dust(frame_img, 39, 108, 1.0)
            elif frame == 2:
                draw_footstep_dust(frame_img, 37, 107, 0.55)
            elif frame == 5:
                draw_footstep_dust(frame_img, 73, 108, 1.0)
            elif frame == 6:
                draw_footstep_dust(frame_img, 75, 107, 0.55)
            return frame_img
        elif direction in (0, 1):  # Facing East (0) or South-East (1)
            walk_idx = frame % len(assets.walk_sprites)
            w_sprite = assets.walk_sprites[walk_idx]
            bob_y = int(round(math.sin(cycle) * 1.5))
            f_img = place_in_frame(w_sprite, target_h=84, offset_y=bob_y)
            if frame == 1:
                draw_footstep_dust(f_img, 44, 108, 1.0)
            elif frame == 5:
                draw_footstep_dust(f_img, 66, 108, 1.0)
            return f_img
        elif direction in (3, 4):  # Facing South-West (3) or West (4) - mirrored
            walk_idx = frame % len(assets.walk_sprites)
            w_sprite = ImageOps.mirror(assets.walk_sprites[walk_idx])
            bob_y = int(round(math.sin(cycle) * 1.5))
            f_img = place_in_frame(w_sprite, target_h=84, offset_y=bob_y)
            if frame == 1:
                draw_footstep_dust(f_img, 68, 108, 1.0)
            elif frame == 5:
                draw_footstep_dust(f_img, 46, 108, 1.0)
            return f_img
        else:  # Facing North-West (5), North (6), or North-East (7)
            step_bob = int(round(math.sin(cycle * 2.0) * 2.0))
            stride_sway = int(round(math.cos(cycle) * 1.5))
            f_img = place_in_frame(base_sprite, target_h=84, offset_x=stride_sway, offset_y=step_bob)
            if frame == 1:
                draw_footstep_dust(f_img, 46, 108, 0.9)
            elif frame == 5:
                draw_footstep_dust(f_img, 66, 108, 0.9)
            return f_img

    elif action == "slash":
        # Broadsword cleave attack combo 1 - strictly preserves intact greatsword blade & aim facing
        if loadout == "heavy":
            # Warhammer overhead smash
            if frame in (0, 1):
                return place_in_frame(assets.hammer_sprite, target_h=88, offset_y=-2)
            elif frame in (2, 3):  # Apex raise
                return place_in_frame(assets.hammer_sprite, target_h=90, offset_y=-4)
            elif frame in (4, 5):  # Downward slam
                frame_img = place_in_frame(base_sprite, target_h=82, offset_y=4)
                draw = ImageDraw.Draw(frame_img, "RGBA")
                draw.ellipse((36, 102, 76, 114), outline=(245, 180, 50, 200), width=2)
                return frame_img
            else:  # Recovery
                return place_in_frame(base_sprite, target_h=84)
        else:
            if direction == 6:  # North (Up) - upward vertical greatsword cleave
                bob_y = -2 if frame in (2, 3) else (1 if frame == 4 else 0)
                c = place_in_frame(assets.row0_sprites[4], target_h=84, offset_y=bob_y)
                return draw_sword_north(c, frame)
            elif direction == 2:  # South (Down) - downward vertical greatsword chop
                bob_y = 2 if frame in (2, 3) else 0
                c = place_in_frame(assets.row0_sprites[0], target_h=84, offset_y=bob_y)
                return draw_sword_south(c, frame)
            else:
                # Broadsword sweeping slash: strictly faces attacking direction with zero 180-degree flip
                is_left = direction in (3, 4, 5)
                if frame == 0:
                    return place_tight_slash(assets.slash_sprites[0], None, 84, is_left, offset_x=-2)
                elif frame == 1:  # Deep coiled windup facing target
                    return place_tight_slash(assets.slash_sprites[0], None, 85, is_left, offset_x=-4)
                elif frame in (2, 3):  # Explosive forward slash with fully intact greatsword blade and tip
                    return place_tight_slash(assets.slash_sprites[1], None, 82, is_left, offset_x=1)
                elif frame == 4:  # Follow-through
                    return place_tight_slash(assets.slash_sprites[2], None, 84, is_left, offset_x=1)
                elif frame == 5:
                    return place_tight_slash(assets.slash_sprites[2], None, 84, is_left, offset_x=0)
                elif frame == 6:  # Forward low recovery holding sword
                    return place_tight_slash(assets.slash_sprites[3], None, 84, is_left, offset_x=-1)
                else:  # Reset to guard holding sword
                    return place_tight_slash(assets.slash_sprites[3], None, 84, is_left, offset_x=0)

    elif action == "draw_sword":
        # Combo hit 2: rising backhand cleave - strictly faces aiming direction with zero 180-degree flip
        if direction == 6:  # North (Up) - rising back-stance cleave
            bob_y = 1 if frame in (0, 1) else (-2 if frame in (2, 3) else 0)
            c = place_in_frame(assets.row0_sprites[4], target_h=84, offset_y=bob_y)
            return draw_sword_north(c, (frame + 2) % 8)
        elif direction == 2:  # South (Down) - rising front-stance cross cleave
            bob_y = 1 if frame in (0, 1) else (2 if frame in (2, 3) else 0)
            c = place_in_frame(assets.row0_sprites[0], target_h=84, offset_y=bob_y)
            return draw_sword_south(c, (frame + 2) % 8)
        else:
            is_left = direction in (3, 4, 5)
            if frame in (0, 1):  # Low forward stance windup
                return place_tight_slash(assets.slash_sprites[3], None, 83, is_left, offset_x=-2)
            elif frame in (2, 3):  # Rising slash cleave with intact sword
                return place_tight_slash(assets.slash_sprites[1], None, 82, is_left, offset_x=0)
            elif frame in (4, 5):  # Apex follow-through
                return place_tight_slash(assets.slash_sprites[2], None, 84, is_left, offset_x=0)
            else:  # Return to guard
                return place_tight_slash(assets.slash_sprites[0], None, 84, is_left, offset_x=-1)

    elif action == "shoot":
        # Mechanical crossbow / arbalest with directional 8-way aiming
        # Directions:
        # 0: right (E), 1: down_right (SE), 2: down (S), 3: down_left (SW)
        # 4: left (W), 5: up_left (NW), 6: up (N), 7: up_right (NE)
        is_left = direction in (3, 4, 5)

        # Base angles
        if direction == 0:
            angle = 0
        elif direction == 1:
            angle = -12
        elif direction == 2:
            angle = -24
        elif direction == 3:
            angle = 20
        elif direction == 4:
            angle = 0
        elif direction == 5:
            angle = -16
        elif direction == 6:
            angle = 24
        else: # 7
            angle = 14

        cb_base = ImageOps.mirror(assets.crossbow_sprite) if is_left else assets.crossbow_sprite
        if angle != 0:
            cb_aimed = cb_base.rotate(angle, resample=Image.BICUBIC)
        else:
            cb_aimed = cb_base

        if frame in (0, 1): # Aiming stance
            return place_in_frame(cb_aimed, target_h=84, offset_x=-1 if is_left else 1)
        elif frame == 2: # Firing bolt with dynamic golden muzzle spark!
            shoot_img = place_in_frame(cb_aimed, target_h=84, offset_x=-1 if is_left else 1)
            draw = ImageDraw.Draw(shoot_img, "RGBA")
            rad = math.radians(-angle)
            cx, cy = 56, 68
            if is_left:
                base_mx = 22
                mx = int(cx + (base_mx - cx) * math.cos(rad) - (68 - cy) * math.sin(rad))
                my = int(cy + (base_mx - cx) * math.sin(rad) + (68 - cy) * math.cos(rad))
                draw.line((mx + 4, my, mx - 8, my), fill=(255, 230, 110, 240), width=2)
                draw.line((mx + 2, my - 4, mx - 6, my + 4), fill=(255, 190, 50, 220), width=2)
                draw.ellipse((mx - 2, my - 2, mx + 3, my + 3), fill=(255, 255, 220, 255))
            else:
                base_mx = 90
                mx = int(cx + (base_mx - cx) * math.cos(rad) - (68 - cy) * math.sin(rad))
                my = int(cy + (base_mx - cx) * math.sin(rad) + (68 - cy) * math.cos(rad))
                draw.line((mx - 4, my, mx + 8, my), fill=(255, 230, 110, 240), width=2)
                draw.line((mx - 2, my - 4, mx + 6, my + 4), fill=(255, 190, 50, 220), width=2)
                draw.ellipse((mx - 2, my - 2, mx + 3, my + 3), fill=(255, 255, 220, 255))
            return shoot_img
        elif frame in (3, 4): # Recoil kickback opposite to aim
            recoil_x = 3 if is_left else -3
            return place_in_frame(cb_aimed, target_h=84, offset_x=recoil_x, offset_y=-1)
        elif frame in (5, 6): # Crank reload step
            return place_in_frame(cb_aimed, target_h=83, offset_x=-1 if is_left else 1, offset_y=1)
        else: # Return to ready
            return place_in_frame(cb_aimed, target_h=84, offset_x=-1 if is_left else 1)


    elif action == "swap_tool":
        # Defensive shield block stance & weapon swap
        if frame in (0, 1):
            return place_in_frame(base_sprite, target_h=84, offset_x=1)
        elif frame in (2, 3, 4): # Shield raised forward
            shield_block = place_in_frame(base_sprite, target_h=85, offset_x=-1)
            # Golden shield flare highlight
            draw = ImageDraw.Draw(shield_block, "RGBA")
            draw.arc((66, 52, 94, 92), -60, 60, fill=(240, 190, 60, 180), width=2)
            return shield_block
        else:
            return place_in_frame(base_sprite, target_h=84)

    elif action == "interact":
        # Reaching gauntleted arm forward to salvage or interact
        if frame in (0, 1):
            return place_in_frame(base_sprite, target_h=84)
        elif frame in (2, 3, 4): # Reaching forward with cyan data-calibration glow
            inter_img = place_in_frame(base_sprite, target_h=84, offset_x=2, offset_y=1)
            draw = ImageDraw.Draw(inter_img, "RGBA")
            draw.ellipse((72, 68, 78, 74), fill=(60, 230, 240, 210))
            draw.arc((68, 64, 82, 78), 0, 360, fill=(40, 200, 230, 140), width=1)
            return inter_img
        else:
            return place_in_frame(base_sprite, target_h=84)

    elif action == "hit":
        # Severe impact recoil with bright golden spark burst
        if frame == 0:
            return place_in_frame(base_sprite, target_h=84)
        elif frame in (1, 2): # Spark impact burst
            return place_in_frame(assets.hurt_sprite, target_h=84, offset_x=-3, offset_y=-1)
        elif frame in (3, 4): # Recoil shudder
            return place_in_frame(assets.hurt_sprite, target_h=83, offset_x=-4, offset_y=1)
        elif frame in (5, 6): # Regaining balance
            return place_in_frame(base_sprite, target_h=83, offset_x=-1)
        else:
            return place_in_frame(base_sprite, target_h=84)

    elif action == "dead":
        # Collapsed defeat sequence - guaranteed zero clipping!
        if frame in (0, 1): # Fatal stagger
            return place_in_frame(assets.hurt_sprite, target_h=84, offset_x=-4, offset_y=-2)
        elif frame in (2, 3): # Drop to knees
            return place_in_frame(base_sprite, target_h=72, offset_y=8)
        elif frame in (4, 5): # Collapsing downward
            return place_in_frame(assets.dead_sprite, target_h=42, max_w=94, anchor_y=108)
        else: # Fully collapsed defeat pose resting peacefully on ground
            # Width = 94px inside 112px canvas (margin = 9px on left and right)
            return place_in_frame(assets.dead_sprite, target_h=38, max_w=94, anchor_y=108)

    # Fallback
    return place_in_frame(base_sprite, target_h=84)


def build_crusader_knight_atlas() -> None:
    source_sheet_path = ROOT / "docs" / "concepts" / "crusader_knight_pixel_spritesheet.png"
    if not source_sheet_path.exists():
        raise FileNotFoundError(f"Missing source spritesheet: {source_sheet_path}")

    print("[CRUSADER_BUILDER] Cleaning and extracting authentic 2D pixel art...")
    cleaned_sheet = extract_and_clean_source_sheet(source_sheet_path)
    assets = ExtractedKnightAssets(cleaned_sheet)

    PLAYER_DIR.mkdir(parents=True, exist_ok=True)
    ACTIONS_DIR.mkdir(parents=True, exist_ok=True)
    FRAMES_DIR.mkdir(parents=True, exist_ok=True)

    loadouts = ["blade", "heavy", "rifle"]
    blade_cells: Dict[Tuple[str, int, int], Image.Image] = {}

    for loadout in loadouts:
        print(f"[CRUSADER_BUILDER] Rendering loadout '{loadout}'...")
        atlas = Image.new("RGBA", (FRAME_W * FRAMES_PER_ACTION * len(ACTIONS), FRAME_H * DIRECTIONS), (0, 0, 0, 0))
        for ai, action in enumerate(ACTIONS):
            for d in range(DIRECTIONS):
                for f in range(FRAMES_PER_ACTION):
                    frame_img = generate_frame(assets, action, d, f, loadout=loadout)
                    if loadout == "blade":
                        blade_cells[(action, d, f)] = frame_img
                    col = ai * FRAMES_PER_ACTION + f
                    atlas.alpha_composite(frame_img, (col * FRAME_W, d * FRAME_H))

        out_path = PLAYER_DIR / f"r17_loadout_{loadout}.png"
        atlas.save(out_path)

        if loadout == "blade":
            for target_name in (
                "recycler_player_multiaction_8dir_preview.png",
                "recycler_player_multiaction_8dir.png",
                "r17_wasteland_8dir_actions.png",
            ):
                atlas.save(PLAYER_DIR / target_name)
            DOCS_DIR.mkdir(parents=True, exist_ok=True)
            atlas.save(DOCS_DIR / "recycler_player_multiaction_8dir_preview.png")

    print("[CRUSADER_BUILDER] Saving split frames and individual action sheets...")
    for ai, action in enumerate(ACTIONS):
        sheet = Image.new("RGBA", (FRAME_W * FRAMES_PER_ACTION, FRAME_H * DIRECTIONS), (0, 0, 0, 0))
        for d in range(DIRECTIONS):
            folder = FRAMES_DIR / action / f"dir_{d}"
            folder.mkdir(parents=True, exist_ok=True)
            for f in range(FRAMES_PER_ACTION):
                frame_img = blade_cells[(action, d, f)]
                frame_img.save(folder / f"frame_{f}.png")
                sheet.alpha_composite(frame_img, (f * FRAME_W, d * FRAME_H))
        sheet.save(ACTIONS_DIR / f"{action}.png")
        if action == "walk":
            sheet.save(PLAYER_DIR / "recycler_player_8dir.png")

    # Generate diagnostic sheet to visually verify all actions and directions
    print("[CRUSADER_BUILDER] Generating visual verification diagnostic...")
    diag_rows = [
        ("blade", "idle", list(range(8)), 2),       # Front idle
        ("blade", "walk", list(range(8)), 1),       # SE walk cycle
        ("blade", "slash", list(range(8)), 1),      # Broadsword cleave with golden arc
        ("blade", "draw_sword", list(range(8)), 1), # Rising slash combo 2
        ("rifle", "shoot", list(range(8)), 0),      # Crossbow shoot with muzzle flash
        ("heavy", "slash", list(range(8)), 2),      # Heavy warhammer slam
        ("blade", "hit", list(range(8)), 2),        # Hurt recoil with sparks
        ("blade", "dead", list(range(8)), 2),       # Collapsed defeat (zero clipping)
    ]
    diag_sheet = Image.new("RGBA", (FRAME_W * 8, FRAME_H * len(diag_rows)), (20, 24, 30, 255))
    for ri, (lo, act, frame_list, d) in enumerate(diag_rows):
        for ci, f in enumerate(frame_list):
            img = generate_frame(assets, act, d, f, loadout=lo)
            diag_sheet.alpha_composite(img, (ci * FRAME_W, ri * FRAME_H))

    diag_sheet.save(DOCS_DIR / "player_split_frame_diagnostic.png")
    diag_sheet.save(DOCS_DIR / "concepts" / "crusader_knight_diagnostic.png")
    print("[CRUSADER_BUILDER] Done! Generated master atlas, 3 loadouts, 9 action sheets, and 576 split frames.")


if __name__ == "__main__":
    build_crusader_knight_atlas()
