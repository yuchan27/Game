"""
Builds environmental-fused versions of all wasteland structures and gates.
Structures are rendered with:
- 2.5D integrated foundation skid / reinforced concrete-steel apron
- Industrial cable conduits, grounding clamps, and bolts
- Machine-specific ground emissions (forge ember spill, beacon cyan pulse, grease stains)
- Multi-tier ambient occlusion and soft dithered gravel berms for seamless terrain fusion
"""

from pathlib import Path
import math
from PIL import Image, ImageDraw, ImageFilter

ARTIFACT_DIR = Path(r"C:\Users\wuwu6\.gemini\antigravity\brain\570862f6-1da4-487f-9851-ea917a94a8d1")
GAME_ROOT = Path(r"C:\Code\Game\first-game")
SPRITES = GAME_ROOT / "assets" / "sprites"
SHEET_STRUCTURES = ARTIFACT_DIR / "wasteland_camp_structures_sheet_1792552134539.jpg"
SHEET_GATES_PROPS = ARTIFACT_DIR / "wasteland_gates_props_1792552492223.jpg"

def strip_dark_slate_bg(im: Image.Image, tolerance: int = 24) -> Image.Image:
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    samples = [
        px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1],
        px[w // 2, 0], px[w // 2, h - 1], px[0, h // 2], px[w - 1, h // 2]
    ]
    bg_r = sum(s[0] for s in samples) // len(samples)
    bg_g = sum(s[1] for s in samples) // len(samples)
    bg_b = sum(s[2] for s in samples) // len(samples)

    def is_bg(r: int, g: int, b: int, a: int) -> bool:
        if a < 24:
            return True
        return (abs(r - bg_r) + abs(g - bg_g) + abs(b - bg_b)) <= tolerance

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
            r, g, b, _ = px[x, y]
            opx[x, y] = (r, g, b, 255)
            if x < min_x: min_x = x
            if y < min_y: min_y = y
            if x > max_x: max_x = x
            if y > max_y: max_y = y

    if max_x < min_x or max_y < min_y:
        return Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    return out.crop((min_x, min_y, max_x + 1, max_y + 1))


def draw_fused_foundation(
    canvas: Image.Image,
    base_center: tuple[int, int],
    base_width: int,
    base_height: int,
    structure_kind: str
) -> None:
    """Draws a rich 2.5D foundation slab, cables, ground stains, and ambient occlusion."""
    draw = ImageDraw.Draw(canvas, "RGBA")
    cx, cy = base_center
    hw = base_width // 2
    hh = base_height // 2

    # 1. Soft ambient occlusion outer halo
    ao_w = int(hw * 1.35)
    ao_h = int(hh * 1.30)
    for r in range(12, 0, -2):
        alpha = int(45 * (1.0 - r / 12.0))
        draw.ellipse([cx - ao_w - r, cy - ao_h - r // 2, cx + ao_w + r, cy + ao_h + r // 2], fill=(10, 8, 14, alpha))

    # 2. Dirt & gravel berm (dithered soil perimeter)
    soil_w = int(hw * 1.18)
    soil_h = int(hh * 1.15)
    draw.ellipse([cx - soil_w, cy - soil_h, cx + soil_w, cy + soil_h], fill=(48, 40, 32, 160))

    # Soil gravel grain texture
    import random
    rng = random.Random(hash(structure_kind) & 0xffff)
    for _ in range(80):
        gx = cx + rng.randint(-soil_w, soil_w)
        gy = cy + rng.randint(-soil_h, soil_h)
        if ((gx - cx) / soil_w)**2 + ((gy - cy) / soil_h)**2 <= 1.0:
            gc = rng.choice([(60, 50, 40, 180), (32, 26, 20, 190), (75, 65, 52, 170)])
            draw.point((gx, gy), fill=gc)

    # 3. 2.5D Foundation Skid / Concrete Apron
    # An isometric octagonal plate
    slab_w = int(hw * 1.05)
    slab_h = int(hh * 0.95)
    plate_poly = [
        (cx - slab_w + 14, cy - slab_h),
        (cx + slab_w - 14, cy - slab_h),
        (cx + slab_w, cy - slab_h + 8),
        (cx + slab_w, cy + slab_h - 8),
        (cx + slab_w - 14, cy + slab_h),
        (cx - slab_w + 14, cy + slab_h),
        (cx - slab_w, cy + slab_h - 8),
        (cx - slab_w, cy - slab_h + 8),
    ]
    # Foundation base plate color
    draw.polygon(plate_poly, fill=(38, 42, 48, 240), outline=(22, 24, 28, 255))

    # Inner bevel rim highlight
    inner_poly = [
        (p[0] + (1 if p[0] > cx else -1), p[1] + (1 if p[1] > cy else -1))
        for p in plate_poly
    ]
    draw.polygon(inner_poly, outline=(62, 68, 76, 200))

    # Corner anchor bolts / rivets
    bolt_coords = [
        (cx - slab_w + 16, cy - slab_h + 6),
        (cx + slab_w - 16, cy - slab_h + 6),
        (cx - slab_w + 16, cy + slab_h - 6),
        (cx + slab_w - 16, cy + slab_h - 6),
        (cx, cy + slab_h - 4),
        (cx, cy - slab_h + 4),
    ]
    for bx, by in bolt_coords:
        draw.ellipse([bx - 2, by - 2, bx + 2, by + 2], fill=(120, 110, 95, 255), outline=(18, 16, 20, 255))
        draw.point((bx, by - 1), fill=(190, 180, 160, 255))

    # 4. Structure-specific ground decals & conduits
    if structure_kind == "forge":
        # Radiant ember glow spilling in front of the furnace door
        ember_center = (cx + 8, cy + 4)
        for er in range(24, 0, -3):
            ea = int(140 * (1.0 - er / 24.0))
            draw.ellipse([ember_center[0] - er * 2, ember_center[1] - er, ember_center[0] + er * 2, ember_center[1] + er],
                         fill=(255, 95, 20, ea))
        # Dropped slag / coal fragments
        for _ in range(15):
            sx = ember_center[0] + rng.randint(-30, 30)
            sy = ember_center[1] + rng.randint(-8, 14)
            draw.point((sx, sy), fill=(255, 200, 60, 220))
            draw.point((sx + 1, sy), fill=(40, 25, 20, 240))

    elif structure_kind == "mod_station":
        # Cyan calibration circuit grid on the ground
        for cr in range(20, 0, -3):
            ca = int(110 * (1.0 - cr / 20.0))
            draw.ellipse([cx - cr * 2, cy - cr // 2, cx + cr * 2, cy + cr // 2], fill=(35, 210, 230, ca))
        # Ground conduit cables running outward
        draw.line([(cx - slab_w + 4, cy + 2), (cx - slab_w - 24, cy + 18)], fill=(28, 30, 36, 255), width=3)
        draw.line([(cx - slab_w + 4, cy + 6), (cx - slab_w - 20, cy + 26)], fill=(22, 90, 105, 255), width=2)
        draw.line([(cx + slab_w - 4, cy + 4), (cx + slab_w + 22, cy + 22)], fill=(28, 30, 36, 255), width=3)

    elif structure_kind == "save_station":
        # Cyan beacon pulse ring on ground
        for cr in range(28, 0, -4):
            ca = int(120 * (1.0 - cr / 28.0))
            draw.ellipse([cx - cr * 1.5, cy - cr * 0.75, cx + cr * 1.5, cy + cr * 0.75], fill=(50, 225, 240, ca))
        # Ground anchor stays / guy wires
        draw.line([(cx - slab_w + 10, cy - slab_h + 8), (cx - slab_w - 18, cy + 16)], fill=(70, 75, 82, 255), width=2)
        draw.line([(cx + slab_w - 10, cy - slab_h + 8), (cx + slab_w + 18, cy + 16)], fill=(70, 75, 82, 255), width=2)

    elif structure_kind == "recycle_machine":
        # Scrap bin rust & black grease stain puddle
        stain_w = int(hw * 0.8)
        stain_h = int(hh * 0.7)
        draw.ellipse([cx - stain_w, cy - stain_h + 4, cx + stain_w, cy + stain_h + 4], fill=(18, 14, 12, 180))
        # Crushed scrap fragments
        for _ in range(22):
            fx = cx + rng.randint(-stain_w + 4, stain_w - 4)
            fy = cy + rng.randint(-stain_h + 4, stain_h + 6)
            draw.point((fx, fy), fill=rng.choice([(140, 90, 45, 255), (90, 95, 105, 255), (180, 140, 70, 255)]))

    elif structure_kind == "craft":
        # Blueprint workbench conduit and metallic filings
        draw.line([(cx - slab_w + 6, cy + 4), (cx - slab_w - 22, cy + 14)], fill=(32, 34, 40, 255), width=3)
        draw.line([(cx + slab_w - 6, cy + 6), (cx + slab_w + 24, cy + 12)], fill=(32, 34, 40, 255), width=3)
        for _ in range(16):
            draw.point((cx + rng.randint(-24, 24), cy + rng.randint(-6, 8)), fill=(160, 180, 200, 200))

    elif structure_kind == "shop":
        # Trader rolled tarp mat under the stall
        tarp_w = int(hw * 0.95)
        tarp_h = int(hh * 0.80)
        draw.polygon([
            (cx - tarp_w, cy - tarp_h + 4),
            (cx + tarp_w, cy - tarp_h + 4),
            (cx + tarp_w - 8, cy + tarp_h),
            (cx - tarp_w + 8, cy + tarp_h),
        ], fill=(95, 75, 45, 210), outline=(50, 40, 25, 255))
        # Fringes and stitches
        for tx in range(cx - tarp_w + 10, cx + tarp_w - 10, 4):
            draw.point((tx, cy + tarp_h - 1), fill=(160, 130, 80, 255))

    elif "gate" in structure_kind:
        # Checkpoint hazard yellow/black stripes on threshold apron
        apron_w = int(hw * 0.9)
        draw.rectangle([cx - apron_w, cy - 6, cx + apron_w, cy + 6], fill=(42, 44, 48, 255), outline=(20, 22, 26, 255))
        for sx in range(cx - apron_w + 4, cx + apron_w - 4, 12):
            draw.polygon([(sx, cy + 5), (sx + 5, cy + 5), (sx + 8, cy - 5), (sx + 3, cy - 5)], fill=(215, 175, 40, 230))
        # Heavy perimeter security floodlight conduits
        draw.line([(cx - apron_w, cy), (cx - apron_w - 20, cy + 14)], fill=(30, 32, 36, 255), width=3)
        draw.line([(cx + apron_w, cy), (cx + apron_w + 20, cy + 14)], fill=(30, 32, 36, 255), width=3)

    # 5. Deep contact ambient occlusion core immediately under the machine base
    core_w = int(hw * 0.88)
    core_h = int(hh * 0.65)
    draw.ellipse([cx - core_w, cy - core_h, cx + core_w, cy + core_h], fill=(8, 6, 10, 185))


def build_fused_structures_and_gates() -> None:
    s_dir = SPRITES / "structures"
    s_dir.mkdir(parents=True, exist_ok=True)

    sheet = Image.open(SHEET_STRUCTURES).convert("RGBA")
    sw, sh = sheet.size
    col_w = sw // 3
    row_h = sh // 2

    # Canvas sizes with extra bottom & horizontal padding for the fused foundation & conduits
    struct_specs = [
        ("forge.png", (0, 0), (220, 170), "forge"),
        ("craft.png", (1, 0), (208, 160), "craft"),
        ("shop.png", (2, 0), (214, 154), "shop"),
        ("mod_station.png", (0, 1), (224, 168), "mod_station"),
        ("recycle_machine.png", (1, 1), (214, 154), "recycle_machine"),
        ("save_station.png", (2, 1), (198, 154), "save_station"),
    ]

    for filename, (col, row), (cw, ch), kind in struct_specs:
        cell = sheet.crop((col * col_w + 12, row * row_h + 12, (col + 1) * col_w - 12, (row + 1) * row_h - 12))
        fg = strip_dark_slate_bg(cell, tolerance=24)
        bbox = fg.getbbox()
        if bbox:
            fg = fg.crop(bbox)

        # Scale foreground machine
        avail_w = cw - 36
        avail_h = ch - 42
        scale = min(avail_w / max(1, fg.width), avail_h / max(1, fg.height))
        nw = max(1, int(round(fg.width * scale)))
        nh = max(1, int(round(fg.height * scale)))
        resized = fg.resize((nw, nh), Image.Resampling.LANCZOS)

        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cx = cw // 2
        # Position machine so its bottom aligns nicely on the foundation plate
        machine_y = ch - 22 - nh
        machine_x = cx - nw // 2

        # Draw fused foundation BEFORE drawing the machine
        foundation_center = (cx, ch - 20)
        foundation_w = int(nw * 0.95)
        foundation_h = max(18, int(nh * 0.22))
        draw_fused_foundation(canvas, foundation_center, foundation_w, foundation_h, kind)

        # Composite the machine
        canvas.alpha_composite(resized, (machine_x, machine_y))

        # Bottom skirt ground integration: blend bottom 3-4 px of the machine into the foundation
        # with dithered contact grime so the machine doesn't have a razor-sharp lower edge
        cdraw = ImageDraw.Draw(canvas, "RGBA")
        skirt_y = machine_y + nh - 3
        for x in range(machine_x, machine_x + nw):
            if canvas.getpixel((x, skirt_y))[3] > 120:
                # Add subtle dirt flecks and contact shading
                if (x % 3) == 0:
                    cdraw.point((x, skirt_y), fill=(30, 26, 22, 220))
                if (x % 5) == 0:
                    cdraw.point((x, skirt_y + 1), fill=(44, 38, 30, 180))

        canvas.save(s_dir / filename)
        print(f"[FUSED_STRUCT] saved {filename} ({cw}x{ch})")

    # Now gates
    gp_sheet = Image.open(SHEET_GATES_PROPS).convert("RGBA")
    gw, gh = gp_sheet.size
    g_col_w = gw // 4
    g_row_h = gh // 3

    gate_specs = [
        ("guild_gate.png", 0, (220, 150), "guild_gate"),
        ("wasteland_gate.png", 1, (214, 150), "wasteland_gate"),
        ("route_gate.png", 2, (214, 150), "route_gate"),
        ("village_return_gate.png", 3, (214, 150), "village_return_gate"),
    ]

    for filename, col, (cw, ch), kind in gate_specs:
        cell = gp_sheet.crop((col * g_col_w + 8, 8, (col + 1) * g_col_w - 8, g_row_h - 8))
        fg = strip_dark_slate_bg(cell, tolerance=24)
        bbox = fg.getbbox()
        if bbox:
            fg = fg.crop(bbox)

        avail_w = cw - 32
        avail_h = ch - 38
        scale = min(avail_w / max(1, fg.width), avail_h / max(1, fg.height))
        nw = max(1, int(round(fg.width * scale)))
        nh = max(1, int(round(fg.height * scale)))
        resized = fg.resize((nw, nh), Image.Resampling.LANCZOS)

        canvas = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
        cx = cw // 2
        machine_y = ch - 18 - nh
        machine_x = cx - nw // 2

        foundation_center = (cx, ch - 16)
        foundation_w = int(nw * 0.96)
        foundation_h = max(16, int(nh * 0.20))
        draw_fused_foundation(canvas, foundation_center, foundation_w, foundation_h, kind)

        canvas.alpha_composite(resized, (machine_x, machine_y))
        canvas.save(s_dir / filename)
        if filename == "village_return_gate.png":
            canvas.save(s_dir / "return_gate.png")
        print(f"[FUSED_STRUCT] saved {filename} ({cw}x{ch})")

if __name__ == "__main__":
    build_fused_structures_and_gates()
