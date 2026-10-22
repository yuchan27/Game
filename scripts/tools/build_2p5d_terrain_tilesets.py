from __future__ import annotations

"""
Builds cohesive, fine-grained 2.5D dark wasteland terrain tilesets inspired by
`參考圖片.png` (地圖瓦片 - 荒野廢土風) and `wasteland_recycler_terrain_tileset_1792555376925.jpg`.

Key fixes over previous tileset:
1. Eliminates oversized bright-orange bricks (`cobble_plaza` was previously 50px-wide orange bricks).
2. Matches the dark wasteland soil, weathered asphalt road, stone curb shoulder, and bolted scrap-steel
   station pads from `參考圖片.png` at true 32x32 tile scale so character feet (R-17 & NPCs) feel
   grounded and proportional to the floor texture.
3. Aligns every tile seam to the 32x32 grid so `VillageTileMap.gd` and `WorldBackdrop.gd` never produce
   broken cutoffs.
"""

import math
import random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageEnhance

ROOT = Path(__file__).resolve().parents[2]
TILES_DIR = ROOT / "assets" / "sprites" / "tiles"
BAKED_DIR = ROOT / "assets" / "sprites" / "baked"
ARTIFACT_DIR = Path(r"C:\Users\wuwu6\.gemini\antigravity\brain\570862f6-1da4-487f-9851-ea917a94a8d1")
SRC_SHEET = ARTIFACT_DIR / "wasteland_recycler_terrain_tileset_1792555376925.jpg"
REF_SHEET = ROOT / "參考圖片.png"


def make_seamless_128(crop_img: Image.Image, tile_subdiv: int = 1) -> Image.Image:
    """
    Resizes swatch to (128 // tile_subdiv) and tiles it to 128x128 so the grain size
    is fine and proportional to 32x32 tiles, with seamless wrap blending.
    """
    sub = max(1, tile_subdiv)
    cell_sz = 128 // sub
    base_small = crop_img.convert("RGBA").resize((cell_sz, cell_sz), Image.Resampling.LANCZOS)
    px = base_small.load()
    out_small = base_small.copy()
    opx = out_small.load()
    margin = max(4, cell_sz // 8)
    for y in range(cell_sz):
        for x in range(cell_sz):
            r, g, b, _ = px[x, y]
            if x < margin:
                t = (margin - x) / (margin * 2.0)
                wr, wg, wb, _ = px[(x + cell_sz // 2) % cell_sz, y]
                r = int(r * (1.0 - t) + wr * t)
                g = int(g * (1.0 - t) + wg * t)
                b = int(b * (1.0 - t) + wb * t)
            elif x >= cell_sz - margin:
                t = (x - (cell_sz - margin) + 1) / (margin * 2.0)
                wr, wg, wb, _ = px[(x + cell_sz // 2) % cell_sz, y]
                r = int(r * (1.0 - t) + wr * t)
                g = int(g * (1.0 - t) + wg * t)
                b = int(b * (1.0 - t) + wb * t)
            if y < margin:
                t = (margin - y) / (margin * 2.0)
                wr, wg, wb, _ = opx[x, (y + cell_sz // 2) % cell_sz]
                r = int(r * (1.0 - t) + wr * t)
                g = int(g * (1.0 - t) + wg * t)
                b = int(b * (1.0 - t) + wb * t)
            elif y >= cell_sz - margin:
                t = (y - (cell_sz - margin) + 1) / (margin * 2.0)
                wr, wg, wb, _ = opx[x, (y + cell_sz // 2) % cell_sz]
                r = int(r * (1.0 - t) + wr * t)
                g = int(g * (1.0 - t) + wg * t)
                b = int(b * (1.0 - t) + wb * t)
            opx[x, y] = (r, g, b, 255)

    full = Image.new("RGBA", (128, 128), (0, 0, 0, 255))
    for ty in range(sub):
        for tx in range(sub):
            variant = out_small
            if (tx + ty) % 2 == 1:
                variant = ImageEnhance.Brightness(out_small).enhance(0.96)
            full.paste(variant, (tx * cell_sz, ty * cell_sz))
    return full


def grade_to_palette(
    img: Image.Image,
    target_rgb: tuple[float, float, float],
    mix: float = 0.45,
    contrast: float = 0.82,
    brightness: float = 0.78,
) -> Image.Image:
    """Grades a 128x128 tile block into the cohesive dark wasteland palette."""
    im = ImageEnhance.Contrast(img).enhance(contrast)
    im = ImageEnhance.Brightness(im).enhance(brightness)
    arr = np.array(im, dtype=np.float32)
    tr, tg, tb = target_rgb
    arr[:, :, 0] = np.clip(arr[:, :, 0] * (1.0 - mix) + tr * mix, 0, 255)
    arr[:, :, 1] = np.clip(arr[:, :, 1] * (1.0 - mix) + tg * mix, 0, 255)
    arr[:, :, 2] = np.clip(arr[:, :, 2] * (1.0 - mix) + tb * mix, 0, 255)
    arr[:, :, 3] = 255
    return Image.fromarray(arr.astype(np.uint8), mode="RGBA")


def build_wasteland_soil_block(base_dirt: Image.Image, seed_val: int, darker: bool = False) -> Image.Image:
    """
    Creates fine-grained dark wasteland earth & gravel (matching `參考圖片.png` 地圖瓦片)
    with subtle pebbles, micro-cracks, and muted scrub tufts.
    """
    target = (46.0, 40.0, 34.0) if darker else (58.0, 50.0, 42.0)
    blk = grade_to_palette(base_dirt, target, mix=0.52, contrast=0.76, brightness=0.68 if darker else 0.76)
    draw = ImageDraw.Draw(blk, "RGBA")
    rng = random.Random(seed_val)

    # Fine gravel speckles & tiny dark cracks
    for _ in range(95):
        x = rng.randint(2, 125)
        y = rng.randint(2, 125)
        w = rng.randint(1, 3)
        h = rng.randint(1, 2)
        if rng.random() < 0.55:
            draw.ellipse((x, y, x + w, y + h), fill=(32, 27, 22, 135))
        else:
            draw.ellipse((x, y, x + w, y + h), fill=(84, 73, 60, 110))

    # Subtle weathered soil cracks
    for _ in range(8):
        x0 = rng.randint(6, 116)
        y0 = rng.randint(6, 116)
        x1 = x0 + rng.randint(-10, 10)
        y1 = y0 + rng.randint(-6, 6)
        draw.line([(x0, y0), (x1, y1)], fill=(26, 22, 18, 125), width=1)

    # Tiny dry wasteland moss/scrub tufts (2-3px) like in 參考圖片.png
    for _ in range(6 if darker else 4):
        tx = rng.randint(8, 120)
        ty = rng.randint(8, 120)
        draw.point((tx, ty), fill=(62, 78, 48, 165))
        draw.point((tx + 1, ty), fill=(48, 64, 38, 165))
        draw.point((tx, ty - 1), fill=(76, 92, 56, 145))

    return blk


def build_wasteland_road_block(base_asphalt: Image.Image, with_markings: bool = True) -> Image.Image:
    """
    Creates the weathered dark slate/asphalt road with subtle 32x32 stone-slab seams,
    cracked patches, and worn amber-yellow road markings matching `參考圖片.png`.
    """
    blk = grade_to_palette(base_asphalt, (54.0, 53.0, 56.0), mix=0.55, contrast=0.75, brightness=0.72)
    draw = ImageDraw.Draw(blk, "RGBA")
    rng = random.Random(409)

    # Subtle 32x32 dark weathered slab grid so road feels structured & proportional
    for g in (0, 32, 64, 96):
        draw.line([(g, 0), (g, 127)], fill=(34, 33, 36, 95), width=1)
        draw.line([(0, g), (127, g)], fill=(34, 33, 36, 95), width=1)
        draw.line([(g + 1, 0), (g + 1, 127)], fill=(74, 72, 76, 55), width=1)
        draw.line([(0, g + 1), (127, g + 1)], fill=(74, 72, 76, 55), width=1)

    if with_markings:
        # Worn yellow-amber road edge/center dashes on 32px alignment
        for tile_y in range(4):
            y_mid = tile_y * 32 + 15
            for tile_x in range(4):
                x0 = tile_x * 32 + 6
                x1 = tile_x * 32 + 24
                draw.rectangle((x0, y_mid, x1, y_mid + 2), fill=(168, 132, 58, 92))
                draw.line([(x0 + 2, y_mid), (x1 - 2, y_mid)], fill=(196, 156, 72, 110), width=1)

    # Fine gravel & cracks over the road so it blends into the wasteland
    for _ in range(60):
        rx = rng.randint(2, 125)
        ry = rng.randint(2, 125)
        draw.point((rx, ry), fill=(36, 34, 32, 140) if rng.random() < 0.6 else (88, 82, 74, 95))

    return blk


def build_road_shoulder_block(base_dirt: Image.Image, base_asphalt: Image.Image) -> Image.Image:
    """
    Creates a transitional curb/shoulder tile block blending weathered stone curb with wasteland dirt.
    """
    dirt = build_wasteland_soil_block(base_dirt, 777, darker=False)
    road = build_wasteland_road_block(base_asphalt, with_markings=False)
    blk = Image.blend(dirt, road, 0.48)
    draw = ImageDraw.Draw(blk, "RGBA")
    rng = random.Random(778)
    # Small curb stones (16x16 grid)
    for gy in range(0, 128, 16):
        for gx in range(0, 128, 16):
            if rng.random() < 0.65:
                draw.rectangle((gx + 1, gy + 1, gx + 14, gy + 14), outline=(36, 32, 28, 90), width=1)
                draw.line([(gx + 2, gy + 2), (gx + 13, gy + 2)], fill=(86, 78, 66, 75), width=1)
    return blk


def build_scrap_plate_block(base_metal: Image.Image) -> Image.Image:
    """
    Creates 32x32 grid-aligned dark industrial steel floor plates with rivets and weathered rust
    for workshop station pads. Because every 32x32 sub-tile is a complete bolted plate,
    any rectangle of tiles in `VillageTileMap` has clean borders with zero cut-off artifacts!
    """
    blk = grade_to_palette(base_metal, (52.0, 56.0, 62.0), mix=0.58, contrast=0.74, brightness=0.70)
    draw = ImageDraw.Draw(blk, "RGBA")
    rng = random.Random(901)

    for ty in range(4):
        for tx in range(4):
            x0, y0 = tx * 32, ty * 32
            x1, y1 = x0 + 31, y0 + 31
            # Outer dark seam
            draw.rectangle((x0, y0, x1, y1), outline=(26, 28, 32, 185), width=1)
            # Inner top-left bevel highlight & bottom-right shadow
            draw.line([(x0 + 1, y0 + 1), (x1 - 1, y0 + 1)], fill=(84, 90, 98, 120), width=1)
            draw.line([(x0 + 1, y0 + 1), (x0 + 1, y1 - 1)], fill=(78, 84, 92, 100), width=1)
            draw.line([(x0 + 1, y1 - 1), (x1 - 1, y1 - 1)], fill=(32, 35, 40, 140), width=1)
            # Corner rivets
            for rx, ry in [(x0 + 4, y0 + 4), (x1 - 4, y0 + 4), (x0 + 4, y1 - 4), (x1 - 4, y1 - 4)]:
                draw.point((rx, ry), fill=(108, 114, 122, 180))
                draw.point((rx + 1, ry + 1), fill=(24, 26, 30, 180))
            # Subtle rust/oil weathering inside plate
            if rng.random() < 0.65:
                wx = x0 + rng.randint(6, 22)
                wy = y0 + rng.randint(6, 22)
                draw.ellipse((wx, wy, wx + rng.randint(4, 7), wy + rng.randint(3, 5)), fill=(68, 48, 36, 68))

    return blk


def pack_strip_512x128(blocks: list[Image.Image]) -> Image.Image:
    strip = Image.new("RGBA", (512, 128), (0, 0, 0, 255))
    for idx, blk in enumerate(blocks[:4]):
        strip.paste(blk.resize((128, 128), Image.Resampling.NEAREST), (idx * 128, 0))
    return strip


def main() -> None:
    if not SRC_SHEET.exists():
        raise FileNotFoundError(f"Missing terrain tileset sheet: {SRC_SHEET}")

    sheet = Image.open(SRC_SHEET).convert("RGBA")
    w, h = sheet.size

    # Use tile_subdiv=2 (64x64 tiled 2x2) so the texture grain is 2x finer and matches character scale!
    cells: dict[tuple[int, int], Image.Image] = {}
    for col in range(4):
        for row in range(3):
            cx1 = int(col * w / 4) + 22
            cy1 = int(row * h / 3) + 22
            cx2 = int((col + 1) * w / 4) - 22
            cy2 = int((row + 1) * h / 3) - 22
            cells[(col, row)] = make_seamless_128(sheet.crop((cx1, cy1, cx2, cy2)), tile_subdiv=2)

    raw_dirt = cells[(1, 0)]
    raw_asphalt = cells[(0, 1)]
    raw_metal = cells[(3, 0)]
    raw_toxic = cells[(1, 1)]
    raw_crystal = cells[(2, 1)]
    raw_factory = cells[(3, 1)]
    raw_bunker = cells[(0, 2)]
    raw_concrete = cells[(1, 2)]
    raw_lab = cells[(2, 2)]
    raw_ash = cells[(3, 2)]

    # Cohesive Dark Wasteland Blocks (matching 參考圖片.png)
    wasteland_dirt = build_wasteland_soil_block(raw_dirt, 101, darker=False)
    dark_soil = build_wasteland_soil_block(raw_dirt, 202, darker=True)
    wasteland_road = build_wasteland_road_block(raw_asphalt, with_markings=True)
    road_shoulder = build_road_shoulder_block(raw_dirt, raw_asphalt)
    cracked_concrete = grade_to_palette(raw_concrete, (56.0, 52.0, 48.0), mix=0.50, contrast=0.76, brightness=0.72)
    scrap_plate = build_scrap_plate_block(raw_metal)

    highway_asphalt = build_wasteland_road_block(raw_asphalt, with_markings=True)
    toxic_marsh = grade_to_palette(raw_toxic, (38.0, 68.0, 42.0), mix=0.32, contrast=0.84, brightness=0.78)
    crystal_scar = grade_to_palette(raw_crystal, (58.0, 42.0, 78.0), mix=0.32, contrast=0.84, brightness=0.78)
    factory_grate = grade_to_palette(raw_factory, (52.0, 56.0, 60.0), mix=0.42, contrast=0.80, brightness=0.74)
    guild_bunker = grade_to_palette(raw_bunker, (48.0, 52.0, 58.0), mix=0.40, contrast=0.82, brightness=0.78)
    urban_concrete = cracked_concrete
    lab_circuit = grade_to_palette(raw_lab, (38.0, 58.0, 72.0), mix=0.36, contrast=0.82, brightness=0.76)
    scorched_ash = grade_to_palette(raw_ash, (46.0, 40.0, 36.0), mix=0.45, contrast=0.78, brightness=0.72)

    TILES_DIR.mkdir(parents=True, exist_ok=True)
    BAKED_DIR.mkdir(parents=True, exist_ok=True)

    # 1. yuchan_wasteland_tiles.png (768x128: 6 blocks of 128x128 for VillageTileMap.gd)
    # 0: BLOCK_WASTELAND (wasteland_dirt)
    # 1: BLOCK_DARK_SOIL (dark_soil)
    # 2: BLOCK_ROAD (wasteland_road - dark asphalt/stone road instead of giant orange bricks!)
    # 3: BLOCK_ROAD_EDGE (road_shoulder - stone curb & gravel transition)
    # 4: BLOCK_CRACKED (cracked_concrete)
    # 5: BLOCK_SCRAP_PLATE (scrap_plate - 32x32 bolted steel pads)
    village_blocks = [wasteland_dirt, dark_soil, wasteland_road, road_shoulder, cracked_concrete, scrap_plate]
    yuchan = Image.new("RGBA", (128 * 6, 128), (0, 0, 0, 255))
    for idx, blk in enumerate(village_blocks):
        yuchan.paste(blk, (idx * 128, 0))
    yuchan.save(TILES_DIR / "yuchan_wasteland_tiles.png")

    # 2. recycler_tileset.png & baked/tiles.png (192x32 contract strip: six 32x32 tiles)
    contract_strip = Image.new("RGBA", (192, 32), (0, 0, 0, 255))
    for idx, blk in enumerate([wasteland_dirt, wasteland_road, highway_asphalt, toxic_marsh, crystal_scar, factory_grate]):
        contract_strip.paste(blk.crop((32, 32, 64, 64)), (idx * 32, 0))
    contract_strip.save(TILES_DIR / "recycler_tileset.png")
    contract_strip.save(BAKED_DIR / "tiles.png")

    # 3. 2.5D Variant Strips (512x128 each) & single 128x128 previews
    village_strip = pack_strip_512x128([wasteland_road, wasteland_dirt, road_shoulder, scrap_plate])
    village_strip.save(TILES_DIR / "village_ground_variants_2p5d.png")
    wasteland_road.save(TILES_DIR / "village_ground_2p5d.png")

    guild_strip = pack_strip_512x128([guild_bunker, scrap_plate, factory_grate, lab_circuit])
    guild_strip.save(TILES_DIR / "guild_ground_variants_2p5d.png")
    guild_bunker.save(TILES_DIR / "guild_ground_2p5d.png")

    wasteland_strip = pack_strip_512x128([wasteland_dirt, dark_soil, scorched_ash, scrap_plate])
    wasteland_strip.save(TILES_DIR / "wasteland_ground_variants_2p5d.png")
    wasteland_dirt.save(TILES_DIR / "wasteland_ground_2p5d.png")

    road_strip = pack_strip_512x128([highway_asphalt, factory_grate, urban_concrete, lab_circuit])
    road_strip.save(TILES_DIR / "wasteland_road_variants_2p5d.png")
    highway_asphalt.save(TILES_DIR / "wasteland_road_2p5d.png")

    toxic_v2 = toxic_marsh.transpose(Image.Transpose.ROTATE_90)
    toxic_v3 = toxic_marsh.transpose(Image.Transpose.ROTATE_180)
    toxic_v4 = ImageEnhance.Brightness(toxic_marsh).enhance(0.90)
    toxic_strip = pack_strip_512x128([toxic_marsh, toxic_v2, toxic_v3, toxic_v4])
    toxic_strip.save(TILES_DIR / "toxic_mud_variants_2p5d.png")
    toxic_marsh.save(TILES_DIR / "toxic_mud_2p5d.png")

    crystal_v2 = crystal_scar.transpose(Image.Transpose.ROTATE_90)
    crystal_v3 = crystal_scar.transpose(Image.Transpose.ROTATE_180)
    crystal_v4 = ImageEnhance.Brightness(crystal_scar).enhance(0.92)
    crystal_strip = pack_strip_512x128([crystal_scar, crystal_v2, crystal_v3, crystal_v4])
    crystal_strip.save(TILES_DIR / "crystal_ground_variants_2p5d.png")

    print("[TILES] Rebuilt cohesive dark wasteland 2.5D terrain tilesets successfully.")


if __name__ == "__main__":
    main()
