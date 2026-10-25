"""Regenerate navigation diagrams from the actual runtime JSON (standard library only)."""

from html import escape
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
routes = json.loads((ROOT / "data/maps/wasteland_routes.json").read_text(encoding="utf-8"))["routes"]
art = json.loads((ROOT / "data/art/world_v2.json").read_text(encoding="utf-8"))

for route_id, route in routes.items():
    world_w, world_h = [v * 32 for v in route["size_tiles"]]
    scale = min(700 / world_w, 590 / world_h)
    ox, oy = 34, 84

    def point(x, y):
        return ox + x * world_w * scale, oy + y * world_h * scale

    def rect(x, y, w, h, fill, stroke="none", extra=""):
        return f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" fill="{fill}" stroke="{stroke}" {extra}/>'

    def label(x, y, text, color="#e8dfc9", size=15):
        return f'<text x="{x:.1f}" y="{y:.1f}" fill="{color}" font-size="{size}">{escape(text)}</text>'

    out = [
        '<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="800" viewBox="0 0 1080 800">',
        '<style>text{font-family:"Microsoft JhengHei","Noto Sans CJK TC",sans-serif} .road{fill:none;stroke-linecap:round;stroke-linejoin:round}</style>',
        rect(0, 0, 1080, 800, "#171b21"),
        label(30, 35, route["name"] + " — authored navigation blueprint", size=23),
        label(30, 61, f'{route_id} | {world_w} × {world_h} world px | generated from runtime JSON', "#a6b2bd", 14),
        rect(ox, oy, world_w * scale, world_h * scale, "#262d34", "#6b7279"),
    ]
    composition = art["routes"].get(route_id, {})
    colors = {"water": "#174e47", "chasm": "#0c0d15", "furnace": "#783d20", "rubble": "#655d58", "coolant": "#0d5369"}
    for area in composition.get("ground_areas", []):
        x, y, w, h = area["rect"]
        px, py = point(x, y)
        out.append(rect(px, py, w * world_w * scale, h * world_h * scale, colors[area["kind"]], "#879399"))
    for i, path in enumerate(route["exploration_paths"]):
        coordinates = " ".join(f"{px:.1f},{py:.1f}" for px, py in (point(*p) for p in path))
        width = route.get("path_widths", [7] * len(route["exploration_paths"]))[i] * 32 * scale
        color = "#ad9157" if i == 0 else ("#5a8b77" if i == len(route["exploration_paths"]) - 1 else "#657e98")
        out.append(f'<polyline points="{coordinates}" class="road" stroke="{color}" stroke-width="{width:.1f}"/>')
        out.append(f'<polyline points="{coordinates}" class="road" stroke="#d4d1bd" stroke-width="1" stroke-dasharray="4 7"/>')
    for placement in composition.get("placements", []):
        module = art["modules"][placement["module"]]
        px, py = point(*placement["position"])
        source = module["source_rect"]
        width = module["width"]
        height = source[3] * width / source[2]
        out.append(rect(px - width * scale / 2, py - height * scale, width * scale, height * scale, "#bdc6c9", "#8b969c", 'fill-opacity="0.13" stroke-width="0.8"'))
        for fx, fy, fw, fh in module["footprints"]:
            out.append(rect(px + fx * scale, py + fy * scale, fw * scale, fh * scale, "#c8796d", "#e4a196", 'fill-opacity="0.8" stroke-width="0.7"'))
    for cover in composition.get("decorations", []):
        px, py = point(*cover["position"])
        out.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="3" fill="#d69659"/>')
    sx, sy = point(*route["story_site"]["walkup"])
    pw, ph = route["story_site"]["protected_area"]
    out.append(rect(sx - pw * scale / 2, sy - ph * .82 * scale, pw * scale, ph * scale, "none", "#eac96b", 'stroke-width="1.5" stroke-dasharray="5 4"'))
    out.append(f'<circle cx="{sx:.1f}" cy="{sy:.1f}" r="10" fill="#e5bf58" stroke="#171b21" stroke-width="2"/>')
    out.append(label(sx - 5, sy + 5, "S", "#171b21", 15))
    for i, event in enumerate(route["exploration_points"], 1):
        px, py = point(*event["position"])
        out.append(f'<circle cx="{px:.1f}" cy="{py:.1f}" r="10" fill="#e1d9c5" stroke="#171b21" stroke-width="2"/>')
        out.append(label(px - 4.5, py + 5, str(i), "#171b21", 14))
    ex, ey = point(.5, (world_h - 90) / world_h)
    out.append(rect(ex - 8, ey - 6, 16, 12, "#6ecfa0", "#b6efcc"))
    lx, ly = 765, 100
    out += [label(lx, ly, "Runtime layers / 圖例", size=20)]
    legend = [
        ("#ad9157", "主路 / main approach"),
        ("#657e98", "支路、側翼 / exploration loop"),
        ("#5a8b77", "連接、回程 / connector-return"),
        ("#c8796d", "建築實體底腳 / collision feet"),
        ("#576069", "淡框為精靈外觀範圍 / visual only"),
        ("#174e47", "深水、斷層、坑槽 / blocked basins"),
        ("#e5bf58", "S：劇情調查點；虛線為保留區"),
        ("#6ecfa0", "綠框：回村出口"),
    ]
    for color, text in legend:
        ly += 33
        out.append(rect(lx, ly - 13, 16, 14, color))
        out.append(label(lx + 24, ly, text, size=13))
    ly += 48
    out.append(label(lx, ly, "Guarded discoveries / 守衛據點", size=17))
    for i, event in enumerate(route["exploration_points"], 1):
        ly += 32
        out.append(label(lx, ly, f'{i}. {event["name"]}', size=14))
    ly += 48
    for module_id in dict.fromkeys(p["module"] for p in composition.get("placements", [])):
        out.append(label(lx, ly, art["modules"][module_id]["label"], "#b5c4cf", 14))
        ly += 26
    out.append(label(30, 735, "Footprints are authored data; collision traversal is not verified. Existing saved positions can suppress new blockers.", "#cbbfaf", 14))
    out.append(label(30, 762, "No concept-board terrain is used. Runtime evidence review and gameplay QA are separate; automated tests were not run.", "#cbbfaf", 14))
    out.append('</svg>')
    (HERE / f'{route_id}-blueprint.svg').write_text("\n".join(out) + "\n", encoding="utf-8")
