"""
Crusader Knight 30-frame animation builder (v2).

Replaces the old 8-frame "paste a pre-drawn sword sprite" pipeline that produced:
  * double / overlapping weapons (baked sword + hand-drawn sword + AttackFlash arc)
  * weapons vanishing on idle / hit / transition frames
  * 180-degree flips and pops caused by mixing differently-scaled source sprites

Pipeline
  1. Body layer  : the clean sword-less turnaround sprite of each direction, articulated procedurally
                   (hip split legs, torso lean, squash/stretch, lunge, bob, sway).
  2. Weapon layer: sword / warhammer / crossbow are drawn ONCE per frame as a 3D-projected vector
                   (supersampled 4x then thresholded to crisp pixels) and depth-sorted behind or in
                   front of the body depending on where the weapon points.  There is never a baked
                   weapon in the body sprite, so overlap is structurally impossible.
  3. Every action has exactly 30 frames x 8 directions x 3 loadouts (blade / heavy / rifle).

Outputs
  assets/sprites/player/anim30/<loadout>/<action>.png   3360x1024 runtime sheets (30 cols x 8 dir rows)
  assets/sprites/player/r17_loadout_<loadout>.png       legacy 8-frame sampled atlas (preview / fallback / QA)
  assets/sprites/player/frames + actions                legacy 8-frame sampled split files (blade)
  docs/concepts/knight30_diagnostic.png                 visual verification sheet
"""

from __future__ import annotations

import math
import sys
from pathlib import Path
from typing import Dict, List, Tuple

import numpy as np
from PIL import Image, ImageDraw, ImageOps

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_crusader_knight_atlas as legacy  # noqa: E402

ROOT = legacy.ROOT
PLAYER_DIR = legacy.PLAYER_DIR
ANIM30_DIR = PLAYER_DIR / "anim30"
DOCS_DIR = legacy.DOCS_DIR

W, H = legacy.FRAME_W, legacy.FRAME_H
N = 30
DIRECTIONS = 8
ACTIONS = legacy.ACTIONS
LOADOUTS = ["blade", "heavy", "rifle"]
KIND_OF = {"blade": "sword", "heavy": "hammer", "rifle": "crossbow"}
SS = 4
FLAT = 0.7  # ground-plane vertical compression of the 2.5D camera
CHEST = (56.0, 70.0)
HIP_Y = 78
FEET_Y = 108.0
THETA = [0, 45, 90, 135, 180, 225, 270, 315]
LEGACY_SAMPLE = [round(i * (N - 1) / 7) for i in range(8)]

OUT = (16, 20, 28, 255)
STEEL_L = (245, 250, 255, 255)
STEEL = (200, 216, 232, 255)
STEEL_M = (126, 148, 174, 255)
STEEL_D = (56, 72, 92, 255)
GOLD_L = (255, 236, 136, 255)
GOLD = (244, 192, 54, 255)
GOLD_D = (164, 116, 26, 255)
WOOD_L = (176, 124, 72, 255)
WOOD = (122, 80, 46, 255)
WOOD_D = (62, 40, 22, 255)
ARM = (112, 134, 158, 255)
BOLT_FLETCH = (215, 52, 48, 255)
STRING_COL = (242, 238, 222, 255)

GUARD = {"sword": (42.0, 60.0), "hammer": (30.0, 66.0), "crossbow": (6.0, -14.0)}


# --------------------------------------------------------------------------- math helpers
def kf(f: float, keys: List[Tuple[float, float]]) -> float:
    """Cardinal (Catmull-Rom style) interpolation through (frame, value) keys."""
    xs = [k[0] for k in keys]
    ys = [k[1] for k in keys]
    if f <= xs[0]:
        return ys[0]
    if f >= xs[-1]:
        return ys[-1]
    i = max(j for j in range(len(xs) - 1) if xs[j] <= f)

    def tangent(j: int) -> float:
        if j == 0:
            return (ys[1] - ys[0]) / (xs[1] - xs[0])
        if j == len(xs) - 1:
            return (ys[-1] - ys[-2]) / (xs[-1] - xs[-2])
        return (ys[j + 1] - ys[j - 1]) / (xs[j + 1] - xs[j - 1])

    h = xs[i + 1] - xs[i]
    t = (f - xs[i]) / h
    m0, m1 = tangent(i) * h, tangent(i + 1) * h
    h00 = 2 * t**3 - 3 * t**2 + 1
    h10 = t**3 - 2 * t**2 + t
    h01 = -2 * t**3 + 3 * t**2
    h11 = t**3 - t**2
    return h00 * ys[i] + h10 * m0 + h01 * ys[i + 1] + h11 * m1


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3 - 2 * t)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


# --------------------------------------------------------------------------- vector layer
class Layer:
    """Supersampled vector layer, downsampled and alpha-thresholded to crisp pixel art."""

    def __init__(self) -> None:
        self.im = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.im)

    def _p(self, p):
        return (p[0] * SS, p[1] * SS)

    def line(self, a, b, w: float, col, outline: bool = True) -> None:
        if outline:
            self._line(a, b, w + 1.7, OUT)
        self._line(a, b, w, col)

    def _line(self, a, b, w, col) -> None:
        self.d.line([self._p(a), self._p(b)], fill=col, width=max(1, int(w * SS)))
        r = w * SS / 2.0
        for p in (a, b):
            x, y = self._p(p)
            self.d.ellipse((x - r, y - r, x + r, y + r), fill=col)

    def poly(self, pts, col, outline: bool = True) -> None:
        sp = [self._p(p) for p in pts]
        self.d.polygon(sp, fill=col)
        if outline:
            self.d.line(sp + [sp[0]], fill=OUT, width=int(1.3 * SS), joint="curve")

    def circle(self, c, r: float, col, outline: bool = True) -> None:
        x, y = self._p(c)
        if outline:
            ro = (r + 0.9) * SS
            self.d.ellipse((x - ro, y - ro, x + ro, y + ro), fill=OUT)
        rr = r * SS
        self.d.ellipse((x - rr, y - rr, x + rr, y + rr), fill=col)

    def finish(self) -> Image.Image:
        small = self.im.resize((W, H), Image.BOX)
        arr = np.array(small)
        a = arr[:, :, 3]
        arr[:, :, 3] = np.where(a >= 96, 255, 0).astype(np.uint8)
        return Image.fromarray(arr, "RGBA")


def vec_dir(theta_deg: float, elev_deg: float):
    t, e = math.radians(theta_deg), math.radians(elev_deg)
    return (math.cos(t) * math.cos(e), math.sin(t) * math.cos(e), math.sin(e))


def add3(a, b):
    return (a[0] + b[0], a[1] + b[1], a[2] + b[2])


def mul3(a, k):
    return (a[0] * k, a[1] * k, a[2] * k)


def proj(c, p):
    return (c[0] + p[0], c[1] + p[1] * FLAT - p[2])


# --------------------------------------------------------------------------- weapons
def draw_arm(layer: Layer, c, shoulder3, hand3) -> None:
    s = proj(c, shoulder3)
    h = proj(c, hand3)
    layer.line(s, h, 4.8, ARM)
    layer.circle(h, 3.1, STEEL_M)
    layer.circle((h[0] + 0.3, h[1] - 0.3), 1.0, GOLD, outline=False)


def screen_normal(a, b):
    ux, uy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(ux, uy)
    if n < 0.001:
        return (0.0, 1.0), (1.0, 0.0)
    ux, uy = ux / n, uy / n
    return (ux, uy), (-uy, ux)


def off(p, n, k):
    return (p[0] + n[0] * k, p[1] + n[1] * k)


def hand_point(d, right):
    return add3(add3(mul3((d[0], d[1], 0.0), 8.0), mul3((right[0], right[1], 0.0), 11.0)), (0, 0, -3.0))


def draw_sword(layer: Layer, c, theta, phi, e, d, right, arms) -> float:
    ang = theta + phi
    dirv = vec_dir(ang, e)
    hand = hand_point(d, right)
    hp = proj(c, hand)
    pm = proj(c, add3(hand, mul3(dirv, -5.0)))
    gd = proj(c, add3(hand, mul3(dirv, 3.0)))
    b0 = proj(c, add3(hand, mul3(dirv, 4.5)))
    md = proj(c, add3(hand, mul3(dirv, 29.0)))
    tp = proj(c, add3(hand, mul3(dirv, 37.0)))
    u, n = screen_normal(b0, tp)
    layer.line(pm, hp, 3.4, WOOD_D)
    layer.poly([off(b0, n, 3.4), off(md, n, 2.5), tp, off(md, n, -2.5), off(b0, n, -3.4)], STEEL)
    layer.line(off(b0, n, -1.6), off(md, n, -1.0), 1.1, STEEL_M, outline=False)
    layer.line(b0, off(tp, u, -2.0), 1.3, (250, 253, 255, 255), outline=False)
    layer.line(off(gd, n, 7.5), off(gd, n, -7.5), 2.8, GOLD)
    layer.circle(pm, 2.2, GOLD)
    return dirv[1]


def draw_hammer(layer: Layer, c, theta, phi, e, d, right, arms) -> float:
    ang = theta + phi
    dirv = vec_dir(ang, e)
    hand = hand_point(d, right)
    end_pt = proj(c, add3(hand, mul3(dirv, -4.5)))
    grip = proj(c, add3(hand, mul3(dirv, 2.0)))
    grip2 = proj(c, add3(hand, mul3(dirv, 7.0)))
    tip = proj(c, add3(hand, mul3(dirv, 30.0)))
    u, n = screen_normal(end_pt, tip)
    layer.line(end_pt, tip, 3.6, WOOD)
    layer.line(grip, grip2, 3.8, GOLD_D, outline=False)
    hc = (tip[0] + u[0] * 2.5, tip[1] + u[1] * 2.5)
    p1, p2 = off(off(hc, u, 5.5), n, 8.5), off(off(hc, u, 5.5), n, -8.5)
    p3, p4 = off(off(hc, u, -5.5), n, -8.5), off(off(hc, u, -5.5), n, 8.5)
    layer.poly([p1, p2, p3, p4], STEEL_M)
    layer.line(off(p1, u, -1.0), off(p2, u, -1.0), 1.1, (236, 244, 252, 255), outline=False)
    layer.line(off(p4, u, 1.0), off(p3, u, 1.0), 1.1, STEEL_D, outline=False)
    layer.circle(hc, 1.6, GOLD, outline=False)
    return dirv[1]


def draw_crossbow(layer: Layer, c, theta, phi, pitch, d, right, string_f, bolt_visible, arms) -> float:
    ang = theta + phi
    A = vec_dir(ang, pitch)
    Rg = (-math.sin(math.radians(ang)), math.cos(math.radians(ang)), 0.0)
    Up = (0.0, 0.0, 1.0)
    p0 = add3((d[0] * 7.0, d[1] * 7.0, -1.0), mul3(Rg, 2.2))

    def P(f, s, u=0.0):
        return add3(add3(add3(p0, mul3(A, f * 1.15)), mul3(Rg, s * 1.15)), mul3(Up, u))

    # 1. Contoured dark walnut tiller / stock
    butt = proj(c, P(-10, 0, -1.2))
    nose = proj(c, P(23, 0, 0.0))
    layer.line(butt, nose, 5.0, WOOD_D)
    layer.line(proj(c, P(-9, 0, -0.8)), proj(c, P(22, 0, 0.0)), 3.8, WOOD)
    layer.line(proj(c, P(-2, 0, 0.6)), proj(c, P(21, 0, 0.6)), 2.2, WOOD_L, outline=False)
    layer.line(proj(c, P(3, 0, 0.8)), proj(c, P(20, 0, 0.8)), 1.3, STEEL_D, outline=False)

    # Brass trigger lock fittings
    layer.circle(proj(c, P(0, 0.8, -0.2)), 2.0, GOLD)
    layer.circle(proj(c, P(0, 0.8, -0.2)), 1.0, GOLD_L, outline=False)

    # 2. Front Stirrup (Forged steel cocking D-ring foot-loop)
    st0 = proj(c, P(22.5, -4.2, -0.5))
    st1 = proj(c, P(29.0, -3.5, -1.0))
    st2 = proj(c, P(30.0, 0.0, -1.2))
    st3 = proj(c, P(29.0, 3.5, -1.0))
    st4 = proj(c, P(22.5, 4.2, -0.5))
    layer.poly([st0, st1, st2, st3, st4, proj(c, P(23.5, 0, -0.5))], STEEL_D)
    layer.line(st1, st2, 2.0, STEEL_M, outline=False)
    layer.line(st2, st3, 2.0, STEEL, outline=False)

    # 3. Forged Recurve Steel Prod (Bow limbs with thickness, bevels and flared tips)
    limb_steps = range(-15, 16, 2)
    pts_front = []
    pts_back = []
    for s in limb_steps:
        u_s = abs(s) / 15.0
        curv_f = 21.0 + 5.5 * (1.0 - (1.0 - u_s) ** 2) - 1.2 * (u_s ** 4)
        thickness = 4.4 * (1.0 - 0.35 * u_s)
        pts_front.append(proj(c, P(curv_f + thickness * 0.45, s, 0.3)))
        pts_back.append(proj(c, P(curv_f - thickness * 0.45, s, -0.1)))

    layer.poly(pts_front + list(reversed(pts_back)), STEEL_M)
    for i in range(len(pts_front) - 1):
        layer.line(pts_front[i], pts_front[i + 1], 1.8, STEEL_L, outline=False)
        layer.line(pts_back[i], pts_back[i + 1], 1.4, STEEL_D, outline=False)

    # Heavy brass nose bridle clamp
    layer.line(proj(c, P(20.5, -3.2, 0.4)), proj(c, P(20.5, 3.2, 0.4)), 3.8, GOLD)
    layer.line(proj(c, P(20.8, -2.6, 0.5)), proj(c, P(20.8, 2.6, 0.5)), 1.8, GOLD_L, outline=False)

    # Gold reinforced limb tip nocks
    tip_l = P(24.5, -15.5, 0.2)
    tip_r = P(24.5, 15.5, 0.2)
    layer.circle(proj(c, tip_l), 2.2, GOLD)
    layer.circle(proj(c, tip_r), 2.2, GOLD)

    # 4. Heavy twisted sinew/steel bowstring
    string_mid = P(string_f, 0, 0.8)
    layer.line(proj(c, tip_l), proj(c, string_mid), 1.6, STRING_COL)
    layer.line(proj(c, tip_r), proj(c, string_mid), 1.6, STRING_COL)

    # 5. Heavy armor-piercing bodkin bolt (quarrel)
    if bolt_visible:
        b_tail = proj(c, P(string_f + 0.8, 0, 0.8))
        b_head_base = proj(c, P(30.0, 0, 0.8))
        b_tip = proj(c, P(35.5, 0, 0.8))
        layer.line(b_tail, b_head_base, 2.4, WOOD_L)
        layer.poly([proj(c, P(29.5, -2.0, 0.8)), b_tip, proj(c, P(29.5, 2.0, 0.8)), b_head_base], STEEL_L)
        fletch_tail = P(string_f + 1.2, 0, 0.8)
        layer.line(proj(c, fletch_tail), proj(c, P(string_f + 4.5, -2.4, 1.0)), 1.8, BOLT_FLETCH, outline=False)
        layer.line(proj(c, fletch_tail), proj(c, P(string_f + 4.5, 2.4, 1.0)), 1.8, BOLT_FLETCH, outline=False)

    # 6. Armored knight gauntlets holding the tiller & bracing the fore-end
    if arms:
        rs = add3(mul3((right[0], right[1], 0.0), 9.0), (0, 0, 6.0))
        ls = add3(mul3((right[0], right[1], 0.0), -9.0), (0, 0, 6.0))
        r_hand = P(0.5, 0.8, -0.4)
        layer.line(proj(c, rs), proj(c, r_hand), 5.0, ARM)
        layer.circle(proj(c, r_hand), 3.4, STEEL_M)
        layer.circle(proj(c, add3(r_hand, (0.4, 0, 0))), 1.4, GOLD, outline=False)
        l_hand = P(12.5, -0.8, -0.6)
        layer.line(proj(c, ls), proj(c, l_hand), 5.0, ARM)
        layer.circle(proj(c, l_hand), 3.4, STEEL_M)
        layer.circle(proj(c, add3(l_hand, (-0.4, 0, 0))), 1.4, GOLD, outline=False)

    return A[1]


# --------------------------------------------------------------------------- body
def affine_coeffs(rot_deg, pivot, squash, feet_y, tx, ty, scale=1.0):
    a = math.radians(rot_deg)
    cs, sn = math.cos(a), math.sin(a)
    t1 = np.array([[1, 0, -pivot[0]], [0, 1, -pivot[1]], [0, 0, 1]], float)
    rm = np.array([[cs, -sn, 0], [sn, cs, 0], [0, 0, 1]], float)
    t2 = np.array([[1, 0, pivot[0]], [0, 1, pivot[1]], [0, 0, 1]], float)
    m1 = t2 @ rm @ t1
    sy = squash * scale
    s = np.array([[scale, 0, pivot[0] * (1 - scale)], [0, sy, feet_y * (1 - sy)], [0, 0, 1]], float)
    tr = np.array([[1, 0, tx], [0, 1, ty], [0, 0, 1]], float)
    m = tr @ s @ m1
    inv = np.linalg.inv(m)
    return tuple(float(v) for v in inv[:2].reshape(-1)), m


def crisp(img: Image.Image) -> Image.Image:
    arr = np.array(img)
    arr[:, :, 3] = np.where(arr[:, :, 3] >= 110, 255, 0).astype(np.uint8)
    return Image.fromarray(arr, "RGBA")


def shift_rows_up(arr: np.ndarray, n: int) -> np.ndarray:
    out = np.zeros_like(arr)
    n = int(round(n))
    if n <= 0:
        return arr.copy()
    out[: arr.shape[0] - n] = arr[n:]
    return out


def tint_white(img: Image.Image, k: float, color=(255, 255, 255)) -> Image.Image:
    if k <= 0.001:
        return img
    arr = np.array(img).astype(np.float32)
    m = arr[:, :, 3] > 0
    for ch in range(3):
        arr[:, :, ch][m] = arr[:, :, ch][m] * (1 - k) + color[ch] * k
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def render_body(base_sprite: Image.Image, dx, dy, lean_rot, squash, l_lift, r_lift, flash=0.0, flash_color=(255, 255, 255)):
    if base_sprite.size == (W, H):
        canvas = base_sprite.copy()
    else:
        canvas = legacy.place_in_frame(base_sprite, target_h=84)
    arr = np.array(canvas)
    upper = np.zeros_like(arr)
    upper[:HIP_Y + 4] = arr[:HIP_Y + 4]
    lower = np.zeros_like(arr)
    lower[HIP_Y - 2:] = arr[HIP_Y - 2:]
    if l_lift == 0 and r_lift == 0:
        lower_img = Image.fromarray(lower, "RGBA")
    else:
        ll, lr = lower.copy(), lower.copy()
        ll[:, 56:] = 0
        lr[:, :56] = 0
        ll, lr = shift_rows_up(ll, l_lift), shift_rows_up(lr, r_lift)
        lower_img = Image.alpha_composite(Image.fromarray(ll, "RGBA"), Image.fromarray(lr, "RGBA"))
    pivot = (56.0, float(HIP_Y))
    cu, m_up = affine_coeffs(lean_rot, pivot, squash, FEET_Y, dx, dy)
    cl, _ = affine_coeffs(0.0, pivot, squash, FEET_Y, dx * 0.6, 0.0)
    up_t = Image.fromarray(upper, "RGBA").transform((W, H), Image.AFFINE, cu, resample=Image.BICUBIC)
    lo_t = lower_img.transform((W, H), Image.AFFINE, cl, resample=Image.BICUBIC)
    body = crisp(Image.alpha_composite(lo_t, up_t))
    body = tint_white(body, flash, flash_color)
    chest = m_up @ np.array([CHEST[0], CHEST[1], 1.0])
    return body, (float(chest[0]), float(chest[1]))


def add_dust(img: Image.Image, f: int, d) -> None:
    for k, contact in enumerate((0.0, 7.5, 15.0, 22.5)):
        age = (f - contact) % N
        if age < 6:
            fade = 1.0 - age / 6.0
            fx = 56 + (-9 if k % 2 == 0 else 9) - d[0] * 5
            dr = ImageDraw.Draw(img, "RGBA")
            rx, ry = 4 + age * 1.6, 1.5 + age * 0.5
            al = int(170 * fade)
            dr.ellipse((fx - rx, 108 - ry, fx + rx, 108 + ry), fill=(168, 142, 108, al))
            dr.ellipse((fx - rx + 2, 107 - ry, fx + rx - 2, 108 + ry - 1), fill=(215, 190, 150, int(al * 0.8)))


def add_sparks(img: Image.Image, cx, cy, age: float) -> None:
    if age < 0 or age > 7:
        return
    dr = ImageDraw.Draw(img, "RGBA")
    r = 5 + age * 2.2
    a = int(255 * (1 - age / 7.0))
    for i in range(10):
        ang = i * math.tau / 10 + 0.3
        r0, r1 = r * 0.45, r * (1.0 if i % 2 == 0 else 0.7)
        dr.line((cx + math.cos(ang) * r0, cy + math.sin(ang) * r0 * 0.8, cx + math.cos(ang) * r1, cy + math.sin(ang) * r1 * 0.8), fill=(255, 214, 90, a), width=1)
    dr.ellipse((cx - 2, cy - 2, cx + 2, cy + 2), fill=(255, 250, 220, a))


def add_scan_ring(img: Image.Image, d, f: int) -> None:
    if f < 8 or f > 26:
        return
    t = (f - 8) / 18.0
    dr = ImageDraw.Draw(img, "RGBA")
    cx, cy = 56 + d[0] * 24, 104 + d[1] * 24 * FLAT * 0.5
    rx = 6 + t * 16
    a = int(220 * (1 - t))
    dr.ellipse((cx - rx, cy - rx * 0.4, cx + rx, cy + rx * 0.4), outline=(60, 230, 244, a), width=1)
    dr.ellipse((cx - rx * 0.55, cy - rx * 0.22, cx + rx * 0.55, cy + rx * 0.22), outline=(255, 200, 80, int(a * 0.8)), width=1)


def add_muzzle_flash(img: Image.Image, chest, theta: float, f: int) -> None:
    dr = ImageDraw.Draw(img, "RGBA")
    rad = math.radians(theta)
    mx = chest[0] + math.cos(rad) * 35.0
    my = chest[1] + math.sin(rad) * 35.0 * FLAT - 1.0
    r = 5.0 if f == 0 else 3.2
    al = 255 if f == 0 else 190
    dr.ellipse((mx - r, my - r * 0.7, mx + r, my + r * 0.7), fill=(255, 252, 225, al))
    dr.line((mx - r * 2.2, my, mx + r * 2.2, my), fill=(255, 214, 70, al), width=1)
    dr.line((mx, my - r * 1.8, mx, my + r * 1.8), fill=(255, 214, 70, al), width=1)


# --------------------------------------------------------------------------- poses
def new_pose(kind: str) -> Dict:
    phi, e = GUARD[kind]
    return dict(lean=0.0, lunge=0.0, bob=0.0, sway=0.0, squash=1.0, l=0.0, r=0.0, flash=0.0, kind=kind, phi=phi, e=e, fs=4.0, bolt=True, arms=True, dust=False)


def pose_for(action: str, loadout: str, f: int) -> Dict:
    kind = "crossbow" if action == "shoot" else KIND_OF[loadout]
    p = new_pose(kind)
    t = f / N
    if action == "idle":
        br = math.sin(math.tau * t)
        p["bob"] = br * 0.9
        p["squash"] = 1 + 0.006 * br
        p["phi"] += math.sin(math.tau * t + 0.8) * 2.5
        p["e"] += br * 2.0
    elif action == "walk":
        ph = math.tau * t * 2
        s = math.sin(ph)
        p["l"], p["r"] = max(0.0, s) * 3.2, max(0.0, -s) * 3.2
        p["bob"] = -abs(s) * 1.8
        p["sway"] = math.sin(ph / 2) * 1.4
        p["lean"] = 3.0
        p["phi"] += s * 5.0
        p["e"] += math.cos(2 * ph) * 2.5
        p["dust"] = True
    elif action in ("slash", "draw_sword"):
        combo2 = action == "draw_sword"
        if kind == "hammer":
            if not combo2:
                p["e"] = kf(f, [(0, 66), (5, 88), (8, 90), (11, 4), (14, 2), (20, 16), (29, 66)])
                p["phi"] = kf(f, [(0, 30), (5, 10), (11, 0), (29, 30)])
                p["lean"] = kf(f, [(0, 0), (5, -9), (8, -9), (11, 11), (16, 9), (24, 2), (29, 0)])
            else:
                p["e"] = kf(f, [(0, 66), (4, 24), (8, 6), (12, 30), (16, 70), (22, 70), (29, 66)])
                p["phi"] = kf(f, [(0, 30), (4, -45), (8, 0), (12, 25), (29, 30)])
                p["lean"] = kf(f, [(0, 0), (4, -6), (8, 9), (14, 5), (22, 1), (29, 0)])
            p["lunge"] = kf(f, [(0, 0), (5, -2), (11, 3), (18, 2.5), (29, 0)])
            p["bob"] = kf(f, [(0, 0), (5, -1.5), (11, 2.5), (16, 1), (29, 0)])
        else:
            if not combo2:
                p["phi"] = kf(f, [(0, 42), (3, 95), (4, 105), (8, -5), (12, -62), (16, -86), (22, -60), (29, 42)])
                p["e"] = kf(f, [(0, 60), (3, 78), (4, 80), (8, 34), (12, 14), (16, 10), (22, 30), (29, 60)])
                p["lean"] = kf(f, [(0, 0), (3, -7), (5, -7), (8, 9), (13, 7), (20, 2), (29, 0)])
            else:
                p["phi"] = kf(f, [(0, -50), (3, -100), (4, -108), (8, 5), (12, 70), (16, 92), (22, 65), (29, 42)])
                p["e"] = kf(f, [(0, 40), (3, 28), (4, 25), (8, 30), (12, 42), (16, 52), (22, 58), (29, 60)])
                p["lean"] = kf(f, [(0, 0), (3, -6), (5, -6), (8, 8), (13, 6), (20, 2), (29, 0)])
            if kind == "crossbow":  # rifle loadout melee => crossbow bash
                p["e"] = -4.0 + 0.0 * p["e"]
            p["lunge"] = kf(f, [(0, 0), (3, -1.5), (8, 3.5), (14, 3), (22, 1), (29, 0)])
            p["squash"] = kf(f, [(0, 1), (3, 0.97), (8, 1.025), (14, 1), (29, 1)])
            p["bob"] = kf(f, [(0, 0), (8, 1.5), (14, 0.5), (29, 0)])
        p["l"] = kf(f, [(0, 0), (4, 1.5), (8, 0), (29, 0)])
    elif action == "shoot":
        # Frame 0: snap release of string, bolt fired immediately on trigger pull!
        # Frames 1-6: arbalest recoil kickback
        # Frames 7-18: winch cranks string back to cocked position
        # Frames 19-29: new bolt loaded, ready in aim stance
        p["e"] = kf(f, [(0, 0), (3, 4), (6, 2), (12, -4), (20, -1), (29, 0)])
        p["phi"] = kf(f, [(0, 0), (6, -2), (16, 1), (29, 0)])
        p["lean"] = kf(f, [(0, -4), (3, -5), (8, -2), (16, 1), (24, 0), (29, 0)])
        p["lunge"] = kf(f, [(0, -3), (3, -3.5), (8, -1), (18, 0.5), (29, 0)])
        p["bob"] = kf(f, [(0, 1.2), (4, 1.5), (12, 0.4), (20, -0.4), (29, 0)])
        if f <= 5:
            p["fs"] = 23.5
            p["bolt"] = False
        elif f <= 18:
            p["fs"] = lerp(23.5, 4.0, smooth((f - 5) / 13.0))
            p["bolt"] = f >= 14
        else:
            p["fs"] = 4.0
            p["bolt"] = True
    elif action == "swap_tool":
        p["phi"] = GUARD[kind][0] + 360.0 * smooth(t * 1.05)
        p["e"] = kf(f, [(0, GUARD[kind][1]), (8, 18), (15, -30), (22, 20), (29, GUARD[kind][1])])
        p["bob"] = kf(f, [(0, 0), (10, 1.6), (22, 0.6), (29, 0)])
        p["lean"] = kf(f, [(0, 0), (10, 4), (29, 0)])
    elif action == "interact":
        p["lean"] = kf(f, [(0, 0), (8, 10), (18, 10), (29, 0)])
        p["lunge"] = kf(f, [(0, 0), (8, 3), (18, 3), (29, 0)])
        p["e"] = kf(f, [(0, GUARD[kind][1]), (8, -22), (20, -22), (29, GUARD[kind][1])])
        p["phi"] = kf(f, [(0, GUARD[kind][0]), (8, 62), (20, 62), (29, GUARD[kind][0])])
        p["bob"] = kf(f, [(0, 0), (8, 1.2), (18, 1.2), (29, 0)])
    elif action == "hit":
        p["lunge"] = kf(f, [(0, 0), (2, -5), (6, -3), (14, -1), (29, 0)])
        p["lean"] = kf(f, [(0, 0), (2, -14), (8, -8), (16, -2), (29, 0)])
        p["flash"] = kf(f, [(0, 0), (1, 0.55), (3, 0.35), (7, 0.0), (29, 0)])
        p["squash"] = kf(f, [(0, 1), (2, 0.96), (8, 1.0), (29, 1)])
        p["phi"] += kf(f, [(0, 0), (2, 24), (10, 6), (29, 0)])
        p["e"] += kf(f, [(0, 0), (2, 16), (10, 4), (29, 0)])
    return p


# --------------------------------------------------------------------------- frame rendering
def get_clean_body_canvas(assets, direction: int) -> Image.Image:
    sprite = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
    return legacy.place_in_frame(sprite, target_h=84)


def draw_weapon_layer(p: Dict, theta, d, right, chest, arms_ok=True) -> Tuple[Image.Image, float]:
    layer = Layer()
    kind = p["kind"]
    if kind == "sword":
        ydir = draw_sword(layer, chest, theta, p["phi"], p["e"], d, right, arms_ok)
        hand = hand_point(d, right)
        sh = add3(mul3((right[0], right[1], 0.0), 9.0), (0, 0, 6.0))
    elif kind == "hammer":
        ydir = draw_hammer(layer, chest, theta, p["phi"], p["e"], d, right, arms_ok)
        hand = hand_point(d, right)
        sh = add3(mul3((right[0], right[1], 0.0), 9.0), (0, 0, 6.0))
    else:
        ydir = draw_crossbow(layer, chest, theta, p["phi"], p["e"], d, right, p["fs"], p["bolt"], arms_ok)
        hand = None
        sh = None
    if arms_ok and hand is not None:
        draw_arm(layer, chest, sh, hand)
    return layer.finish(), ydir


def compose(body: Image.Image, weapon: Image.Image, behind: bool) -> Image.Image:
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    if behind:
        out.alpha_composite(weapon)
        out.alpha_composite(body)
    else:
        out.alpha_composite(body)
        out.alpha_composite(weapon)
    return out


def rotate_on_feet(img: Image.Image, angle: float) -> Image.Image:
    if abs(angle) < 0.1:
        return img
    w, h = img.size
    pad = 50
    big = Image.new("RGBA", (w + pad * 2, h + pad * 2), (0, 0, 0, 0))
    ax, ay = int(w * 0.45), h
    big.paste(img, (pad, pad))
    center = (pad + ax, pad + ay)
    rot = big.rotate(angle, resample=Image.BICUBIC, center=center)
    bbox = rot.getbbox()
    if not bbox:
        return img
    return rot.crop(bbox)


def render_dead(assets, direction: int, f: int, loadout: str = "blade") -> Image.Image:
    is_left = direction in (3, 4, 5)
    hurt_s = ImageOps.mirror(assets.hurt_sprite) if is_left else assets.hurt_sprite
    dead_s = ImageOps.mirror(assets.dead_sprite) if is_left else assets.dead_sprite

    if f <= 6:
        ox = -4 if not is_left else 4
        return legacy.place_in_frame(hurt_s, target_h=83, offset_x=ox, offset_y=-1)
    elif f <= 14:
        prog = (f - 6) / 8.0
        ox = int(round((-4 if not is_left else 4) * (1.0 - prog)))
        oy = int(round(prog * 8))
        return legacy.place_in_frame(hurt_s, target_h=81, offset_x=ox, offset_y=oy)
    else:
        # Fallen defeated knight resting on the ground
        dw = 100
        dh = int(round(dw / float(dead_s.width) * dead_s.height))
        scaled_dead = dead_s.resize((dw, dh), Image.NEAREST)
        frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        ox = (W - dw) // 2
        oy = int(FEET_Y - dh)
        frame.alpha_composite(scaled_dead, (ox, oy))
        return frame


# --------------------------------------------------------------------------- authentic action renderers
ANGLES_SHOOT = {0: 0, 1: -8, 2: -15, 3: 15, 4: 0, 5: -8, 6: 12, 7: 8}


def render_shoot(assets, direction: int, f: int) -> Image.Image:
    is_left = direction in (3, 4, 5)
    ang = ANGLES_SHOOT[direction]
    cb = assets.crossbow_sprite
    base = ImageOps.mirror(cb) if is_left else cb

    # Scale to target knight height (76px keeps comfortable margins on 112px cell)
    aspect = base.width / float(base.height)
    th = 76
    tw = int(round(th * aspect))
    scaled = base.resize((tw, th), Image.NEAREST)

    aimed = rotate_on_feet(scaled, ang)

    # 30-frame timing:
    # f 0..2: Fire! Golden/cyan muzzle burst flash, bolt release!
    # f 3..8: Peak recoil impulse absorption (slight backward kickback)
    # f 9..18: Winch crank & reload
    # f 19..29: Aimed ready stance
    t = f / float(N)
    if f <= 2:
        rx = -1.0
        ry = 0.0
    elif f <= 8:
        w_rec = math.sin((f - 2) / 6.0 * math.pi)
        rx = -2.5 * w_rec
        ry = -0.8 * w_rec
    elif f <= 18:
        prog = (f - 8) / 10.0
        rx = -2.5 * (1.0 - prog)
        ry = 0.6 * math.sin(prog * math.pi)
    else:
        rx = 0.0
        ry = math.sin(t * math.tau * 2) * 0.3

    sign_x = -1.0 if is_left else 1.0
    ox = (W - aimed.width) // 2 + int(round(sign_x * rx))
    oy = int(FEET_Y - aimed.height + round(ry))

    frame = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    frame.alpha_composite(aimed, (ox, oy))

    # Brilliant muzzle burst flash on frame 0 and 1
    if f in (0, 1):
        dr = ImageDraw.Draw(frame, "RGBA")
        if not is_left:
            mx = ox + aimed.width - 2
            my = oy + int(round(aimed.height * 0.38))
        else:
            mx = ox + 2
            my = oy + int(round(aimed.height * 0.38))

        r = 4 if f == 0 else 3
        dr.ellipse((mx - r, my - r * 0.7, mx + r, my + r * 0.7), fill=(255, 255, 225, 255))
        dr.line((mx - r * 1.5, my, mx + r * 1.5, my), fill=(255, 215, 65, 240), width=2)
        dr.line((mx, my - r * 1.5, mx, my + r * 1.5), fill=(255, 215, 65, 240), width=2)
        dr.line((mx - r * 1.1, my - r * 0.9, mx + r * 1.1, my + r * 0.9), fill=(255, 240, 150, 200), width=1)
        dr.line((mx - r * 1.1, my + r * 0.9, mx + r * 1.1, my - r * 0.9), fill=(255, 240, 150, 200), width=1)

    return frame


def render_slash(assets, action: str, direction: int, f: int, loadout: str) -> Image.Image:
    combo2 = action == "draw_sword"
    is_left = direction in (3, 4, 5)

    if loadout == "heavy":
        if f <= 6:
            img = legacy.place_in_frame(assets.hammer_sprite, target_h=88, offset_y=-2)
        elif f <= 14:
            img = legacy.place_in_frame(assets.hammer_sprite, target_h=90, offset_y=-4)
        elif f <= 22:
            base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
            img = legacy.place_in_frame(base_s, target_h=82, offset_y=4)
            dr = ImageDraw.Draw(img, "RGBA")
            dr.ellipse((34, 100, 78, 114), outline=(245, 180, 50, 200), width=2)
            dr.ellipse((26, 96, 86, 118), outline=(255, 215, 80, 120), width=1)
        else:
            base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
            img = legacy.place_in_frame(base_s, target_h=84)
        if is_left:
            img = ImageOps.mirror(img)
        return img

    if not combo2:
        if f <= 5:
            pose_idx = 0
            ox = -2 if not is_left else 2
        elif f <= 14:
            pose_idx = 1
            ox = 1 if not is_left else -1
        elif f <= 22:
            pose_idx = 2
            ox = 1 if not is_left else -1
        else:
            pose_idx = 3
            ox = 0
    else:
        if f <= 5:
            pose_idx = 3
            ox = -2 if not is_left else 2
        elif f <= 14:
            pose_idx = 1
            ox = 0
        elif f <= 22:
            pose_idx = 2
            ox = 0
        else:
            pose_idx = 0
            ox = -1 if not is_left else 1

    sprite = assets.slash_sprites[pose_idx]
    placed = legacy.place_tight_slash(sprite, None, 84, is_left, offset_x=ox, pose_idx=pose_idx)
    return placed


def render_walk(assets, direction: int, f: int) -> Image.Image:
    is_left = direction in (3, 4, 5)
    cycle = (f / float(N)) * 2.0 * math.pi * 2.0
    walk_sprites = assets.walk_sprites
    step = int((f * 4.0 / float(N))) % len(walk_sprites)
    w_sprite = walk_sprites[step]
    if is_left:
        w_sprite = ImageOps.mirror(w_sprite)
    bob_y = int(round(math.sin(cycle) * 1.5))
    stride_x = int(round(math.cos(cycle) * 1.0))
    img = legacy.place_in_frame(w_sprite, target_h=84, offset_x=stride_x, offset_y=bob_y)
    if f in (1, 8, 16, 23):
        fx = 44 if is_left else 68
        legacy.draw_footstep_dust(img, fx, 108, 1.0)
    return img


def render_idle(assets, direction: int, f: int) -> Image.Image:
    base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
    cycle = (f / float(N)) * math.tau
    bob_y = int(round(math.sin(cycle) * 1.2))
    return legacy.place_in_frame(base_s, target_h=84, offset_y=bob_y)


def render_hit(assets, direction: int, f: int) -> Image.Image:
    base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
    is_left = direction in (3, 4, 5)
    hurt_s = ImageOps.mirror(assets.hurt_sprite) if is_left else assets.hurt_sprite
    if f <= 3:
        return legacy.place_in_frame(hurt_s, target_h=84, offset_x=-3 if not is_left else 3, offset_y=-1)
    elif f <= 10:
        return legacy.place_in_frame(hurt_s, target_h=83, offset_x=-4 if not is_left else 4, offset_y=1)
    elif f <= 18:
        return legacy.place_in_frame(base_s, target_h=83, offset_x=-1 if not is_left else 1)
    else:
        return legacy.place_in_frame(base_s, target_h=84)


def render_swap_tool(assets, direction: int, f: int) -> Image.Image:
    base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
    if f <= 6:
        return legacy.place_in_frame(base_s, target_h=84, offset_x=1)
    elif f <= 18:
        shield_block = legacy.place_in_frame(base_s, target_h=85, offset_x=-1)
        dr = ImageDraw.Draw(shield_block, "RGBA")
        dr.arc((66, 52, 94, 92), -60, 60, fill=(240, 190, 60, 180), width=2)
        return shield_block
    else:
        return legacy.place_in_frame(base_s, target_h=84)


def render_interact(assets, direction: int, f: int) -> Image.Image:
    base_s = assets.row0_sprites[legacy.DIR_TO_ROW0_INDEX[direction]]
    if f <= 6:
        return legacy.place_in_frame(base_s, target_h=84)
    elif f <= 18:
        inter_img = legacy.place_in_frame(base_s, target_h=84, offset_x=2, offset_y=1)
        dr = ImageDraw.Draw(inter_img, "RGBA")
        dr.ellipse((72, 68, 78, 74), fill=(60, 230, 240, 210))
        dr.arc((68, 64, 82, 78), 0, 360, fill=(40, 200, 230, 140), width=1)
        return inter_img
    else:
        return legacy.place_in_frame(base_s, target_h=84)


def render_frame(assets, action: str, direction: int, f: int, loadout: str) -> Image.Image:
    if action == "dead":
        return render_dead(assets, direction, f, loadout)
    if action == "shoot":
        return render_shoot(assets, direction, f)
    if action in ("slash", "draw_sword"):
        return render_slash(assets, action, direction, f, loadout)
    if action == "walk":
        return render_walk(assets, direction, f)
    if action == "hit":
        return render_hit(assets, direction, f)
    if action == "swap_tool":
        return render_swap_tool(assets, direction, f)
    if action == "interact":
        return render_interact(assets, direction, f)
    return render_idle(assets, direction, f)


# --------------------------------------------------------------------------- build
def build() -> None:
    src = ROOT / "docs" / "concepts" / "crusader_knight_pixel_spritesheet.png"
    print("[KNIGHT30] extracting clean sword-less turnaround bodies...")
    assets = legacy.ExtractedKnightAssets(legacy.extract_and_clean_source_sheet(src))

    ANIM30_DIR.mkdir(parents=True, exist_ok=True)
    blade_cells: Dict[Tuple[str, int, int], Image.Image] = {}
    for loadout in LOADOUTS:
        (ANIM30_DIR / loadout).mkdir(parents=True, exist_ok=True)
        legacy_atlas = Image.new("RGBA", (W * 8 * len(ACTIONS), H * DIRECTIONS), (0, 0, 0, 0))
        for ai, action in enumerate(ACTIONS):
            print(f"[KNIGHT30] {loadout}/{action} ...")
            sheet = Image.new("RGBA", (W * N, H * DIRECTIONS), (0, 0, 0, 0))
            for d in range(DIRECTIONS):
                for f in range(N):
                    img = render_frame(assets, action, d, f, loadout)
                    sheet.alpha_composite(img, (f * W, d * H))
                    if f in LEGACY_SAMPLE:
                        li = LEGACY_SAMPLE.index(f)
                        legacy_atlas.alpha_composite(img, ((ai * 8 + li) * W, d * H))
                        if loadout == "blade":
                            blade_cells[(action, d, li)] = img
            sheet.save(ANIM30_DIR / loadout / f"{action}.png")
        legacy_atlas.save(PLAYER_DIR / f"r17_loadout_{loadout}.png")
        if loadout == "blade":
            for name in ("recycler_player_multiaction_8dir_preview.png", "recycler_player_multiaction_8dir.png", "r17_wasteland_8dir_actions.png"):
                legacy_atlas.save(PLAYER_DIR / name)
            DOCS_DIR.mkdir(parents=True, exist_ok=True)
            legacy_atlas.save(DOCS_DIR / "recycler_player_multiaction_8dir_preview.png")

    print("[KNIGHT30] writing legacy 8-frame split files...")
    for action in ACTIONS:
        sheet = Image.new("RGBA", (W * 8, H * DIRECTIONS), (0, 0, 0, 0))
        for d in range(DIRECTIONS):
            folder = legacy.FRAMES_DIR / action / f"dir_{d}"
            folder.mkdir(parents=True, exist_ok=True)
            for li in range(8):
                img = blade_cells[(action, d, li)]
                img.save(folder / f"frame_{li}.png")
                sheet.alpha_composite(img, (li * W, d * H))
        sheet.save(legacy.ACTIONS_DIR / f"{action}.png")
        if action == "walk":
            sheet.save(PLAYER_DIR / "recycler_player_8dir.png")

    build_diagnostic(assets)
    print("[KNIGHT30] done: 3 loadouts x 9 actions x 8 dirs x 30 frames")


def build_diagnostic(assets) -> None:
    rows = [
        ("blade", "slash", 2), ("blade", "slash", 6), ("blade", "slash", 0), ("blade", "draw_sword", 4),
        ("rifle", "shoot", 0), ("rifle", "shoot", 6), ("heavy", "slash", 2), ("blade", "walk", 1),
        ("blade", "hit", 0), ("blade", "dead", 0),
    ]
    cols = list(range(0, 30, 2))
    sheet = Image.new("RGBA", (W * len(cols), H * len(rows)), (22, 26, 34, 255))
    for ri, (lo, act, d) in enumerate(rows):
        for ci, f in enumerate(cols):
            sheet.alpha_composite(render_frame(assets, act, d, f, lo), (ci * W, ri * H))
    out = DOCS_DIR / "concepts" / "knight30_diagnostic.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out)
    sheet.save(DOCS_DIR / "player_split_frame_diagnostic.png")


if __name__ == "__main__":
    build()
