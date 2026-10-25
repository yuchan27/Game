"""
Build All Medieval Wasteland Objects Pipeline.

Extracts, cleans, pixel-aligns, and exports all 2.5D / 2D pixel-art:
1. Materials & Collectibles (12 distinct RPG items)
2. Camp Structures & Gates (forge, craft, shop, mod_station, recycle, save, gates)
3. Biome Gathering Nodes & Props (crystals, acid pools, scrap heaps, ore veins, herbs, barrels)
4. Prop Variants (8 organic biome variants per prop)
5. Visual Assets Manifest synchronization
"""

from __future__ import annotations

import hashlib
import json
from collections import deque
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageEnhance, ImageOps

GAME_ROOT = Path(r"C:\Code\Game\first-game")
SPRITES = GAME_ROOT / "assets" / "sprites"
DOCS_DIR = GAME_ROOT / "docs" / "concepts"
ART_DIR = Path(r"C:\Users\wuwu6\.gemini\antigravity\brain\570862f6-1da4-487f-9851-ea917a94a8d1")

ITEMS_SHEET_SRC = ART_DIR / "wasteland_medieval_items_spritesheet_1792658270990.jpg"
PROPS_SHEET_SRC = ART_DIR / "wasteland_medieval_props_and_structures_1792658289428.jpg"


def strip_dark_bg(im: Image.Image, tolerance: int = 24) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    arr = np.array(im, dtype=np.int32)

    samples = [arr[0, 0], arr[0, w - 1], arr[h - 1, 0], arr[h - 1, w - 1]]
    bg_r = sum(s[0] for s in samples) // len(samples)
    bg_g = sum(s[1] for s in samples) // len(samples)
    bg_b = sum(s[2] for s in samples) // len(samples)

    diff = np.abs(arr[:, :, 0] - bg_r) + np.abs(arr[:, :, 1] - bg_g) + np.abs(arr[:, :, 2] - bg_b)

    visited = np.zeros((h, w), dtype=bool)
    q = deque()
    for x in range(w):
        q.append((0, x))
        q.append((h - 1, x))
    for y in range(h):
        q.append((y, 0))
        q.append((y, w - 1))
    for y, x in q:
        visited[y, x] = True

    while q:
        cy, cx = q.popleft()
        for dy, dx in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            ny, nx = cy + dy, cx + dx
            if 0 <= ny < h and 0 <= nx < w and not visited[ny, nx]:
                if diff[ny, nx] <= tolerance:
                    visited[ny, nx] = True
                    q.append((ny, nx))

    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[:, :, :3] = arr[:, :, :3]
    rgba[:, :, 3] = 255
    rgba[visited, 3] = 0

    alpha = rgba[:, :, 3]
    y_idx = np.where(alpha > 0)[0]
    x_idx = np.where(alpha > 0)[1]
    if len(y_idx) == 0:
        return Image.new("RGBA", (10, 10), (0, 0, 0, 0))
    return Image.fromarray(rgba[y_idx.min():y_idx.max() + 1, x_idx.min():x_idx.max() + 1], "RGBA")


def fit_on_canvas(
    fg: Image.Image,
    target_size: tuple[int, int],
    pad_x: int = 4,
    pad_y: int = 4,
    align_bottom: bool = True,
    ground_shadow: bool = False
) -> Image.Image:
    tw, th = target_size
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")

    avail_w = max(4, tw - pad_x * 2)
    avail_h = max(4, th - pad_y * 2)
    scale = min(avail_w / max(1, fg.width), avail_h / max(1, fg.height))
    nw = max(1, int(round(fg.width * scale)))
    nh = max(1, int(round(fg.height * scale)))
    resized = fg.resize((nw, nh), Image.NEAREST)

    px = (tw - nw) // 2
    py = (th - pad_y - nh) if align_bottom else (th - nh) // 2

    if ground_shadow:
        sw = int(nw * 0.45)
        sh = max(4, int(th * 0.06))
        sy = py + nh - sh // 3
        draw.ellipse((tw // 2 - sw, sy - sh, tw // 2 + sw, sy + sh), fill=(8, 6, 12, 100))

    canvas.alpha_composite(resized, (px, py))
    return canvas


def build_all_items() -> None:
    print("[BUILD] Slicing and updating all 12 items & materials...")
    mat_dir = SPRITES / "items" / "materials"
    drop_dir = SPRITES / "items" / "掉落物"
    mat_dir.mkdir(parents=True, exist_ok=True)
    drop_dir.mkdir(parents=True, exist_ok=True)

    items_sheet = Image.open(ITEMS_SHEET_SRC).convert("RGB")
    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    items_sheet.save(DOCS_DIR / "wasteland_medieval_items_spritesheet.png")

    w, h = items_sheet.size
    cw = w // 4
    rh = h // 3

    item_names = [
        "scrap_metal", "ammo", "mutant_core", "bio_crystal",
        "alloy_plate", "broken_coil", "mutant_herb", "acid_sac",
        "amethyst_gem", "precision_chip", "dynamo_core", "terminal_controller"
    ]

    for idx, name in enumerate(item_names):
        col = idx % 4
        row = idx // 4
        box = (col * cw + 10, row * rh + 10, (col + 1) * cw - 10, (row + 1) * rh - 10)
        cell = items_sheet.crop(box)
        cleaned = strip_dark_bg(cell, tolerance=24)

        # Standard 64x64 item icon
        item_icon = fit_on_canvas(cleaned, (64, 64), pad_x=4, pad_y=4, align_bottom=False)

        # Save to materials/
        if name == "terminal_controller":
            item_icon.save(SPRITES / "items" / "terminal_controller.png")
            item_icon.save(mat_dir / "terminal_controller.png")
        else:
            item_icon.save(mat_dir / f"{name}.png")

        # Save compatibility mirrors for 掉落物/
        if name == "scrap_metal":
            item_icon.save(drop_dir / "1.png")
        elif name == "ammo":
            item_icon.save(drop_dir / "2.png")
        elif name == "bio_crystal":
            item_icon.save(drop_dir / "3.png")
        elif name == "mutant_core":
            item_icon.save(drop_dir / "4.png")

    print("[BUILD] Items & materials completed.")


def build_all_structures_and_props() -> None:
    print("[BUILD] Slicing and updating camp structures, gates, and biome props...")
    s_dir = SPRITES / "structures"
    p_dir = SPRITES / "props"
    v_dir = p_dir / "variants"
    s_dir.mkdir(parents=True, exist_ok=True)
    p_dir.mkdir(parents=True, exist_ok=True)
    v_dir.mkdir(parents=True, exist_ok=True)

    props_sheet = Image.open(PROPS_SHEET_SRC).convert("RGB")
    props_sheet.save(DOCS_DIR / "wasteland_medieval_props_and_structures.png")

    sw, sh = props_sheet.size
    cw4 = sw // 4
    cw6 = sw // 6

    # 1. Structures & Gates (Rows 0 and 1)
    struct_targets = [
        ("forge.png", 0, 0, (192, 150)),
        ("craft.png", 1, 0, (176, 140)),
        ("shop.png", 2, 0, (184, 132)),
        ("mod_station.png", 3, 0, (196, 146)),
        ("recycle_machine.png", 0, 1, (184, 132)),
        ("save_station.png", 1, 1, (168, 132)),
        ("guild_gate.png", 2, 1, (190, 128)),
        ("village_return_gate.png", 3, 1, (184, 128)),
    ]

    for filename, c, r, sz in struct_targets:
        box = (c * cw4 + 8, r * 256 + 8, (c + 1) * cw4 - 8, (r + 1) * 256 - 8)
        cell = props_sheet.crop(box)
        cleaned = strip_dark_bg(cell, tolerance=26)
        out = fit_on_canvas(cleaned, sz, pad_x=4, pad_y=4, align_bottom=True)
        out.save(s_dir / filename)
        if filename == "village_return_gate.png":
            out.save(s_dir / "return_gate.png")
        if filename == "guild_gate.png":
            # Distinct weathered rust wasteland gate (184, 128)
            w_cleaned = ImageEnhance.Color(cleaned).enhance(0.82)
            w_cleaned = ImageEnhance.Brightness(w_cleaned).enhance(0.91)
            w_gate = fit_on_canvas(w_cleaned, (184, 128), pad_x=4, pad_y=4, align_bottom=True)
            w_gate.save(s_dir / "wasteland_gate.png")
            # Distinct route gate (184, 128)
            r_cleaned = ImageEnhance.Contrast(cleaned).enhance(1.12)
            r_gate = fit_on_canvas(r_cleaned, (184, 128), pad_x=4, pad_y=4, align_bottom=True)
            r_gate.save(s_dir / "route_gate.png")

    # 2. Props (Row 2)
    props_targets = [
        ("crystal_node", 0, 2, (96, 80)),
        ("toxic_pool", 1, 2, (96, 80)),
        ("scrap_pile", 2, 2, (96, 80)),
        ("ore_node", 3, 2, (96, 80)),
        ("herb_patch", 4, 2, (96, 80)),
        ("barrel_stack", 5, 2, (96, 80)),
    ]

    extracted_props: Dict[str, Image.Image] = {}
    for name, c, r, sz in props_targets:
        box = (c * cw6 + 6, r * 256 + 6, (c + 1) * cw6 - 6, (r + 1) * 256 - 6)
        cell = props_sheet.crop(box)
        cleaned = strip_dark_bg(cell, tolerance=26)
        extracted_props[name] = cleaned
        out = fit_on_canvas(cleaned, sz, pad_x=4, pad_y=4, align_bottom=True)
        out.save(p_dir / f"{name}.png")

    # 3. Canonical Manifest Props & 8-Variants Generation
    manifest_prop_map = [
        ("rust_rock", extracted_props["ore_node"], (72, 62)),
        ("dead_tree", extracted_props["herb_patch"], (72, 110)),
        ("scrap_wall", extracted_props["scrap_pile"], (96, 66)),
        ("toxic_pool", extracted_props["toxic_pool"], (88, 54)),
        ("wreck", extracted_props["scrap_pile"], (104, 78)),
        ("signal_pylon", extracted_props["crystal_node"], (72, 128)),
        ("road_marker", extracted_props["barrel_stack"], (42, 58)),
        ("scrap_barricade", extracted_props["barrel_stack"], (104, 70)),
    ]

    for prop_id, base_fg, target_sz in manifest_prop_map:
        base_img = fit_on_canvas(base_fg, target_sz, pad_x=4, pad_y=4, align_bottom=True)
        base_img.save(p_dir / f"{prop_id}.png")

        for v_idx in range(8):
            var_fg = base_fg.copy()
            if v_idx % 2 == 1:
                var_fg = ImageOps.mirror(var_fg)
            b_factor = 0.90 + (v_idx * 0.03)
            c_factor = 0.92 + ((v_idx % 4) * 0.05)
            var_fg = ImageEnhance.Brightness(var_fg).enhance(b_factor)
            var_fg = ImageEnhance.Contrast(var_fg).enhance(c_factor)
            pad_x = 3 + (v_idx % 3)
            pad_y = 3 + ((v_idx // 2) % 3)
            var_img = fit_on_canvas(var_fg, target_sz, pad_x=pad_x, pad_y=pad_y, align_bottom=True)
            var_img.save(v_dir / f"{prop_id}_{v_idx}.png")

    print("[BUILD] Structures, gates, and props completed.")


def sync_manifest() -> None:
    print("[BUILD] Synchronizing visual_assets.json manifest hashes & dimensions...")
    manifest_path = GAME_ROOT / "data" / "art" / "visual_assets.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    assets: dict[str, dict] = data.get("assets", {})

    for asset_id, entry in assets.items():
        rel = str(entry.get("path", "")).replace("res://", "", 1)
        disk_path = GAME_ROOT / rel
        if disk_path.is_file():
            raw = disk_path.read_bytes()
            im = Image.open(disk_path)
            entry["source_sha256"] = hashlib.sha256(raw).hexdigest()
            entry["source_dimensions"] = [im.width, im.height]

    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("[BUILD] Manifest synchronized successfully.")


def main() -> None:
    build_all_items()
    build_all_structures_and_props()
    sync_manifest()
    print("[BUILD] ALL MEDIEVAL WASTELAND OBJECTS REGENERATED AND SYNCHRONIZED!")


if __name__ == "__main__":
    main()
