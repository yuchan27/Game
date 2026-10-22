from __future__ import annotations

"""
R-17 rigged pixel-art renderer.

Replaces the old "warp a reference sheet + paste a weapon image on top" pipeline.
R-17 is modelled as a small 3D skeleton (pelvis, spine, head, two 2-bone arms,
two 2-bone legs, backpack, scarf/cape) built from sphere-swept capsules, and every
weapon (blade, heavy hammer, rifle) is real geometry held in the hands. Each frame
is posed procedurally, rendered with an orthographic 3/4 top-down camera,
z-buffered, toon-shaded into a fixed palette and outlined, so:

* the sword swing is the actual arm + blade moving through an arc (with a motion
  smear generated from the blade's own swept path),
* shooting raises the rifle to the shoulder, fires (baked muzzle flash) and recoils,
* walking has real alternating legs, counter-swinging arms and body bob,
* all 8 facing directions come from rotating the same rig, so they are consistent.

Outputs (atlas contract unchanged: 112x128 cells, 9 actions x 8 frames x 8 dirs):
  assets/sprites/player/recycler_player_multiaction_8dir_preview.png  (blade loadout)
  assets/sprites/player/recycler_player_multiaction_8dir.png          (blade loadout)
  assets/sprites/player/r17_wasteland_8dir_actions.png                (blade loadout)
  assets/sprites/player/r17_loadout_blade.png
  assets/sprites/player/r17_loadout_heavy.png
  assets/sprites/player/r17_loadout_rifle.png
  assets/sprites/player/actions/<action>.png + frames/<action>/dir_<d>/frame_<f>.png (blade)
  docs/player_split_frame_diagnostic.png

Action semantics:
  idle, walk, shoot, draw_sword (= backhand rising slash, 2nd combo hit),
  slash (= forehand diagonal slash, 1st combo hit), swap_tool, interact, hit, dead
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
PLAYER = ROOT / "assets" / "sprites" / "player"
DOCS = ROOT / "docs"

FRAME_W, FRAME_H = 112, 128
FRAMES = 8
DIRS = 8
ACTIONS = ["idle", "walk", "shoot", "draw_sword", "slash", "swap_tool", "interact", "hit", "dead"]
DIR_ANGLES = [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]
DIR_NAMES = ["right", "down_right", "down", "down_left", "left", "up_left", "up", "up_right"]
LOADOUTS = ["blade", "heavy", "rifle"]

# Camera: orthographic, elevated 40 degrees, looking north.
ELEV = math.radians(40.0)
SIN_E, COS_E = math.sin(ELEV), math.cos(ELEV)
ORIGIN_X, ORIGIN_Y = 56.0, 112.0
LIGHT = np.array([-0.55, -0.50, 0.68])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
OUTLINE = (18, 14, 22, 255)

# Palette: dark, mid, light, highlight
# Direct faithful translation of User Reference Picture 2 (Crusader Knight Automaton):
# - Iconic Crusader Greathelm (cylindrical bucket helm with bold golden cross faceplate)
# - Slate/steel blue-grey knight plate with rich heraldic gold border trim
# - Heavy rounded golden-rimmed pauldrons and gilded gorget collar
# - Broad plate waist belt with gold buckle and segmented fauld hip armor
# - Massive broad-bladed greatsword with wide gold crossguard and knight heater shield
# - Flowing crimson knightly cape draped behind shoulders
PAL: dict[str, list[tuple[int, int, int]]] = {
    "plate":   [(38, 46, 62), (66, 82, 108), (112, 134, 168), (176, 200, 234)], # Slate blue-grey knight steel
    "gold":    [(96, 62, 20), (172, 118, 34), (232, 172, 50), (255, 230, 120)],  # Rich medieval chivalric gold trim
    "joint":   [(20, 22, 28), (38, 42, 52), (60, 66, 80), (90, 98, 116)],       # Internal mechanical chassis & servos
    "cape":    [(72, 16, 26), (130, 24, 38), (192, 42, 58), (236, 80, 96)],     # Noble crusader crimson cape
    "boot":    [(32, 38, 52), (58, 72, 96), (102, 122, 154), (164, 188, 222)],  # Armored greaves & sabatons
    "pack":    [(38, 42, 50), (64, 70, 80), (98, 106, 118), (142, 150, 164)],   # Back armor plate / boiler
    "steel":   [(52, 62, 80), (104, 122, 150), (170, 192, 224), (240, 250, 255)],# Broad greatsword blade steel
    "shield":  [(30, 36, 48), (52, 64, 84), (88, 106, 134), (140, 162, 194)],  # Knight heater shield face
    "grip":    [(40, 24, 18), (70, 42, 28), (100, 64, 42), (132, 88, 60)],      # Leather hilt wrap
    "wood":    [(54, 36, 22), (92, 60, 36), (134, 90, 52), (172, 120, 74)],     # Heavy poleaxe shaft / stock
    "gun":     [(26, 30, 38), (48, 54, 66), (76, 86, 102), (114, 126, 144)],    # Mechanical clockwork
    "iron":    [(34, 32, 36), (62, 58, 66), (96, 90, 100), (134, 128, 138)],   # Cast flanged hammer head
    "visor":   [(18, 18, 22), (24, 26, 32), (75, 230, 255), (225, 255, 255)],  # Dark T-slit with glowing cyan optic
    "cyan":    [(65, 215, 240)] * 3 + [(200, 255, 255)],                         # Core energy jewel
    "ember":   [(255, 125, 30)] * 3 + [(255, 220, 100)],                         # Back steam booster glow
    "flash":   [(255, 230, 110)] * 3 + [(255, 255, 235)],                        # Strike spark / muzzle flash
    "edge":    [(145, 238, 255)] * 3 + [(245, 255, 255)],                        # Greatsword cutting edge
}
EMISSIVE = {"cyan", "ember", "flash", "edge"}


# --------------------------------------------------------------------------- math
def v(*a: float) -> np.ndarray:
    return np.array(a, dtype=np.float64)


def norm(a: np.ndarray) -> np.ndarray:
    n = np.linalg.norm(a)
    return a / n if n > 1e-9 else a


def lerp(a, b, t):
    return a + (b - a) * t


def smooth(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return t * t * (3.0 - 2.0 * t)


def ease_out(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return 1.0 - (1.0 - t) ** 3


def ease_in_out(t: float) -> float:
    t = min(1.0, max(0.0, t))
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def seg(t: float, a: float, b: float) -> float:
    return min(1.0, max(0.0, (t - a) / max(1e-6, b - a)))


def yaw_rot(vec: np.ndarray, deg: float) -> np.ndarray:
    """Rotate local (f, r, z) vector around z; positive turns forward toward right."""
    a = math.radians(deg)
    f, r, z = vec
    return v(f * math.cos(a) - r * math.sin(a), f * math.sin(a) + r * math.cos(a), z)


def pitch_rot(vec: np.ndarray, deg: float, pivot: np.ndarray) -> np.ndarray:
    """Lean around the local right axis; positive leans the top forward."""
    a = math.radians(deg)
    p = vec - pivot
    f, r, z = p
    return pivot + v(f * math.cos(a) + z * math.sin(a), r, -f * math.sin(a) + z * math.cos(a))


def ik(root: np.ndarray, target: np.ndarray, la: float, lb: float, hint: np.ndarray) -> np.ndarray:
    d_vec = target - root
    d = float(np.linalg.norm(d_vec))
    d = min(max(d, abs(la - lb) + 0.01), la + lb - 0.01)
    dirv = norm(d_vec)
    along = (la * la - lb * lb + d * d) / (2.0 * d)
    h = math.sqrt(max(0.0, la * la - along * along))
    perp = hint - dirv * float(np.dot(hint, dirv))
    perp = norm(perp) if np.linalg.norm(perp) > 1e-6 else v(0, 0, 1)
    return root + dirv * along + perp * h


def reach(root: np.ndarray, target: np.ndarray, max_len: float) -> np.ndarray:
    d = target - root
    n = float(np.linalg.norm(d))
    if n > max_len:
        return root + d / n * max_len
    return target


# --------------------------------------------------------------------------- pose
class Pose:
    def __init__(self) -> None:
        self.root = v(0, 0, 0)          # pelvis ground offset (f, r, z)
        self.hip_h = 44.0
        self.lean = 0.0                 # torso pitch deg
        self.yaw = 0.0                  # torso yaw deg
        self.hip_yaw = 0.0
        self.head_yaw = 0.0
        self.head_pitch = 0.0
        self.foot_l = v(0, -6, 0)
        self.foot_r = v(0, 6, 0)
        self.hand_l: np.ndarray | None = None
        self.hand_r: np.ndarray | None = None
        self.weapon = "none"            # blade | heavy | rifle | none
        self.wdir = v(1, 0, 0)          # weapon forward (local)
        self.wup = v(0, 0, 1)
        self.flash = 0.0                # muzzle flash size
        self.scan = False
        self.hurt = 0.0
        self.lying = 0.0                # 0..1 for death collapse
        self.cape_swing = 0.0


def body_frame(p: Pose):
    pelvis = p.root + v(0, 0, p.hip_h)
    chest = pitch_rot(pelvis + v(0, 0, 24), p.lean, pelvis)
    neck = pitch_rot(pelvis + v(0, 0, 34), p.lean, pelvis)
    head = pitch_rot(pelvis + v(0, 0, 47), p.lean + p.head_pitch, pelvis)
    sh_l = pitch_rot(pelvis + yaw_rot(v(0, -14, 27), p.yaw), p.lean, pelvis)
    sh_r = pitch_rot(pelvis + yaw_rot(v(0, 14, 27), p.yaw), p.lean, pelvis)
    hip_l = pelvis + yaw_rot(v(0, -7, -2), p.hip_yaw)
    hip_r = pelvis + yaw_rot(v(0, 7, -2), p.hip_yaw)
    return pelvis, chest, neck, head, sh_l, sh_r, hip_l, hip_r


def apply_lying(points: dict, p: Pose) -> dict:
    """Death collapse: rotate the whole figure backwards around the feet line."""
    if p.lying <= 0.0:
        return points
    ang = -78.0 * ease_in_out(p.lying)
    pivot = v(-2, 0, 0)
    out = {}
    for k, val in points.items():
        if isinstance(val, np.ndarray) and val.shape == (3,):
            q = pitch_rot(val, ang, pivot)
            q[2] = max(q[2], 3.0) if k not in ("foot_l", "foot_r", "toe_l", "toe_r") else q[2]
            out[k] = q
        else:
            out[k] = val
    return out


# --------------------------------------------------------------------------- actions
def carry_pose(p: Pose, loadout: str, sway: float = 0.0) -> None:
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    if loadout == "rifle":
        p.weapon = "rifle"
        grip = pelvis + yaw_rot(v(8, 9, 12 + sway), p.yaw * 0.5)
        p.wdir = norm(yaw_rot(v(1.0, -0.25, -0.28), p.yaw * 0.5))
        p.wup = v(0, 0, 1)
        p.hand_r = grip
        p.hand_l = grip + p.wdir * 13
    else:
        p.weapon = "heavy" if loadout == "heavy" else "blade"
        p.hand_r = sh_r + yaw_rot(v(5 + sway, 4, -22), p.yaw)
        if loadout == "heavy":
            p.wdir = norm(yaw_rot(v(-0.35, 0.25, 1.0), p.yaw))   # hammer resting on shoulder
            p.hand_r = sh_r + yaw_rot(v(6, 2, -12), p.yaw)
        else:
            p.wdir = norm(yaw_rot(v(0.9, 0.18, -0.55), p.yaw))
        p.hand_l = sh_l + yaw_rot(v(2 - sway, -3, -23), p.yaw)


def pose_idle(s: float, loadout: str) -> Pose:
    p = Pose()
    b = math.sin(s * math.tau)
    p.root = v(0, 0, 0.9 * b)
    p.head_pitch = 1.5 * b
    p.foot_l = v(1, -7, 0)
    p.foot_r = v(-1, 7, 0)
    p.cape_swing = 0.6 * b
    carry_pose(p, loadout, sway=0.8 * b)
    return p


def pose_walk(s: float, loadout: str) -> Pose:
    p = Pose()
    ph = s * math.tau
    stride = 9.0
    p.root = v(0, 0, 1.4 * math.cos(2 * ph) - 0.6)
    p.lean = 6.0
    p.yaw = -7.0 * math.sin(ph)
    p.hip_yaw = 7.0 * math.sin(ph)
    p.foot_l = v(stride * math.sin(ph), -6.5, max(0.0, math.cos(ph)) * 5.0)
    p.foot_r = v(-stride * math.sin(ph), 6.5, max(0.0, -math.cos(ph)) * 5.0)
    p.cape_swing = -2.5 + 1.2 * math.sin(2 * ph)
    carry_pose(p, loadout, sway=3.0 * math.sin(ph))
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    if loadout != "rifle":
        p.hand_l = sh_l + yaw_rot(v(-8.0 * math.sin(ph), -4, -22), p.yaw)
    return p


def pose_shoot(s: float, loadout: str) -> Pose:
    p = Pose()
    k = int(round(s * 7))
    recoil = [0.0, 3.2, 2.0, 0.9, 0.3, 0.0, 0.0, 0.0][k]
    raise_t = ease_out(seg(s, 0.0, 0.08)) if k > 0 else 0.85
    p.foot_l = v(5, -7, 0)
    p.foot_r = v(-4, 7, 0)
    p.yaw = -12.0
    p.lean = 4.0 - recoil * 1.5
    p.root = v(-recoil * 0.6, 0, -1.0)
    p.weapon = "rifle"
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    aim = v(1, 0, 0)
    grip = sh_r + v(7 - recoil, -4, -4 - 6 * (1 - raise_t)) + v(0, 0, recoil * 0.4)
    p.wdir = norm(aim + v(0, 0, 0.02 + recoil * 0.05))
    p.wup = v(0, 0, 1)
    p.hand_r = grip
    p.hand_l = grip + p.wdir * 13
    p.flash = [0.0, 1.0, 0.45, 0.0, 0.0, 0.0, 0.0, 0.0][k]
    p.head_pitch = 3.0
    return p


def swing_pose(s: float, loadout: str, forehand: bool) -> Pose:
    """Melee swing. The hand travels an arc around the chest; the weapon trails it."""
    p = Pose()
    heavy = loadout == "heavy"
    if loadout == "rifle":
        loadout = "blade"   # rifle loadout: quick bayonet-style slash with the rifle butt? keep blade arc
    p.weapon = "heavy" if heavy else "blade"
    # timeline: 0-0.16 wind-up, 0.16-0.52 strike, 0.52-0.72 follow-through, 0.72-1 recover
    wind = ease_out(seg(s, 0.0, 0.16))
    strike = ease_in_out(seg(s, 0.16, 0.52))
    follow = ease_out(seg(s, 0.52, 0.72))
    recover = smooth(seg(s, 0.72, 1.0))
    if forehand:
        a_guard, a_wind, a_hit, a_follow = 40.0, 118.0, -70.0, -96.0
        h_guard, h_wind, h_hit, h_follow = -8.0, 16.0, -6.0, -12.0
    else:
        a_guard, a_wind, a_hit, a_follow = 40.0, -64.0, 104.0, 128.0
        h_guard, h_wind, h_hit, h_follow = -8.0, -14.0, 14.0, 20.0
    ang = lerp(a_guard, a_wind, wind)
    ang = lerp(ang, a_hit, strike)
    ang = lerp(ang, a_follow, follow)
    ang = lerp(ang, a_guard, recover)
    hgt = lerp(h_guard, h_wind, wind)
    hgt = lerp(hgt, h_hit, strike)
    hgt = lerp(hgt, h_follow, follow)
    hgt = lerp(hgt, h_guard, recover)

    lunge = 7.0 * (strike - recover * 1.0) if s < 1.0 else 0.0
    lunge = max(0.0, min(7.0, lunge + 7.0 * follow * (1 - recover)))
    p.root = v(lunge * 0.8 - 2.0 * wind * (1 - strike), 0, -2.0 * strike * (1 - recover))
    p.yaw = ang * 0.32
    p.hip_yaw = ang * 0.12
    p.lean = 10.0 * strike * (1 - recover) - 4.0 * wind * (1 - strike)
    p.foot_l = v(4 + 8 * strike * (1 - recover), -7, 2.5 * math.sin(math.pi * seg(s, 0.16, 0.45)))
    p.foot_r = v(-4 - 3 * strike * (1 - recover), 7.5, 0)
    p.cape_swing = -3.0 * strike * (1 - recover)

    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    center = chest + v(2, 3, 0)
    rad = 21.0
    hand_dir = yaw_rot(v(1, 0, 0), ang)
    p.hand_r = reach(sh_r, center + hand_dir * rad + v(0, 0, hgt), 27.5)
    # Weapon points outward along the swing with a trailing lag + tilt
    lag = 26.0 * (1 if forehand else -1) * (strike * (1 - follow))
    out_dir = yaw_rot(v(1, 0, 0), ang + lag)
    tilt = 0.55 if wind > 0.5 and strike < 0.2 else (-0.18 if forehand else 0.28)
    if s < 0.05 or recover > 0.95:
        out_dir = yaw_rot(v(0.9, 0.18, 0), 0)
        tilt = -0.55
    p.wdir = norm(out_dir + v(0, 0, tilt))
    p.wup = v(0, 0, 1)
    p.hand_l = sh_l + yaw_rot(v(6 - 6 * strike, -6, -18 + 6 * strike), p.yaw)
    p.head_yaw = ang * 0.12
    return p


def pose_swap(s: float, loadout: str) -> Pose:
    p = pose_idle(0.0, loadout)
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    t = math.sin(math.pi * s)
    behind = sh_r + v(-10, -2, 8)
    p.hand_r = lerp(p.hand_r, behind, t)
    if p.weapon in ("blade", "heavy"):
        p.wdir = norm(lerp(p.wdir, v(-0.2, -0.3, 1.0), t))
    else:
        p.wdir = norm(lerp(p.wdir, v(0.1, -0.2, 1.0), t))
        p.hand_l = lerp(p.hand_l, sh_l + v(4, 2, -20), t)
    p.head_yaw = 18 * t
    p.yaw = -8 * t
    return p


def pose_interact(s: float, loadout: str) -> Pose:
    p = Pose()
    kneel = math.sin(math.pi * min(1.0, s * 1.15))
    p.root = v(2 * kneel, 0, -12 * kneel)
    p.lean = 18 * kneel
    p.foot_l = v(8 * kneel, -7, 0)
    p.foot_r = v(-6 * kneel, 7, 0)
    carry_pose(p, loadout)
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    p.hand_l = sh_l + v(14 * kneel + 2, 2, -16 - 6 * kneel)
    p.scan = 0.25 < s < 0.85
    p.head_pitch = 14 * kneel
    return p


def pose_hit(s: float, loadout: str) -> Pose:
    p = Pose()
    k = int(round(s * 7))
    jolt = [1.0, 0.9, 0.7, 0.5, 0.32, 0.18, 0.08, 0.0][k]
    p.root = v(-5 * jolt, 0, -1.5 * jolt)
    p.lean = -16 * jolt
    p.head_pitch = -10 * jolt
    p.foot_l = v(-2 * jolt, -7, 0)
    p.foot_r = v(-6 * jolt, 7, 0)
    p.cape_swing = 3 * jolt
    carry_pose(p, loadout)
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    p.hand_l = sh_l + v(-2, -9 - 4 * jolt, -16 + 6 * jolt)
    p.hurt = [0.7, 0.55, 0.4, 0.25, 0.12, 0.05, 0.0, 0.0][k]
    return p


def pose_dead(s: float, loadout: str) -> Pose:
    p = Pose()
    t = ease_in_out(seg(s, 0.0, 0.85))
    p.root = v(-6 * t, 0, -8 * t)
    p.foot_l = v(6 * t, -7, 0)
    p.foot_r = v(9 * t, 7, 0)
    p.head_pitch = -12 * t
    p.lean = -10 * t
    carry_pose(p, loadout)
    pelvis, chest, neck, head, sh_l, sh_r, *_ = body_frame(p)
    p.hand_l = sh_l + v(-2, -12 * t - 2, -16)
    p.hand_r = sh_r + v(-2, 12 * t + 2, -16)
    p.wdir = norm(v(0.3, 1.0, -0.2 * (1 - t)))
    p.lying = t
    return p


def make_pose(action: str, s: float, loadout: str) -> Pose:
    if action == "idle":
        return pose_idle(s, loadout)
    if action == "walk":
        return pose_walk(s, loadout)
    if action == "shoot":
        return pose_shoot(s, loadout)
    if action == "slash":
        return swing_pose(s, loadout, forehand=True)
    if action == "draw_sword":
        return swing_pose(s, loadout, forehand=False)
    if action == "swap_tool":
        return pose_swap(s, loadout)
    if action == "interact":
        return pose_interact(s, loadout)
    if action == "hit":
        return pose_hit(s, loadout)
    return pose_dead(s, loadout)


# --------------------------------------------------------------------------- model
Part = tuple  # (a, b, ra, rb, material)


def weapon_parts(p: Pose) -> tuple[list[Part], np.ndarray | None, np.ndarray | None]:
    parts: list[Part] = []
    hand = p.hand_r
    if hand is None or p.weapon == "none":
        return parts, None, None
    d = norm(p.wdir)
    side = np.cross(d, v(0, 0, 1))
    if np.linalg.norm(side) < 1e-3:
        side = v(0, 1, 0)
    side = norm(side)
    up = norm(np.cross(side, d))
    tip = None
    base = None
    if p.weapon == "blade":
        # Massive Knightly Broad Greatsword (Direct Picture 2 translation)
        # Thick cross-wrapped dark grip & golden faceted pommel
        parts.append((hand - d * 6.5, hand + d * 1.5, 2.0, 2.0, "grip"))
        parts.append((hand - d * 7.5, hand - d * 7.5, 3.4, 3.4, "gold"))
        # Imposing wide golden crossguard quillons
        parts.append((hand + d * 2.4 - side * 7.0, hand + d * 2.4 + side * 7.0, 2.2, 2.2, "gold"))
        parts.append((hand + d * 2.4 - side * 7.5, hand + d * 2.4 - side * 7.5, 3.0, 3.0, "gold"))
        parts.append((hand + d * 2.4 + side * 7.5, hand + d * 2.4 + side * 7.5, 3.0, 3.0, "gold"))
        base = hand + d * 3.8
        tip = hand + d * 35.0
        # Very broad, thick double-edged steel blade with central ridge
        parts.append((base, hand + d * 26.0, 3.8, 3.2, "steel"))
        parts.append((hand + d * 26.0, tip, 3.2, 0.8, "steel"))
        # High-frequency vibro cutting edge
        parts.append((base + up * 1.4, tip + up * 0.4, 0.8, 0.5, "edge"))
    elif p.weapon == "heavy":
        # Medieval Knightly Flanged War Hammer / Poleaxe
        parts.append((hand - d * 7.5, hand + d * 24.0, 2.2, 2.2, "wood"))
        parts.append((hand - d * 6.5, hand - d * 6.5, 3.0, 3.0, "gold"))
        parts.append((hand + d * 23.0, hand + d * 23.0, 3.2, 3.2, "gold"))
        head = hand + d * 24.5
        # Heavy flanged hammer head
        parts.append((head - up * 7.0, head + up * 7.0, 6.2, 6.2, "iron"))
        # Rear steam booster nozzle
        parts.append((head - d * 3.4, head - d * 3.4, 3.2, 3.2, "ember"))
        # Front armor-piercing thrusting spike
        parts.append((head + d * 3.0, head + d * 9.0, 1.8, 0.7, "steel"))
        base = hand + d * 15.0
        tip = head + up * 7.5
    elif p.weapon == "rifle":
        # Medieval Mechanical Arbalest / Crossbow-Rifle
        parts.append((hand - d * 10.5 - up * 1.4, hand - d * 1.5, 3.2, 2.5, "wood"))
        parts.append((hand - d * 2.0, hand + d * 13.0, 3.0, 2.8, "gun"))
        parts.append((hand + d * 13.0, hand + d * 25.0, 1.8, 1.8, "gun"))
        # Broad steel bow prod arms
        parts.append((hand + d * 20.0 - side * 10.5, hand + d * 20.0 + side * 10.5, 2.0, 2.0, "steel"))
        parts.append((hand + d * 20.0 - side * 11.0, hand + d * 20.0 - side * 11.0, 2.6, 2.6, "gold"))
        parts.append((hand + d * 20.0 + side * 11.0, hand + d * 20.0 + side * 11.0, 2.6, 2.6, "gold"))
        # Glowing cyan energy bolt track
        parts.append((hand + d * 6.0 + up * 3.4, hand + d * 12.0 + up * 3.4, 1.4, 1.4, "cyan"))
        muzzle = hand + d * 26.5
        if p.flash > 0:
            f = p.flash
            parts.append((muzzle + d * 1.0, muzzle + d * (1 + 7 * f), 3.8 * f + 0.8, 1.4 * f + 0.5, "flash"))
            parts.append((muzzle + d * 2.0 - side * 4.0 * f, muzzle + d * 2.0 + side * 4.0 * f, 1.6 * f + 0.4, 1.6 * f + 0.4, "flash"))
        base, tip = hand, muzzle
    return parts, base, tip


def body_parts(p: Pose) -> list[Part]:
    pelvis, chest, neck, head, sh_l, sh_r, hip_l, hip_r = body_frame(p)
    up = pitch_rot(v(0, 0, 1), p.lean, v(0, 0, 0))
    back = pitch_rot(v(-1, 0, 0), p.lean, v(0, 0, 0))
    fwd = -back

    foot_l = p.foot_l + v(0, 0, 3.5)
    foot_r = p.foot_r + v(0, 0, 3.5)
    knee_l = ik(hip_l, foot_l, 21.0, 20.0, v(1, -0.15, 0))
    knee_r = ik(hip_r, foot_r, 21.0, 20.0, v(1, 0.15, 0))
    hand_l = p.hand_l if p.hand_l is not None else sh_l + v(2, -3, -24)
    hand_r = p.hand_r if p.hand_r is not None else sh_r + v(2, 3, -24)
    hand_l = reach(sh_l, hand_l, 27.5)
    hand_r = reach(sh_r, hand_r, 27.5)
    elbow_l = ik(sh_l, hand_l, 14.5, 13.5, v(-0.6, -0.8, -0.3))
    elbow_r = ik(sh_r, hand_r, 14.5, 13.5, v(-0.6, 0.8, -0.3))
    toe_l = foot_l + yaw_rot(v(6.5, 0, -1.0), p.hip_yaw)
    toe_r = foot_r + yaw_rot(v(6.5, 0, -1.0), p.hip_yaw)

    pts = dict(pelvis=pelvis, chest=chest, neck=neck, head=head, sh_l=sh_l, sh_r=sh_r,
               hip_l=hip_l, hip_r=hip_r, knee_l=knee_l, knee_r=knee_r, foot_l=foot_l, foot_r=foot_r,
               toe_l=toe_l, toe_r=toe_r, elbow_l=elbow_l, elbow_r=elbow_r, hand_l=hand_l, hand_r=hand_r)
    pts = apply_lying(pts, p)
    g = pts
    hy = math.radians(p.head_yaw)
    head_f = yaw_rot(fwd, p.head_yaw)
    head_r = yaw_rot(v(0, 1, 0), p.head_yaw)
    if p.lying > 0:
        head_f = pitch_rot(head_f, -78 * ease_in_out(p.lying), v(0, 0, 0))
        up = pitch_rot(up, -78 * ease_in_out(p.lying), v(0, 0, 0))
        back = pitch_rot(back, -78 * ease_in_out(p.lying), v(0, 0, 0))
    _ = hy

    parts: list[Part] = []

    # 1. Legs & Sabatons (Solid chunky greaves & pointed boots)
    for side in ("l", "r"):
        # Thigh plate & hydraulic chassis
        parts.append((g[f"hip_{side}"], g[f"knee_{side}"], 6.2, 5.4, "joint"))
        parts.append((g[f"hip_{side}"] + fwd * 2.0, g[f"knee_{side}"] + fwd * 2.0, 5.6, 5.0, "plate"))
        # Knee poleyn (armored roundel cup with gold rivet)
        parts.append((g[f"knee_{side}"], g[f"knee_{side}"] + up * 0.5, 5.5, 5.5, "plate"))
        parts.append((g[f"knee_{side}"] + fwd * 4.5, g[f"knee_{side}"] + fwd * 4.5, 2.6, 2.6, "gold"))
        # Chunky shin greave
        parts.append((g[f"knee_{side}"], g[f"foot_{side}"], 5.6, 5.0, "plate"))
        # Wide sabaton boot with gold toe cap
        parts.append((g[f"foot_{side}"] + v(0, 0, 2.5), g[f"foot_{side}"] - v(0, 0, 0.5), 5.6, 5.6, "boot"))
        parts.append((g[f"foot_{side}"], g[f"toe_{side}"], 5.6, 4.4, "boot"))
        parts.append((g[f"toe_{side}"], g[f"toe_{side}"], 3.8, 3.8, "gold"))

    # 2. Pelvis, Waist Belt & Segmented Fauld
    parts.append((g["pelvis"] + up * -2, g["pelvis"] + up * 5, 10.5, 11.0, "joint"))
    # Broad plate belt with thick gold trim & rectangular buckle
    parts.append((g["pelvis"] + up * 2.5, g["pelvis"] + up * 5.0, 11.2, 11.2, "gold"))
    parts.append((g["pelvis"] + up * 3.8 + fwd * 9.2, g["pelvis"] + up * 3.8 + fwd * 9.2, 3.8, 3.8, "gold"))
    # Segmented fauld hip armor plates on sides
    for sgn in (-1, 1):
        fauld_pos = g["pelvis"] + head_r * (9.5 * sgn)
        parts.append((fauld_pos + up * 2.0, fauld_pos - up * 3.0, 5.2, 4.6, "plate"))
        parts.append((fauld_pos - up * 3.0, fauld_pos - up * 3.0, 4.8, 4.8, "gold"))

    # 3. Flowing Crimson Knight Cape (Scalloped cloth hanging from behind shoulders)
    cape_top = g["chest"] + back * 7.5 + up * 5.0
    cape_bot = g["pelvis"] + back * (9.5 - p.cape_swing * 1.0) - up * 16.0
    parts.append((cape_top, cape_bot, 12.0, 10.5, "cape"))
    # Left & Right cape drape folds
    for sgn in (-1, 1):
        parts.append((cape_top + head_r * (9.0 * sgn), cape_bot + head_r * (8.0 * sgn), 5.2, 4.5, "cape"))

    # 4. Heavy Plate Cuirass & Breastplate
    parts.append((g["pelvis"] + up * 5, g["chest"], 11.5, 13.8, "plate"))
    # Center ridge & gilded crest jewel
    parts.append((g["chest"] + fwd * 6.5 + up * 2.0, g["chest"] + fwd * 6.5 + up * 2.0, 3.8, 3.8, "cyan"))
    parts.append((g["chest"] + fwd * 6.0 + up * 2.0, g["chest"] + fwd * 6.0 + up * 2.0, 5.0, 5.0, "gold"))

    # Back armor plate / boiler casing
    pack_c = g["chest"] + back * 10.0 - up * 2.0
    parts.append((pack_c - up * 6.5, pack_c + up * 6.0, 8.8, 8.8, "pack"))
    parts.append((pack_c + back * 7.0 - up * 1.5, pack_c + back * 7.0 + up * 1.5, 3.2, 3.2, "ember"))
    parts.append((pack_c + up * 7.5 + v(0, -3.8, 0), pack_c + up * 16.5 + v(0, -4.2, 0), 1.8, 1.4, "gold"))
    parts.append((pack_c + up * 7.5 + v(0, 3.8, 0), pack_c + up * 16.5 + v(0, 4.2, 0), 1.8, 1.4, "gold"))

    # 5. Heavy Rounded Pauldrons with Thick Gold Border (Direct Picture 2 translation)
    for sgn, side in ((-1, "l"), (1, "r")):
        sh_pos = g[f"sh_{side}"]
        # Main heavy curved pauldron dome
        parts.append((sh_pos - up * 1.2, sh_pos + up * 4.2 + head_r * (2.8 * sgn), 9.2, 8.8, "plate"))
        # Prominent thick golden border rim
        parts.append((sh_pos + up * 4.2 + head_r * (2.8 * sgn), sh_pos + up * 5.2 + head_r * (3.4 * sgn), 9.2, 9.2, "gold"))
        parts.append((sh_pos - up * 1.5 + head_r * (2.4 * sgn), sh_pos - up * 1.5 + head_r * (2.4 * sgn), 8.8, 8.8, "gold"))

    # Neck Gorget Collar (Thick golden ring collar around neck)
    parts.append((g["neck"] - up * 1.2 + fwd * 1.0, g["neck"] + up * 1.8, 8.8, 8.2, "plate"))
    parts.append((g["neck"] + up * 2.0, g["neck"] + up * 2.0, 8.8, 8.8, "gold"))

    # 6. Crusader Greathelm / Bucket Helmet with Golden Cross (Direct Picture 2 translation)
    hc = g["head"]
    # Main cylindrical barrel / bucket helmet dome
    parts.append((hc - up * 3.5, hc + up * 7.5, 11.8, 11.5, "plate"))
    # Flat/beveled cylindrical top crown
    parts.append((hc + up * 7.5, hc + up * 8.2, 10.8, 10.8, "plate"))

    # THE ICONIC GOLDEN CROSS FACEPLATE (十字面甲金框):
    # 1. Horizontal cross bar across the brow/eyes
    parts.append((hc + head_f * 9.6 - head_r * 8.2 + up * 2.2, hc + head_f * 9.6 + head_r * 8.2 + up * 2.2, 2.8, 2.8, "gold"))
    # 2. Vertical cross bar running from top crown down to chin
    parts.append((hc + head_f * 9.8 + up * 8.0, hc + head_f * 9.8 - up * 4.5, 2.8, 2.8, "gold"))

    # T-slit eye openings on both sides of the vertical cross bar
    for sgn in (-1, 1):
        eye_inner = hc + head_f * 9.2 + head_r * (1.8 * sgn) + up * 0.4
        eye_outer = hc + head_f * 9.2 + head_r * (5.5 * sgn) + up * 0.4
        parts.append((eye_inner, eye_outer, 1.8, 1.8, "visor"))

    # Lower breathing slots on the faceplate
    for sgn in (-1, 1):
        parts.append((hc + head_f * 8.8 + head_r * (4.2 * sgn) - up * 2.0, hc + head_f * 8.8 + head_r * (4.2 * sgn) - up * 4.5, 1.2, 1.2, "joint"))

    # Side ear bolts
    for sgn in (-1, 1):
        parts.append((hc + head_r * 11.8 * sgn, hc + head_r * 11.8 * sgn, 3.2, 3.2, "gold"))

    # 7. Arms, Vambraces & Gauntlets
    for side in ("l", "r"):
        # Upper arm plate
        parts.append((g[f"sh_{side}"], g[f"elbow_{side}"], 5.2, 4.6, "joint"))
        parts.append((g[f"sh_{side}"] + fwd * 1.5, g[f"elbow_{side}"] + fwd * 1.5, 4.8, 4.2, "plate"))
        # Forearm vambrace with flared golden cuff
        parts.append((g[f"elbow_{side}"], g[f"hand_{side}"], 4.8, 4.4, "plate"))
        gauntlet_cuff = g[f"hand_{side}"] - (g[f"hand_{side}"] - g[f"elbow_{side}"]) * 0.22
        parts.append((gauntlet_cuff, gauntlet_cuff, 5.2, 5.2, "gold"))
        # Articulated gauntlet hand
        parts.append((g[f"hand_{side}"], g[f"hand_{side}"], 4.4, 4.4, "joint"))

    # 8. Knight Heater Shield on Left Arm (Direct Picture 2 translation)
    # When weapon is blade and not attacking (or in guard/walk/idle), left hand holds the heater shield!
    if p.weapon == "blade":
        shield_pos = g["hand_l"] + head_f * 2.0 - head_r * 3.5 + up * 1.0
        # Shield triangular plate
        parts.append((shield_pos - up * 7.5, shield_pos + up * 7.5, 8.2, 8.2, "shield"))
        # Golden shield border rim
        parts.append((shield_pos - up * 7.8, shield_pos + up * 7.8, 8.8, 8.8, "gold"))
        # Central golden cross / heraldic boss on shield
        parts.append((shield_pos + head_f * 2.0, shield_pos + head_f * 2.0, 3.0, 3.0, "gold"))

    if p.scan:
        parts.append((g["hand_l"] + fwd * 3, g["hand_l"] + fwd * 3, 2.8, 2.8, "cyan"))
    return parts


def to_world(local: np.ndarray, facing_deg: float) -> np.ndarray:
    a = math.radians(facing_deg)
    F = v(math.cos(a), math.sin(a), 0)
    R = v(-math.sin(a), math.cos(a), 0)
    return F * local[0] + R * local[1] + v(0, 0, 1) * local[2]


def project(w: np.ndarray) -> tuple[float, float, float]:
    sx = ORIGIN_X + w[0]
    sy = ORIGIN_Y + w[1] * SIN_E - w[2] * COS_E
    depth = w[1] * COS_E + w[2] * SIN_E
    return sx, sy, depth


SCREEN_RIGHT = v(1, 0, 0)
SCREEN_DOWN = v(0, SIN_E, -COS_E)
TOWARD_CAM = v(0, COS_E, SIN_E)


# --------------------------------------------------------------------------- render
def render(parts: list[Part], facing: float, hurt: float = 0.0) -> Image.Image:
    depth = np.full((FRAME_H, FRAME_W), -1e9)
    shade = np.zeros((FRAME_H, FRAME_W), dtype=np.int16)
    mat_id = np.full((FRAME_H, FRAME_W), -1, dtype=np.int16)
    mats = list(PAL.keys())
    yy, xx = np.mgrid[0:FRAME_H, 0:FRAME_W].astype(np.float64)
    xx += 0.5
    yy += 0.5

    for a, b, ra, rb, mat in parts:
        wa = to_world(a, facing)
        wb = to_world(b, facing)
        length = float(np.linalg.norm(wb - wa))
        n = max(1, int(math.ceil(length / max(0.45, min(ra, rb) * 0.45))))
        mi = mats.index(mat)
        for i in range(n + 1):
            t = i / n
            c = wa + (wb - wa) * t
            r = ra + (rb - ra) * t
            sx, sy, dc = project(c)
            x0, x1 = int(max(0, math.floor(sx - r))), int(min(FRAME_W, math.ceil(sx + r) + 1))
            y0, y1 = int(max(0, math.floor(sy - r))), int(min(FRAME_H, math.ceil(sy + r) + 1))
            if x0 >= x1 or y0 >= y1:
                continue
            dx = xx[y0:y1, x0:x1] - sx
            dy = yy[y0:y1, x0:x1] - sy
            d2 = dx * dx + dy * dy
            inside = d2 <= r * r
            if not inside.any():
                continue
            dz = np.sqrt(np.clip(r * r - d2, 0, None))
            dep = dc + dz
            sub_depth = depth[y0:y1, x0:x1]
            win = inside & (dep > sub_depth)
            if not win.any():
                continue
            nx, ny, nz = dx / r, dy / r, dz / r
            nw = (nx[..., None] * SCREEN_RIGHT + ny[..., None] * SCREEN_DOWN + nz[..., None] * TOWARD_CAM)
            lam = nw @ LIGHT
            band = np.where(lam < -0.15, 0, np.where(lam < 0.30, 1, np.where(lam < 0.72, 2, 3)))
            sub_depth[win] = dep[win]
            shade[y0:y1, x0:x1][win] = band[win]
            mat_id[y0:y1, x0:x1][win] = mi

    img = np.zeros((FRAME_H, FRAME_W, 4), dtype=np.uint8)
    filled = mat_id >= 0
    for mi, mat in enumerate(mats):
        m = mat_id == mi
        if not m.any():
            continue
        pal = PAL[mat]
        for bnd in range(4):
            mm = m & (shade == bnd)
            if mm.any():
                img[mm] = (*pal[bnd], 255)

    # inner depth-discontinuity lines (darken the farther pixel)
    dark = np.zeros_like(filled)
    for oy, ox in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        nd = np.roll(np.roll(depth, oy, axis=0), ox, axis=1)
        nm = np.roll(np.roll(mat_id, oy, axis=0), ox, axis=1)
        dark |= filled & (nm >= 0) & (nd - depth > 5.5) & (nm != mat_id)
    emissive_ids = [mats.index(m) for m in EMISSIVE]
    dark &= ~np.isin(mat_id, emissive_ids)
    img[dark, :3] = (img[dark, :3].astype(np.int32) * 45 // 100 + np.array(OUTLINE[:3]) * 55 // 100).astype(np.uint8)

    if hurt > 0:
        body = filled & ~np.isin(mat_id, emissive_ids)
        tint = np.array([255, 70, 60], dtype=np.float64)
        img[body, :3] = np.clip(img[body, :3] * (1 - hurt) + tint * hurt, 0, 255).astype(np.uint8)

    # outer outline
    alpha = filled
    grow = np.zeros_like(alpha)
    for oy, ox in ((0, 1), (1, 0), (0, -1), (-1, 0)):
        grow |= np.roll(np.roll(alpha, oy, axis=0), ox, axis=1)
    edge = grow & ~alpha
    edge[:, :1] = False
    edge[:, -1:] = False
    edge[:1, :] = False
    edge[-1:, :] = False
    img[edge] = OUTLINE
    return Image.fromarray(img, "RGBA")


def smear_layer(action: str, s: float, loadout: str, facing: float) -> Image.Image | None:
    """Motion smear generated from the blade's own swept path over the last frame interval."""
    if action not in ("slash", "draw_sword"):
        return None
    k = int(round(s * 7))
    if k not in (2, 3, 4):
        return None
    s0 = max(0.0, s - 1.0 / 7.0)
    layer = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer, "RGBA")
    steps = 8
    prev = None
    for i in range(steps + 1):
        ss = lerp(s0, s, i / steps)
        p = make_pose(action, ss, loadout)
        _, base, tip = weapon_parts(p)
        if base is None:
            continue
        b2 = project(to_world(base, facing))
        t2 = project(to_world(tip, facing))
        cur = ((b2[0], b2[1]), (t2[0], t2[1]))
        if prev is not None:
            age = i / steps
            col = (226, 250, 255, int(40 + 120 * age)) if loadout != "heavy" else (255, 214, 150, int(40 + 120 * age))
            draw.polygon([prev[0], prev[1], cur[1], cur[0]], fill=col)
        prev = cur
    return layer


def shadow_layer() -> Image.Image:
    layer = Image.new("RGBA", (FRAME_W, FRAME_H), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer, "RGBA")
    cx, cy = ORIGIN_X, ORIGIN_Y
    d.ellipse((cx - 22, cy - 6, cx + 22, cy + 6), fill=(10, 8, 12, 70))
    d.ellipse((cx - 15, cy - 4, cx + 15, cy + 4), fill=(10, 8, 12, 95))
    return layer


def render_frame(action: str, frame: int, direction: int, loadout: str) -> Image.Image:
    loop = action in ("idle", "walk")
    s = frame / FRAMES if loop else frame / (FRAMES - 1)
    p = make_pose(action, s, loadout)
    facing = DIR_ANGLES[direction]
    parts = body_parts(p)
    wparts, _, _ = weapon_parts(p)
    if p.lying > 0 and wparts:
        wparts = [(pitch_rot(a, -78 * ease_in_out(p.lying), v(-2, 0, 0)),
                   pitch_rot(b, -78 * ease_in_out(p.lying), v(-2, 0, 0)), ra, rb, m) for a, b, ra, rb, m in wparts]
        wparts = [(np.maximum(a, v(-99, -99, 2)), np.maximum(b, v(-99, -99, 2)), ra, rb, m) for a, b, ra, rb, m in wparts]
    sprite = render(parts + wparts, facing, p.hurt)
    canvas = shadow_layer()
    sm = smear_layer(action, s, loadout, facing)
    if sm is not None:
        canvas.alpha_composite(sm)
    canvas.alpha_composite(sprite)
    arr = np.array(canvas)
    arr[:, :2] = 0
    arr[:, FRAME_W - 2:] = 0
    arr[:1, :] = 0
    arr[FRAME_H - 1:, :] = 0
    return Image.fromarray(arr, "RGBA")


def build_loadout(loadout: str) -> tuple[Image.Image, dict]:
    atlas = Image.new("RGBA", (FRAME_W * FRAMES * len(ACTIONS), FRAME_H * DIRS), (0, 0, 0, 0))
    cells: dict = {}
    for ai, action in enumerate(ACTIONS):
        for d in range(DIRS):
            for f in range(FRAMES):
                img = render_frame(action, f, d, loadout)
                cells[(action, d, f)] = img
                atlas.alpha_composite(img, ((ai * FRAMES + f) * FRAME_W, d * FRAME_H))
    return atlas, cells


def main() -> None:
    PLAYER.mkdir(parents=True, exist_ok=True)
    (PLAYER / "actions").mkdir(exist_ok=True)
    blade_cells = None
    for loadout in LOADOUTS:
        atlas, cells = build_loadout(loadout)
        atlas.save(PLAYER / f"r17_loadout_{loadout}.png")
        if loadout == "blade":
            blade_cells = cells
            for name in ("recycler_player_multiaction_8dir_preview.png", "recycler_player_multiaction_8dir.png", "r17_wasteland_8dir_actions.png"):
                atlas.save(PLAYER / name)
            DOCS.mkdir(exist_ok=True)
            atlas.save(DOCS / "recycler_player_multiaction_8dir_preview.png")
        print(f"[R17_RIG] rendered loadout '{loadout}'")

    assert blade_cells is not None
    for ai, action in enumerate(ACTIONS):
        sheet = Image.new("RGBA", (FRAME_W * FRAMES, FRAME_H * DIRS), (0, 0, 0, 0))
        for d in range(DIRS):
            folder = PLAYER / "frames" / action / f"dir_{d}"
            folder.mkdir(parents=True, exist_ok=True)
            for f in range(FRAMES):
                img = blade_cells[(action, d, f)]
                img.save(folder / f"frame_{f}.png")
                sheet.alpha_composite(img, (f * FRAME_W, d * FRAME_H))
        sheet.save(PLAYER / "actions" / f"{action}.png")
        if action == "walk":
            sheet.save(PLAYER / "recycler_player_8dir.png")

    # diagnostic contact sheet on a wasteland-ground colour
    rows = [
        ("blade", "walk", [1, 2, 3, 4, 5, 6, 7, 0], 1),
        ("blade", "slash", list(range(8)), 1),
        ("blade", "draw_sword", list(range(8)), 3),
        ("rifle", "shoot", list(range(8)), 0),
        ("heavy", "slash", list(range(8)), 2),
        ("blade", "idle", [0] * 8, None),
    ]
    sc = 2
    sheet = Image.new("RGBA", (FRAME_W * 8 * sc, FRAME_H * len(rows) * sc), (62, 56, 46, 255))
    for ri, (lo, act, frames, d) in enumerate(rows):
        for ci, f in enumerate(frames):
            dd = ci if d is None else d
            img = render_frame(act, f, dd, lo).resize((FRAME_W * sc, FRAME_H * sc), Image.Resampling.NEAREST)
            sheet.alpha_composite(img, (ci * FRAME_W * sc, ri * FRAME_H * sc))
    sheet.save(DOCS / "player_split_frame_diagnostic.png")
    print("[R17_RIG] done: 3 loadouts x 576 frames, diagnostic -> docs/player_split_frame_diagnostic.png")


if __name__ == "__main__":
    main()
