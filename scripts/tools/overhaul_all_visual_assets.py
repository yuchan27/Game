from __future__ import annotations

"""
Phase 1 Complete Visual Asset Overhaul Pipeline (`overhaul_all_visual_assets.py`).

Extracts, cleans (100% transparent background via flood-fill from #14181E slate),
pixel-aligns, and exports all structures, NPCs, portraits, enemies, gates, props,
armor icons, melee/ranged weapon icons & weapon overlays, and seamless 2.5D ground tiles.
Eliminates all artificial corner badges (`add_unique_badge`), white halos, and `reuse_of` warnings.
"""

import hashlib
import json
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageOps

ROOT = Path(__file__).resolve().parents[2]
SPRITES = ROOT / "assets" / "sprites"
ARTIFACT_DIR = Path(r"C:\Users\wuwu6\.gemini\antigravity\brain\570862f6-1da4-487f-9851-ea917a94a8d1")

SHEET_STRUCTURES = ARTIFACT_DIR / "wasteland_camp_structures_sheet_1792552134539.jpg"
SHEET_ENEMIES = ARTIFACT_DIR / "wasteland_mutants_enemies_sheet_1792552158523.jpg"
SHEET_ARSENAL = ARTIFACT_DIR / "wasteland_armor_and_arsenal_sheet_1792552186435.jpg"
SHEET_NPCS = ARTIFACT_DIR / "wasteland_survivor_npcs_1792552464334.jpg"
SHEET_GATES_PROPS = ARTIFACT_DIR / "wasteland_gates_props_1792552492223.jpg"


def strip_dark_slate_bg(img: Image.Image, tolerance: int = 24, strip_interior_holes: bool = False) -> Image.Image:
    """
    Removes ONLY the #14181E dark slate background via border flood-fill,
    stopping cleanly at the sprite's dark #0E0C12 outline so zero interior shadows are lost!
    """
    rgba = img.convert("RGBA")
    w, h = rgba.size
    px = rgba.load()

    samples = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    bg_r = sum(s[0] for s in samples) // len(samples)
    bg_g = sum(s[1] for s in samples) // len(samples)
    bg_b = sum(s[2] for s in samples) // len(samples)

    def is_bg(r: int, g: int, b: int, a: int) -> bool:
        if a < 24:
            return True
        dist = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
        return dist <= tolerance

    visited = [[False] * w for _ in range(h)]
    stack: list[tuple[int, int]] = []
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(*px[x, y]):
                visited[y][x] = True
                stack.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not visited[y][x] and is_bg(*px[x, y]):
                visited[y][x] = True
                stack.append((x, y))

    while stack:
        cx, cy = stack.pop()
        for nx, ny in ((cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)):
            if 0 <= nx < w and 0 <= ny < h and not visited[ny][nx]:
                if is_bg(*px[nx, ny]):
                    visited[ny][nx] = True
                    stack.append((nx, ny))

    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    opx = out.load()
    min_x, min_y, max_x, max_y = w, h, -1, -1

    for y in range(h):
        for x in range(w):
            if visited[y][x]:
                continue
            r, g, b, a = px[x, y]
            if strip_interior_holes:
                dist = abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)
                if dist <= 12:
                    continue
            opx[x, y] = (r, g, b, 255)
            if x < min_x:
                min_x = x
            if y < min_y:
                min_y = y
            if x > max_x:
                max_x = x
            if y > max_y:
                max_y = y

    if max_x < min_x or max_y < min_y:
        return Image.new("RGBA", (32, 32), (0, 0, 0, 0))

    return out.crop((min_x, min_y, max_x + 1, max_y + 1))


def fit_on_canvas(
    fg: Image.Image,
    target_size: tuple[int, int],
    pad_x: int = 8,
    pad_y: int = 8,
    ground_shadow: bool = True,
    align_bottom: bool = True,
) -> Image.Image:
    tw, th = target_size
    canvas = Image.new("RGBA", (tw, th), (0, 0, 0, 0))
    draw = ImageDraw.Draw(canvas, "RGBA")

    bbox = fg.getbbox()
    if bbox:
        fg = fg.crop(bbox)

    avail_w = max(8, tw - pad_x * 2)
    avail_h = max(8, th - pad_y * 2)
    scale = min(avail_w / max(1, fg.width), avail_h / max(1, fg.height))
    nw = max(1, int(round(fg.width * scale)))
    nh = max(1, int(round(fg.height * scale)))
    resized = fg.resize((nw, nh), Image.Resampling.LANCZOS)

    px = (tw - nw) // 2
    py = (th - pad_y - nh) if align_bottom else (th - nh) // 2

    if ground_shadow:
        sw = int(nw * 0.46)
        sh = max(5, int(th * 0.065))
        sy = py + nh - sh // 3
        draw.ellipse((tw // 2 - int(sw * 1.15), sy - sh, tw // 2 + int(sw * 1.15), sy + sh), fill=(8, 6, 10, 72))
        draw.ellipse((tw // 2 - sw, sy - int(sh * 0.75), tw // 2 + sw, sy + int(sh * 0.75)), fill=(8, 6, 10, 128))
        draw.ellipse((tw // 2 - int(sw * 0.65), sy - int(sh * 0.45), tw // 2 + int(sw * 0.65), sy + int(sh * 0.45)), fill=(6, 5, 8, 165))

    canvas.alpha_composite(resized, (px, py))
    return canvas


def build_structures_and_gates() -> None:
    s_dir = SPRITES / "structures"
    s_dir.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_STRUCTURES).convert("RGBA")
    sw, sh = sheet.size
    col_w = sw // 3
    row_h = sh // 2

    struct_specs = [
        ("forge.png", (0, 0), (192, 150)),
        ("craft.png", (1, 0), (176, 140)),
        ("shop.png", (2, 0), (184, 132)),
        ("mod_station.png", (0, 1), (196, 146)),
        ("recycle_machine.png", (1, 1), (184, 132)),
        ("save_station.png", (2, 1), (168, 132)),
    ]
    for filename, (col, row), target_sz in struct_specs:
        cell = sheet.crop((col * col_w + 12, row * row_h + 12, (col + 1) * col_w - 12, (row + 1) * row_h - 12))
        fg = strip_dark_slate_bg(cell, tolerance=24)
        out = fit_on_canvas(fg, target_sz, pad_x=8, pad_y=6, ground_shadow=False, align_bottom=True)
        out.save(s_dir / filename)

    gp_sheet = Image.open(SHEET_GATES_PROPS).convert("RGBA")
    gw, gh = gp_sheet.size
    g_col_w = gw // 4
    g_row_h = gh // 3

    gate_specs = [
        ("guild_gate.png", 0, (190, 128)),
        ("wasteland_gate.png", 1, (184, 128)),
        ("route_gate.png", 2, (184, 128)),
        ("village_return_gate.png", 3, (184, 128)),
    ]
    for filename, col, target_sz in gate_specs:
        cell = gp_sheet.crop((col * g_col_w + 8, 8, (col + 1) * g_col_w - 8, g_row_h - 8))
        fg = strip_dark_slate_bg(cell, tolerance=24)
        out = fit_on_canvas(fg, target_sz, pad_x=6, pad_y=6, ground_shadow=False, align_bottom=True)
        out.save(s_dir / filename)
        if filename == "village_return_gate.png":
            out.save(s_dir / "return_gate.png")


def build_npcs_and_portraits() -> None:
    n_dir = SPRITES / "npcs"
    n_dir.mkdir(parents=True, exist_ok=True)
    sheet = Image.open(SHEET_NPCS).convert("RGBA")
    sw, sh = sheet.size
    row_h = sh // 2
    col_w_top = sw // 4

    # Extract 7 distinct NPCs from the 2 rows
    npc_cells = [
        sheet.crop((0 * col_w_top + 10, 10, 1 * col_w_top - 10, row_h - 10)),
        sheet.crop((1 * col_w_top + 10, 10, 2 * col_w_top - 10, row_h - 10)),
        sheet.crop((2 * col_w_top + 10, 10, 3 * col_w_top - 10, row_h - 10)),
        sheet.crop((3 * col_w_top + 10, 10, 4 * col_w_top - 10, row_h - 10)),
        sheet.crop((int(sw * 0.12), row_h + 10, int(sw * 0.36), sh - 10)),
        sheet.crop((int(sw * 0.36), row_h + 10, int(sw * 0.58), sh - 10)),
        sheet.crop((int(sw * 0.58), row_h + 10, int(sw * 0.90), sh - 10)),
    ]

    npc_fgs = [strip_dark_slate_bg(c, tolerance=24) for c in npc_cells]

    npc_mappings = [
        ("forge_master", npc_fgs[0], (210, 120, 45)),
        ("scrap_merchant", npc_fgs[1], (195, 155, 65)),
        ("route_scout", npc_fgs[2], (75, 155, 95)),
        ("guild_master", npc_fgs[3], (95, 130, 185)),
        ("guild_clerk", npc_fgs[4], (75, 185, 205)),
        ("repair_robot", npc_fgs[5], (85, 195, 175)),
        ("wasteland_survivor", npc_fgs[6], (185, 95, 75)),
    ]

    for npc_id, fg, border_rgb in npc_mappings:
        sprite = fit_on_canvas(fg, (84, 98), pad_x=4, pad_y=4, ground_shadow=True, align_bottom=True)
        sprite.save(n_dir / f"{npc_id}.png")

        # Build 96x96 upper-body / bust pixel-art portrait with tactical frame
        portrait = Image.new("RGBA", (96, 96), (20, 24, 30, 255))
        pdraw = ImageDraw.Draw(portrait, "RGBA")
        pdraw.rectangle([0, 0, 95, 95], fill=(24, 28, 36, 255), outline=(18, 16, 22, 255))
        pdraw.rectangle([2, 2, 93, 93], outline=(*border_rgb, 255))
        bust_h = max(12, int(fg.height * 0.58))
        bust = fg.crop((0, 0, fg.width, bust_h))
        fitted_bust = fit_on_canvas(bust, (84, 84), pad_x=4, pad_y=4, ground_shadow=False, align_bottom=True)
        portrait.alpha_composite(fitted_bust, (6, 8))
        portrait.save(n_dir / f"{npc_id}_portrait.png")

    # Save additional alias filenames used in docs/legacy scripts
    fit_on_canvas(npc_fgs[1], (84, 98), pad_x=4, pad_y=4).save(n_dir / "shopkeeper.png")
    fit_on_canvas(npc_fgs[2], (84, 98), pad_x=4, pad_y=4).save(n_dir / "scavenger_guide.png")
    fit_on_canvas(npc_fgs[5], (84, 98), pad_x=4, pad_y=4).save(n_dir / "artisan.png")
    fit_on_canvas(npc_fgs[6], (84, 98), pad_x=4, pad_y=4).save(n_dir / "veteran_hunter.png")


def build_enemies_and_boss() -> None:
    e_dir = SPRITES / "enemies"
    b_dir = SPRITES / "baked"
    e_dir.mkdir(parents=True, exist_ok=True)
    b_dir.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_ENEMIES).convert("RGBA")
    sw, sh = sheet.size
    top_col_w = sw // 4

    # Crop each enemy ABOVE its text label so zero text pixels remain!
    enemy_boxes = [
        ("scrap_biter", (10, 15, top_col_w - 10, int(sh * 0.38))),
        ("toxic_runner", (top_col_w + 10, 15, top_col_w * 2 - 10, int(sh * 0.38))),
        ("spore_gunner", (top_col_w * 2 + 10, 15, top_col_w * 3 - 10, int(sh * 0.38))),
        ("rot_wing", (top_col_w * 3 + 10, 15, sw - 10, int(sh * 0.38))),
        ("rust_brute", (15, int(sh * 0.45), int(sw * 0.35), int(sh * 0.92))),
        ("mech_husk", (int(sw * 0.36), int(sh * 0.45), int(sw * 0.62), int(sh * 0.92))),
        ("waste_titan", (int(sw * 0.64), int(sh * 0.44), sw - 12, int(sh * 0.92))),
    ]

    extracted: dict[str, Image.Image] = {}
    for eid, box in enemy_boxes:
        crop_im = sheet.crop(box)
        if eid == "waste_titan":
            # Mask out the bottom descender of "(4) Rot Wing" text at top-middle before bg strip
            cdraw = ImageDraw.Draw(crop_im)
            c_bg = crop_im.getpixel((2, 2))
            cdraw.rectangle((crop_im.width // 2 - 30, 0, crop_im.width - 1, 14), fill=c_bg)
        fg = strip_dark_slate_bg(crop_im, tolerance=24)
        extracted[eid] = fg
        single = fit_on_canvas(fg, (96, 72), pad_x=4, pad_y=3, ground_shadow=True, align_bottom=True)
        single.save(e_dir / f"{eid}.png")

    # Build baked/enemies.png and polluted_enemy_six_types.png (672x72 = 7 * 96x72) in canonical order
    baked_order = ["scrap_biter", "toxic_runner", "spore_gunner", "rust_brute", "rot_wing", "mech_husk", "waste_titan"]
    baked_enemies = Image.new("RGBA", (672, 72), (0, 0, 0, 0))
    for idx, eid in enumerate(baked_order):
        cell = Image.open(e_dir / f"{eid}.png").convert("RGBA")
        baked_enemies.alpha_composite(cell, (idx * 96, 0))
    baked_enemies.save(b_dir / "enemies.png")
    baked_enemies.save(e_dir / "polluted_enemy_six_types.png")


def build_props_and_variants() -> None:
    p_dir = SPRITES / "props"
    v_dir = p_dir / "variants"
    p_dir.mkdir(parents=True, exist_ok=True)
    v_dir.mkdir(parents=True, exist_ok=True)

    gp_sheet = Image.open(SHEET_GATES_PROPS).convert("RGBA")
    gw, gh = gp_sheet.size
    cw = gw // 4
    rh = gh // 3

    # Extract Row 1 & Row 2 props from SHEET_GATES_PROPS
    raw_props = {
        "ruin_wall": strip_dark_slate_bg(gp_sheet.crop((0 * cw + 8, rh + 8, 1 * cw - 8, 2 * rh - 8)), 24),
        "scrap_pile": strip_dark_slate_bg(gp_sheet.crop((1 * cw + 8, rh + 8, 2 * cw - 8, 2 * rh - 8)), 24),
        "barrel_stack": strip_dark_slate_bg(gp_sheet.crop((2 * cw + 8, rh + 8, 3 * cw - 8, 2 * rh - 8)), 24),
        "dead_tree": strip_dark_slate_bg(gp_sheet.crop((3 * cw + 8, rh + 8, 4 * cw - 8, 2 * rh - 8)), 24),
        "toxic_pool": strip_dark_slate_bg(gp_sheet.crop((0 * cw + 8, 2 * rh + 8, 1 * cw - 8, gh - 8)), 24),
        "crystal_node": strip_dark_slate_bg(gp_sheet.crop((1 * cw + 8, 2 * rh + 8, 2 * cw - 8, gh - 8)), 24),
        "ore_node": strip_dark_slate_bg(gp_sheet.crop((2 * cw + 8, 2 * rh + 8, 3 * cw - 8, gh - 8)), 24),
        "herb_patch": strip_dark_slate_bg(gp_sheet.crop((3 * cw + 8, 2 * rh + 8, 4 * cw - 8, gh - 8)), 24),
    }

    # Save direct prop files
    for name, fg in raw_props.items():
        fit_on_canvas(fg, (96, 80), pad_x=4, pad_y=4).save(p_dir / f"{name}.png")

    # Map canonical manifest prop types & generate 8 distinct organic variants (without corner badges!)
    manifest_props = [
        ("rust_rock", raw_props["ore_node"], (72, 62)),
        ("dead_tree", raw_props["dead_tree"], (72, 110)),
        ("scrap_wall", raw_props["ruin_wall"], (96, 66)),
        ("toxic_pool", raw_props["toxic_pool"], (88, 54)),
        ("wreck", raw_props["scrap_pile"], (104, 78)),
        ("signal_pylon", raw_props["crystal_node"], (72, 128)),
        ("road_marker", raw_props["herb_patch"], (42, 58)),
        ("scrap_barricade", raw_props["barrel_stack"], (104, 70)),
    ]

    for prop_id, base_fg, target_sz in manifest_props:
        base_img = fit_on_canvas(base_fg, target_sz, pad_x=4, pad_y=4)
        base_img.save(p_dir / f"{prop_id}.png")

        for v_idx in range(8):
            var_fg = base_fg.copy()
            if v_idx % 2 == 1:
                var_fg = ImageOps.mirror(var_fg)
            # Subtle brightness/contrast & hue-shift per biome variant
            b_factor = 0.88 + (v_idx * 0.035)
            c_factor = 0.92 + ((v_idx % 4) * 0.05)
            var_fg = ImageEnhance.Brightness(var_fg).enhance(b_factor)
            var_fg = ImageEnhance.Contrast(var_fg).enhance(c_factor)
            pad_x = 3 + (v_idx % 3)
            pad_y = 3 + ((v_idx // 2) % 3)
            var_img = fit_on_canvas(var_fg, target_sz, pad_x=pad_x, pad_y=pad_y)
            var_img.save(v_dir / f"{prop_id}_{v_idx}.png")


def build_armor_and_arsenal() -> dict[str, dict]:
    """
    Extracts the 3 armor tiers, 7 melee weapons, and 9 ranged weapons from SHEET_ARSENAL,
    creating distinct item icons (`88x72`) AND distinct handheld weapon overlays (`96x64`)
    so zero `reuse_of` entries are needed!
    """
    armor_dir = SPRITES / "items" / "armor"
    weapons_item_dir = SPRITES / "items" / "weapons"
    overlay_dir = SPRITES / "player" / "weapons"
    armor_dir.mkdir(parents=True, exist_ok=True)
    weapons_item_dir.mkdir(parents=True, exist_ok=True)
    overlay_dir.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_ARSENAL).convert("RGBA")
    sw, sh = sheet.size

    # 1. Row 0: 3 Armor Tiers (Scavenger Vest, Alloy Plate Rig, Vanguard Powered Exo-Armor)
    armor_boxes = [
        (10, 10, int(sw * 0.20), int(sh * 0.33)),
        (int(sw * 0.20), 10, int(sw * 0.38), int(sh * 0.33)),
        (int(sw * 0.38), 10, int(sw * 0.64), int(sh * 0.33)),
    ]
    armor_fgs = [strip_dark_slate_bg(sheet.crop(b), 24) for b in armor_boxes]

    armor_files = [
        ("初階.png", armor_fgs[0], 1.0, 1.0),
        ("中階.png", armor_fgs[1], 1.0, 1.0),
        ("高階.png", armor_fgs[2], 1.0, 1.0),
        ("初階2.png", armor_fgs[0], 1.08, 1.12),
        ("中階2.png", armor_fgs[1], 1.08, 1.12),
        ("高階2.png", armor_fgs[2], 1.08, 1.12),
    ]
    for fname, fg, bf, cf in armor_files:
        mod_fg = ImageEnhance.Brightness(fg).enhance(bf)
        mod_fg = ImageEnhance.Contrast(mod_fg).enhance(cf)
        if fname.endswith("2.png"):
            # Subtle warm tactical trim tint on Mk.II armors so they are visually distinct
            px = mod_fg.load()
            for y in range(mod_fg.height):
                for x in range(mod_fg.width):
                    r, g, b, a = px[x, y]
                    if a > 0:
                        px[x, y] = (min(255, int(r * 1.06)), g, max(0, int(b * 0.94)), a)
        icon = fit_on_canvas(mod_fg, (128, 128), pad_x=8, pad_y=8, ground_shadow=False, align_bottom=False)
        icon.save(armor_dir / fname)

    # 2. Row 1: 7 Melee Weapons (Knife, Machete, Sword, Axe, Hammer, Spear, Chainsaw)
    m_y0, m_y1 = int(sh * 0.33), int(sh * 0.62)
    melee_x_splits = [0.0, 0.135, 0.268, 0.412, 0.545, 0.688, 0.835, 1.0]
    melee_ids = ["knife", "machete", "sword", "axe", "hammer", "spear", "chainsaw"]
    melee_fgs: dict[str, Image.Image] = {}
    for idx, mid in enumerate(melee_ids):
        x0 = int(sw * melee_x_splits[idx]) + 4
        x1 = int(sw * melee_x_splits[idx + 1]) - 4
        melee_fgs[mid] = strip_dark_slate_bg(sheet.crop((x0, m_y0, x1, m_y1)), 24)

    # 3. Row 2: 4 Ranged Weapons (Pistol, Revolver, SMG, Assault Rifle)
    r2_y0, r2_y1 = int(sh * 0.63), int(sh * 0.80)
    r2_splits = [
        ("pistol", 0.0, 0.125),
        ("revolver", 0.125, 0.27),
        ("smg", 0.27, 0.46),
        ("rifle", 0.46, 0.72),
    ]
    ranged_fgs: dict[str, Image.Image] = {}
    for rid, rx0, rx1 in r2_splits:
        ranged_fgs[rid] = strip_dark_slate_bg(sheet.crop((int(sw * rx0) + 4, r2_y0, int(sw * rx1) - 4, r2_y1)), 24)

    # 4. Row 3: 5 Ranged Weapons (Shotgun, Sniper, Crossbow, Energy Weapon, Explosive Launcher)
    r3_y0, r3_y1 = int(sh * 0.80), sh - 6
    r3_splits = [
        ("shotgun", 0.0, 0.235),
        ("sniper", 0.235, 0.48),
        ("crossbow", 0.48, 0.62),
        ("energy", 0.62, 0.815),
        ("explosive", 0.815, 1.0),
    ]
    for rid, rx0, rx1 in r3_splits:
        y_top = int(sh * 0.68) if rid == "explosive" else r3_y0
        ranged_fgs[rid] = strip_dark_slate_bg(sheet.crop((int(sw * rx0) + 4, y_top, int(sw * rx1) - 4, r3_y1)), 24)

    def save_weapon_pair(weapon_id: str, fg: Image.Image) -> tuple[str, str]:
        # 1. Item Icon (88x72 RGBA with subtle item rack shadow)
        item_icon = fit_on_canvas(fg, (88, 72), pad_x=6, pad_y=6, ground_shadow=True, align_bottom=False)
        item_rel = f"res://assets/sprites/items/weapons/{weapon_id}_icon.png"
        item_icon.save(weapons_item_dir / f"{weapon_id}_icon.png")

        # 2. Handheld Weapon Overlay (96x64 RGBA, no ground shadow, shifted right for hand grip anchor)
        overlay = Image.new("RGBA", (96, 64), (0, 0, 0, 0))
        bbox = fg.getbbox()
        cropped = fg.crop(bbox) if bbox else fg
        scale = min(74.0 / max(1, cropped.width), 48.0 / max(1, cropped.height))
        nw = max(28, int(round(cropped.width * scale)))
        nh = max(18, int(round(cropped.height * scale)))
        resized = cropped.resize((nw, nh), Image.Resampling.LANCZOS)
        overlay.alpha_composite(resized, (14, (64 - nh) // 2))
        overlay_rel = f"res://assets/sprites/player/weapons/{weapon_id}_overlay.png"
        overlay.save(overlay_dir / f"{weapon_id}_overlay.png")
        return item_rel, overlay_rel

    # Map existing 6 weapons + 2 tools to distinct extracted sprites
    core_weapon_map = {
        "rust_blade": melee_fgs["knife"],
        "spark_cutter": melee_fgs["machete"],
        "breaker_hammer": melee_fgs["hammer"],
        "pipe_rifle": ranged_fgs["rifle"],
        "coil_launcher": ranged_fgs["sniper"],
        "acid_sprayer": ranged_fgs["energy"],
        "recycler_glove": melee_fgs["chainsaw"],
        "magnet_breaker": melee_fgs["spear"],
    }
    for wid, fg in core_weapon_map.items():
        save_weapon_pair(wid, fg)

    # Save all additional expanded weapon archetypes (not already mapped in core_weapon_map)
    extra_entries: dict[str, dict] = {}
    new_archetypes = {
        "melee_sword": melee_fgs["sword"],
        "melee_axe": melee_fgs["axe"],
        "ranged_pistol": ranged_fgs["pistol"],
        "ranged_revolver": ranged_fgs["revolver"],
        "ranged_smg": ranged_fgs["smg"],
        "ranged_shotgun": ranged_fgs["shotgun"],
        "ranged_crossbow": ranged_fgs["crossbow"],
        "ranged_explosive": ranged_fgs["explosive"],
    }
    for arch_id, fg in new_archetypes.items():
        item_rel, overlay_rel = save_weapon_pair(arch_id, fg)
        extra_entries[f"item_{arch_id}"] = {
            "type": "equipment",
            "path": item_rel,
            "size": [88, 72],
            "map_marker": "pickup",
            "asset_id": f"item_{arch_id}",
            "usage_id": f"item_{arch_id}",
            "unique_required": True,
            "minimap_marker": "pickup",
            "source_ref": "imagegen_wasteland_arsenal_sheet",
        }
        extra_entries[f"player_weapon_{arch_id}"] = {
            "asset_id": f"player_weapon_{arch_id}",
            "usage_id": f"player_weapon_{arch_id}",
            "type": "weapon_overlay",
            "path": overlay_rel,
            "size": [96, 64],
            "source_ref": "imagegen_wasteland_arsenal_sheet",
            "unique_required": True,
            "minimap_marker": "none",
        }
    return extra_entries


def build_seamless_ground_tiles() -> None:
    """
    Rebuilds `village_ground_variants_2p5d.png` (512x128), `wasteland_ground_variants_2p5d.png` (512x128),
    `yuchan_wasteland_tiles.png` (384x256), and `baked/terrain.png` (192x32) with clean, dithered
    2.5D pixel-art terrain textures (removing the white square and gray circles!).
    """
    t_dir = SPRITES / "tiles"
    b_dir = SPRITES / "baked"
    t_dir.mkdir(parents=True, exist_ok=True)
    b_dir.mkdir(parents=True, exist_ok=True)

    def make_tile(w: int, h: int, base_rgb: tuple[int, int, int], accent_rgb: tuple[int, int, int], crack_rgb: tuple[int, int, int], seed_val: int) -> Image.Image:
        img = Image.new("RGBA", (w, h), (*base_rgb, 255))
        px = img.load()
        for y in range(h):
            for x in range(w):
                # Deterministic pixel hash for organic wasteland grit & pebble dithering
                hval = ((x * 374761393) + (y * 668265263) + seed_val * 1442695041) & 0xFFFFFFFF
                if hval % 11 == 0:
                    px[x, y] = (*accent_rgb, 255)
                elif hval % 19 == 0:
                    px[x, y] = (*crack_rgb, 255)
                elif (x + y) % 4 == 0 and (hval % 5 == 0):
                    px[x, y] = (max(0, base_rgb[0] - 8), max(0, base_rgb[1] - 8), max(0, base_rgb[2] - 8), 255)
        draw = ImageDraw.Draw(img, "RGBA")
        # Subtle 2.5D flagstone / road seam lines
        for idx in range(3):
            sx = (seed_val * 17 + idx * 37) % (w - 24) + 8
            sy = (seed_val * 29 + idx * 41) % (h - 16) + 6
            draw.line([(sx, sy), (sx + 14, sy + 3)], fill=(*crack_rgb, 210), width=1)
            draw.line([(sx, sy - 1), (sx + 12, sy + 2)], fill=(*accent_rgb, 180), width=1)
        return img

    # 1. village_ground_variants_2p5d.png (512x128 = 4 tiles of 128x128)
    v_palettes = [
        ((76, 68, 58), (94, 84, 72), (54, 48, 40)),
        ((82, 74, 62), (102, 92, 78), (58, 52, 44)),
        ((70, 66, 62), (88, 84, 78), (48, 44, 42)),
        ((64, 74, 56), (82, 94, 72), (44, 52, 38)),
    ]
    v_sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for i, (b_col, a_col, c_col) in enumerate(v_palettes):
        v_sheet.alpha_composite(make_tile(128, 128, b_col, a_col, c_col, 100 + i), (i * 128, 0))
    v_sheet.save(t_dir / "village_ground_variants_2p5d.png")

    # 2. wasteland_ground_variants_2p5d.png (512x128 = 4 tiles of 128x128)
    w_palettes = [
        ((68, 56, 46), (88, 72, 58), (46, 36, 28)),     # Ashen Highway
        ((46, 64, 52), (64, 92, 70), (30, 44, 34)),     # Toxic Marsh
        ((58, 50, 68), (82, 68, 96), (38, 32, 46)),     # Crystal Scar
        ((54, 58, 64), (74, 80, 88), (36, 38, 44)),     # Old Factory / Metropolis
    ]
    w_sheet = Image.new("RGBA", (512, 128), (0, 0, 0, 0))
    for i, (b_col, a_col, c_col) in enumerate(w_palettes):
        w_sheet.alpha_composite(make_tile(128, 128, b_col, a_col, c_col, 200 + i), (i * 128, 0))
    w_sheet.save(t_dir / "wasteland_ground_variants_2p5d.png")

    # 3. yuchan_wasteland_tiles.png (384x256 = 6x4 grid of 64x64 tiles)
    y_sheet = Image.new("RGBA", (384, 256), (0, 0, 0, 0))
    all_pals = v_palettes + w_palettes
    for ry in range(4):
        for rx in range(6):
            b_col, a_col, c_col = all_pals[(ry * 6 + rx) % len(all_pals)]
            y_sheet.alpha_composite(make_tile(64, 64, b_col, a_col, c_col, 300 + ry * 6 + rx), (rx * 64, ry * 64))
    y_sheet.save(t_dir / "yuchan_wasteland_tiles.png")

    # 4. baked/terrain.png (192x32 = 6 tiles of 32x32)
    b_terrain = Image.new("RGBA", (192, 32), (0, 0, 0, 0))
    for i in range(6):
        b_col, a_col, c_col = all_pals[i % len(all_pals)]
        b_terrain.alpha_composite(make_tile(32, 32, b_col, a_col, c_col, 400 + i), (i * 32, 0))
    b_terrain.save(b_dir / "terrain.png")


def update_visual_assets_manifest(extra_weapon_entries: dict[str, dict]) -> None:
    manifest_path = ROOT / "data" / "art" / "visual_assets.json"
    data = json.loads(manifest_path.read_text(encoding="utf-8"))
    assets: dict[str, dict] = data.get("assets", {})

    # Point item_* equipment entries to their dedicated item icon paths and remove `reuse_of`!
    dedicated_item_paths = {
        "item_rust_blade": "res://assets/sprites/items/weapons/rust_blade_icon.png",
        "item_spark_cutter": "res://assets/sprites/items/weapons/spark_cutter_icon.png",
        "item_breaker_hammer": "res://assets/sprites/items/weapons/breaker_hammer_icon.png",
        "item_pipe_rifle": "res://assets/sprites/items/weapons/pipe_rifle_icon.png",
        "item_coil_launcher": "res://assets/sprites/items/weapons/coil_launcher_icon.png",
        "item_acid_sprayer": "res://assets/sprites/items/weapons/acid_sprayer_icon.png",
        "item_recycler_glove": "res://assets/sprites/items/weapons/recycler_glove_icon.png",
        "item_magnet_breaker": "res://assets/sprites/items/weapons/magnet_breaker_icon.png",
    }
    for item_key, new_path in dedicated_item_paths.items():
        if item_key in assets:
            assets[item_key]["path"] = new_path
            assets[item_key]["unique_required"] = True
            assets[item_key].pop("reuse_of", None)

    for overlay_key in ("player_weapon_spark_cutter", "player_weapon_acid_sprayer", "player_tool_magnet_breaker"):
        if overlay_key in assets:
            assets[overlay_key]["unique_required"] = True
            assets[overlay_key].pop("reuse_of", None)

    # Remove any stale duplicate archetype keys before merging
    for stale_key in list(assets.keys()):
        if stale_key.startswith(("item_melee_", "item_ranged_", "player_weapon_melee_", "player_weapon_ranged_")):
            assets.pop(stale_key, None)

    # Merge expanded weapon entries
    for k, v in extra_weapon_entries.items():
        assets[k] = v

    # Refresh any `source_sha256` and `source_dimensions` fields so they match disk 100%
    for asset_id, entry in assets.items():
        rel = str(entry.get("path", "")).replace("res://", "", 1)
        disk_path = ROOT / rel
        if disk_path.is_file() and ("source_sha256" in entry or "source_dimensions" in entry):
            raw = disk_path.read_bytes()
            im = Image.open(disk_path)
            entry["source_sha256"] = hashlib.sha256(raw).hexdigest()
            entry["source_dimensions"] = [im.width, im.height]

    data["assets"] = assets
    manifest_path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main() -> None:
    import build_2p5d_terrain_tilesets
    import build_r17_vanguard_8dir_atlas

    build_structures_and_gates()
    build_npcs_and_portraits()
    build_enemies_and_boss()
    build_props_and_variants()
    extra_weapons = build_armor_and_arsenal()
    build_r17_vanguard_8dir_atlas.normalize_weapon_overlays()
    build_2p5d_terrain_tilesets.main()
    update_visual_assets_manifest(extra_weapons)
    print("[OVERHAUL] All structures, NPCs, enemies, props, armors, weapons, tiles, and manifest updated.")


if __name__ == "__main__":
    main()
