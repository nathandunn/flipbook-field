"""Costumes and the backs of heads, drawn in pen at build time.

The heads are Nathan's drawings; nobody drew the bodies, so this draws them in
the same idiom - one pen, paper white, a wobble in every line - and one costume
per class: the CEO's suit, the engineer's plaid, IT's hoodie and lanyard, HR's
blazer and badge, marketing's turtleneck and scarf, sales' rolled sleeves and
loosened tie, legal's waistcoat and bow tie, the intern's sticker and backpack.
Each part is drawn twice, front and back, so a figure reads from any side.

The back of every head is inferred from its front: the silhouette mirrored,
the hair kept (whatever ink lies outside the middle of the head, where the
features are), the face dropped, the crown hatched, the paper edge inked.

Outputs, all RGBA:
    bodies/<role>_torso_f.png  bodies/<role>_torso_b.png   128 x 160
    bodies/<role>_arm.png                                     48 x 160
    bodies/<role>_leg.png                                     56 x 192
    faces/back_NN.png  for every faces/face_NN.png            160 x 160

Needs numpy only. Run from the project directory.
"""
import math
import os
import struct
import sys
import zlib

import numpy as np

INK = np.array((0x12, 0x10, 0x1a), np.float32)
PAPER = np.array((0xef, 0xe7, 0xd6), np.float32)

ROLES = ["ceo", "engineer", "it", "hr", "marketing", "sales", "legal", "intern", "staff"]

# One wash per class, pale enough that the ink is still the darkest thing.
TINT = {
    "ceo": (0x5a, 0x4e, 0x63), "engineer": (0x9c, 0x5a, 0x4a), "it": (0x4f, 0x6b, 0x72),
    "hr": (0xb5, 0x7f, 0x9a), "marketing": (0xc4, 0x61, 0x4f), "sales": (0x5b, 0x7f, 0xa6),
    "legal": (0x3f, 0x4a, 0x52), "intern": (0xd8, 0xa9, 0x4b), "staff": (0xa8, 0xa0, 0x8e),
}


# --- a pen -------------------------------------------------------------------

class Sheet:
    """An RGBA page: a paper mask, a wash layer, and ink on top."""

    def __init__(self, w, h, seed=0):
        self.w, self.h = w, h
        self.paper = np.zeros((h, w), np.float32)
        self.wash = np.zeros((h, w, 3), np.float32)
        self.washa = np.zeros((h, w), np.float32)
        self.ink = np.zeros((h, w), np.float32)
        self.rng = np.random.RandomState(seed)
        yy, xx = np.mgrid[0:h, 0:w]
        self.xx = xx.astype(np.float32) + 0.5
        self.yy = yy.astype(np.float32) + 0.5

    # geometry -----------------------------------------------------------
    def _wobble(self, pts, amt):
        """Resample a polyline finely and shake it: the hand, not the ruler."""
        out = []
        for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
            n = max(2, int(math.hypot(x1 - x0, y1 - y0) / 4.0))
            for i in range(n):
                t = i / n
                out.append((x0 + (x1 - x0) * t, y0 + (y1 - y0) * t))
        out.append(tuple(pts[-1]))
        out = np.array(out, np.float32)
        if amt > 0 and len(out) > 2:
            k = self.rng.uniform(0.3, 0.9, 2)
            ph = self.rng.uniform(0, 6.28, 2)
            t = np.linspace(0, 1, len(out))
            out[:, 0] += amt * np.sin(t * 6.28 * 2.3 * k[0] + ph[0])
            out[:, 1] += amt * np.sin(t * 6.28 * 2.1 * k[1] + ph[1])
        return out

    def line(self, pts, width=2.2, wobble=1.0, closed=False):
        pts = list(pts)
        if closed:
            pts = pts + [pts[0]]
        pl = self._wobble(pts, wobble)
        r = width * 0.5
        for (x0, y0), (x1, y1) in zip(pl[:-1], pl[1:]):
            lo_x = max(0, int(min(x0, x1) - r - 2)); hi_x = min(self.w, int(max(x0, x1) + r + 3))
            lo_y = max(0, int(min(y0, y1) - r - 2)); hi_y = min(self.h, int(max(y0, y1) + r + 3))
            if lo_x >= hi_x or lo_y >= hi_y:
                continue
            px = self.xx[lo_y:hi_y, lo_x:hi_x]
            py = self.yy[lo_y:hi_y, lo_x:hi_x]
            dx, dy = x1 - x0, y1 - y0
            l2 = dx * dx + dy * dy + 1e-6
            t = np.clip(((px - x0) * dx + (py - y0) * dy) / l2, 0.0, 1.0)
            d = np.hypot(px - (x0 + t * dx), py - (y0 + t * dy))
            a = np.clip(r + 0.6 - d, 0.0, 1.0)
            self.ink[lo_y:hi_y, lo_x:hi_x] = np.maximum(self.ink[lo_y:hi_y, lo_x:hi_x], a)

    def poly_mask(self, pts, wobble=0.8):
        pl = self._wobble(list(pts) + [tuple(pts[0])], wobble)
        inside = np.zeros((self.h, self.w), bool)
        n = len(pl) - 1
        for i in range(n):
            x0, y0 = pl[i]
            x1, y1 = pl[i + 1]
            if y0 == y1:
                continue
            cond = ((self.yy > min(y0, y1)) & (self.yy <= max(y0, y1)))
            xint = x0 + (self.yy - y0) * (x1 - x0) / (y1 - y0)
            inside ^= cond & (self.xx < xint)
        return inside.astype(np.float32)

    def shape(self, pts, wash=None, outline=2.2, wobble=1.0, paper=True):
        """A garment or limb: paper under it, optional wash, ink around it."""
        m = self.poly_mask(pts, wobble * 0.6)
        if paper:
            self.paper = np.maximum(self.paper, m)
        if wash is not None:
            col = np.array(wash, np.float32).reshape(1, 1, 3)
            self.wash = np.where(m[..., None] > 0, col, self.wash)
            self.washa = np.maximum(self.washa, m * 0.42)
        if outline > 0:
            self.line(pts, outline, wobble, closed=True)
        return m

    def hatch(self, mask, spacing=6, angle=45, width=1.4, density=1.0):
        """Pen shading: parallel wobbly strokes clipped to a mask."""
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        diag = int(math.hypot(self.w, self.h)) + 10
        keep = np.zeros_like(self.ink)
        saved = self.ink
        self.ink = keep
        for k in range(-diag, diag, spacing):
            if self.rng.rand() > density:
                continue
            cx, cy = self.w * 0.5 + k * (-sa), self.h * 0.5 + k * ca
            p0 = (cx - ca * diag, cy - sa * diag)
            p1 = (cx + ca * diag, cy + sa * diag)
            self.line([p0, p1], width, 0.8)
        self.ink = saved
        self.ink = np.maximum(self.ink, keep * (mask > 0.5))

    def dots(self, mask, n=60, r=1.4):
        keep = np.zeros_like(self.ink)
        saved = self.ink
        self.ink = keep
        ys, xs = np.nonzero(mask > 0.5)
        if len(xs):
            for i in self.rng.choice(len(xs), min(n, len(xs)), replace=False):
                self.line([(xs[i], ys[i]), (xs[i] + 1.0, ys[i] + 0.5)], r * 2, 0.0)
        self.ink = saved
        self.ink = np.maximum(self.ink, keep)

    # output -------------------------------------------------------------
    def rgba(self):
        rgb = PAPER.reshape(1, 1, 3) * np.ones((self.h, self.w, 1), np.float32)
        wa = self.washa[..., None]
        rgb = rgb * (1 - wa) + self.wash * wa
        ink = np.clip(self.ink, 0, 1)[..., None]
        rgb = rgb * (1 - ink) + INK.reshape(1, 1, 3) * ink
        alpha = np.clip(np.maximum(self.paper, self.ink), 0, 1)
        return np.clip(np.concatenate([rgb, alpha[..., None] * 255.0], 2), 0, 255).astype(np.uint8)


# --- PNG in and out ----------------------------------------------------------

def write_png(path, rgba):
    h, w = rgba.shape[:2]
    rows = b"".join(b"\x00" + rgba[y].tobytes() for y in range(h))

    def chunk(tag, data):
        c = tag + data
        return struct.pack(">I", len(data)) + c + struct.pack(">I", zlib.crc32(c))

    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
           + chunk(b"IDAT", zlib.compress(rows, 9))
           + chunk(b"IEND", b""))
    open(path, "wb").write(png)


def read_png(path):
    """8-bit RGBA, non-interlaced - which is what write_png makes."""
    data = open(path, "rb").read()
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos, idat, w, h = 8, b"", 0, 0
    while pos < len(data):
        n = struct.unpack(">I", data[pos:pos + 4])[0]
        tag = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + n]
        if tag == b"IHDR":
            w, h, depth, ctype = struct.unpack(">IIBB", body[:10])
            assert depth == 8 and ctype == 6, "expected 8-bit RGBA"
        elif tag == b"IDAT":
            idat += body
        pos += 12 + n
    raw = zlib.decompress(idat)
    stride = w * 4
    out = np.zeros((h, stride), np.uint8)
    prev = np.zeros(stride, np.int32)
    p = 0
    for y in range(h):
        f = raw[p]
        row = np.frombuffer(raw[p + 1:p + 1 + stride], np.uint8).astype(np.int32)
        p += 1 + stride
        if f == 1:
            for i in range(4, stride):
                row[i] = (row[i] + row[i - 4]) & 255
        elif f == 2:
            row = (row + prev) & 255
        elif f == 3:
            for i in range(stride):
                a = row[i - 4] if i >= 4 else 0
                row[i] = (row[i] + ((a + prev[i]) >> 1)) & 255
        elif f == 4:
            for i in range(stride):
                a = row[i - 4] if i >= 4 else 0
                b = prev[i]
                c = prev[i - 4] if i >= 4 else 0
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                pr = a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)
                row[i] = (row[i] + pr) & 255
        out[y] = row
        prev = row
    return out.reshape(h, w, 4)


# --- costumes ----------------------------------------------------------------
# Torso sheet is 128 x 160: shoulders at the top, hips at the bottom. Arm sheet
# 48 x 160 hangs from the shoulder. Leg sheet 56 x 192 hangs from the hip.

TW, TH = 128, 160
AW, AH = 48, 160
LW, LH = 56, 192

SKIN = (0xe8, 0xc4, 0xa0)


def seed_of(text):
    """A stable seed: Python's hash() is salted per process, and a costume
    should come out the same on every build."""
    return sum((i + 1) * ord(c) for i, c in enumerate(text)) & 0xffff


def torso_outline():
    # Shoulders slope in, waist nips, hips flare a touch.
    return [(10, 6), (52, 2), (76, 2), (118, 6), (114, 70), (108, 154), (20, 154), (14, 70)]


def base_torso(s, tint, neck=True):
    s.shape(torso_outline(), wash=tint)
    if neck:
        s.shape([(50, 0), (78, 0), (76, 14), (52, 14)], wash=SKIN, outline=0)
        s.line([(52, 0), (54, 14)], 1.8); s.line([(76, 0), (74, 14)], 1.8)


def collar_v(s, depth=48, width=20):
    s.line([(64 - width, 8), (64, depth), (64 + width, 8)], 2.2)


def buttons(s, x, ys, r=3):
    for y in ys:
        s.line([(x - r, y), (x + r, y)], r * 1.6, 0.2)


def tie(s, loose=False):
    dx = 6 if loose else 0
    s.shape([(60, 14), (68, 14), (66 + dx, 26), (72 + dx, 92), (64 + dx, 104), (56 + dx, 92), (62 + dx, 26)],
            wash=(0x8a, 0x2a, 0x2a), outline=1.8)


def lanyard(s):
    s.line([(56, 4), (60, 60)], 2.0); s.line([(72, 4), (68, 60)], 2.0)
    s.shape([(54, 60), (74, 60), (74, 84), (54, 84)], wash=(0xf7, 0xf3, 0xea), outline=1.8)
    s.line([(58, 68), (70, 68)], 1.6); s.line([(58, 76), (66, 76)], 1.6)


def jacket(s, tint, dark=True, lapel=True, vent=False):
    left = [(10, 6), (44, 4), (48, 150), (20, 154), (14, 70)]
    right = [(118, 6), (84, 4), (80, 150), (108, 154), (114, 70)]
    m = s.shape(left, wash=tint, outline=2.2)
    m = np.maximum(m, s.shape(right, wash=tint, outline=2.2))
    if dark:
        s.hatch(m, spacing=5, angle=60, width=1.2, density=0.9)
    if lapel:
        s.line([(44, 4), (58, 40), (48, 62)], 2.0)
        s.line([(84, 4), (70, 40), (80, 62)], 2.0)
    if vent:
        s.line([(64, 100), (64, 154)], 1.8)


def draw_torso(role, back):
    s = Sheet(TW, TH, seed=seed_of(role + ("b" if back else "f")))
    t = TINT[role]
    base_torso(s, (0xf7, 0xf3, 0xea), neck=not back)
    if back:
        s.shape([(50, 0), (78, 0), (76, 12), (52, 12)], wash=SKIN, outline=0)
    if role == "ceo":
        jacket(s, t, dark=True, lapel=not back, vent=back)
        if not back:
            collar_v(s, 44, 12); tie(s)
            s.line([(22, 56), (34, 54), (33, 62)], 1.8)  # pocket square
    elif role == "legal":
        jacket(s, t, dark=True, lapel=not back, vent=back)
        if not back:
            s.shape([(48, 12), (80, 12), (78, 118), (64, 128), (50, 118)], wash=(0xb9, 0xa0, 0x7c), outline=2.0)
            buttons(s, 64, [50, 72, 94, 112])
            s.line([(54, 12), (64, 18), (74, 12), (64, 8)], 2.0, closed=True)  # bow tie
            s.line([(60, 10), (68, 16)], 1.6); s.line([(60, 16), (68, 10)], 1.6)
    elif role == "engineer":
        m = s.shape(torso_outline(), wash=t, outline=2.2)
        s.hatch(m, spacing=14, angle=0, width=1.6); s.hatch(m, spacing=14, angle=90, width=1.6)
        if not back:
            collar_v(s, 30, 14); buttons(s, 64, [44, 66, 88, 110, 132])
        else:
            s.line([(20, 40), (108, 40)], 1.8)  # yoke
    elif role == "it":
        s.shape(torso_outline(), wash=t, outline=2.2)
        if not back:
            s.line([(40, 2), (46, 30), (64, 40), (82, 30), (88, 2)], 2.2)  # hood rim
            s.line([(56, 34), (54, 70)], 1.6); s.line([(72, 34), (74, 70)], 1.6)  # drawstrings
            s.shape([(30, 104), (98, 104), (100, 150), (28, 150)], outline=2.0, paper=False)  # pouch
            s.line([(38, 104), (34, 126)], 1.6); s.line([(90, 104), (94, 126)], 1.6)
            lanyard(s)
        else:
            s.shape([(34, 2), (94, 2), (100, 40), (64, 60), (28, 40)], wash=t, outline=2.2)  # hood
            s.line([(40, 12), (64, 48), (88, 12)], 1.6)
    elif role == "hr":
        jacket(s, t, dark=False, lapel=not back, vent=False)
        if not back:
            s.shape([(48, 4), (80, 4), (80, 152), (48, 152)], wash=(0xf7, 0xf3, 0xea), outline=0)
            s.line([(48, 12), (58, 26), (64, 14), (70, 26), (80, 12)], 1.8)  # blouse collar
            lanyard(s)
            buttons(s, 42, [80, 100])
        else:
            s.line([(64, 20), (64, 100)], 1.4)
    elif role == "marketing":
        m = s.shape(torso_outline(), wash=t, outline=2.2)
        s.shape([(44, 0), (84, 0), (86, 22), (42, 22)], wash=t, outline=2.2)  # turtleneck
        s.line([(46, 8), (82, 8)], 1.4); s.line([(45, 15), (83, 15)], 1.4)
        sc = s.shape([(30, 20), (98, 26), (92, 44), (70, 48), (66, 120), (54, 120), (52, 48), (34, 40)],
                     wash=(0xd8, 0xa9, 0x4b), outline=2.0, paper=False)  # scarf
        s.hatch(sc, spacing=8, angle=-30, width=1.2, density=0.8)
    elif role == "sales":
        s.shape(torso_outline(), wash=(0xf7, 0xf3, 0xea), outline=2.2)
        if not back:
            collar_v(s, 34, 16); buttons(s, 64, [52, 74, 96, 118, 140])
            tie(s, loose=True)
            s.shape([(80, 100), (104, 100), (104, 132), (80, 132)], outline=1.8, paper=False)  # pocket
            s.line([(84, 104), (100, 104), (100, 128), (84, 128)], 1.4, closed=True)  # phone
        else:
            s.line([(20, 36), (108, 36)], 1.8)
    elif role == "intern":
        s.shape(torso_outline(), wash=t, outline=2.2)
        s.line([(48, 2), (54, 18), (74, 18), (80, 2)], 2.0)  # tee neck
        if not back:
            s.shape([(26, 50), (76, 50), (76, 84), (26, 84)], wash=(0xf7, 0xf3, 0xea), outline=2.0, paper=False)
            s.line([(30, 60), (72, 60)], 3.0, 0.3); s.line([(32, 72), (60, 72)], 2.0)  # HELLO sticker
            s.line([(22, 6), (30, 150)], 3.0); s.line([(106, 6), (98, 150)], 3.0)  # backpack straps
        else:
            bp = s.shape([(24, 10), (104, 10), (108, 120), (20, 120)], wash=(0x4f, 0x6b, 0x72), outline=2.4)
            s.hatch(bp, spacing=7, angle=45, width=1.0, density=0.6)
            s.line([(40, 28), (88, 28)], 1.8); s.line([(30, 80), (98, 80)], 1.8)
    else:  # staff: a plain shirt
        s.shape(torso_outline(), wash=t, outline=2.2)
        if not back:
            collar_v(s, 28, 14); buttons(s, 64, [46, 70, 94, 118])
    return s.rgba()


def draw_arm(role):
    s = Sheet(AW, AH, seed=seed_of(role + "arm"))
    t = TINT[role]
    sleeve_end = {"sales": 80, "intern": 40, "marketing": 150, "staff": 150}.get(role, 150)
    if role in ("ceo", "legal", "hr"):
        m = s.shape([(6, 0), (42, 0), (40, 150), (8, 150)], wash=t)
        if role != "hr":
            s.hatch(m, spacing=5, angle=60, width=1.2, density=0.9)
        s.line([(8, 142), (40, 142)], 1.6)  # cuff
    elif role == "engineer":
        m = s.shape([(6, 0), (42, 0), (40, 150), (8, 150)], wash=t)
        s.hatch(m, spacing=14, angle=0, width=1.6); s.hatch(m, spacing=14, angle=90, width=1.6)
    else:
        s.shape([(6, 0), (42, 0), (40, sleeve_end), (8, sleeve_end)], wash=t)
        if sleeve_end < 150:
            s.line([(8, sleeve_end - 10), (40, sleeve_end - 10)], 2.0)
    # hand, and bare forearm if the sleeve stops short
    s.shape([(10, sleeve_end - 2), (38, sleeve_end - 2), (36, 160), (12, 160)], wash=SKIN, outline=2.0)
    if role == "ceo":
        s.line([(10, 146), (38, 146)], 2.4)  # watch
    return s.rgba()


def draw_leg(role):
    s = Sheet(LW, LH, seed=seed_of(role + "leg"))
    dark = (0x4a, 0x54, 0x68)
    if role == "intern":
        s.shape([(6, 0), (50, 0), (48, 96), (8, 96)], wash=(0x87, 0x79, 0x6a))
        s.shape([(10, 96), (46, 96), (44, 178), (12, 178)], wash=SKIN, outline=1.8)
    else:
        col = {"engineer": (0x5b, 0x7f, 0xa6), "it": (0x87, 0x79, 0x6a), "hr": (0x6b, 0x5a, 0x4a),
               "marketing": (0x3f, 0x4a, 0x52), "sales": (0x6b, 0x5a, 0x4a)}.get(role, dark)
        m = s.shape([(6, 0), (50, 0), (48, 178), (8, 178)], wash=col)
        if role in ("ceo", "legal"):
            s.line([(28, 6), (28, 172)], 1.4)  # crease
            if role == "legal":
                s.hatch(m, spacing=6, angle=90, width=0.9, density=0.7)  # pinstripe
        if role == "engineer":
            s.line([(10, 4), (12, 172)], 1.2); s.line([(46, 4), (44, 172)], 1.2)  # jean seams
            s.line([(10, 160), (46, 160)], 1.4)
        if role == "it":
            s.line([(8, 70), (50, 70), (50, 104), (8, 104)], 1.6, closed=True)  # cargo pocket
    # shoe
    s.shape([(4, 176), (52, 176), (54, 192), (2, 192)], wash=(0x2b, 0x23, 0x20), outline=2.0)
    return s.rgba()


# --- the back of a head ------------------------------------------------------

def _dilate(a, r):
    out = a.copy()
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                out = np.maximum(out, np.roll(np.roll(a, dy, 0), dx, 1))
    return out


def _blur(a, r):
    out = np.zeros_like(a)
    n = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += np.roll(np.roll(a, dy, 0), dx, 1)
            n += 1
    return out / n


def head_back(face_rgba):
    """Mirror the silhouette, keep the hair, lose the face, ink the edge.

    Hair is whatever ink lies outside the face box - the middle of the head,
    where the eyes, nose and mouth are - so a fringe, the sides of long hair
    and the top of an afro all survive, and sunglasses do not. A light hatch
    over the crown gives the back of the head some mass.
    """
    alpha = face_rgba[..., 3].astype(np.float32) / 255.0
    lum = face_rgba[..., :3].astype(np.float32).mean(2) / 255.0
    sil = (_blur(alpha, 3) > 0.5).astype(np.float32)
    ink = np.clip((0.78 - lum) / 0.38, 0, 1) * sil

    ys, xs = np.nonzero(sil > 0.5)
    if len(xs) == 0:
        return face_rgba
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    w, h = x1 - x0, y1 - y0
    face = np.zeros_like(sil, bool)
    face[int(y0 + 0.28 * h):int(y0 + 0.92 * h), int(x0 + 0.17 * w):int(x0 + 0.83 * w)] = True
    kept = ink * (~face)

    # Mirror everything: the right side of the front is the left of the back.
    sil = sil[:, ::-1]
    kept = kept[:, ::-1]

    sheet = Sheet(sil.shape[1], sil.shape[0], seed=int(lum.sum()) & 0xffff)
    crown = sil.copy()
    crown[int(y0 + 0.42 * h):] = 0
    sheet.hatch(crown, spacing=6, angle=70, width=1.0, density=0.45)
    inner = 1 - _dilate(1 - sil, 2)
    edge = np.clip(sil - inner, 0, 1)
    ink_out = np.clip(np.maximum(np.maximum(kept, edge * 0.85), sheet.ink * 0.7), 0, 1)
    tint = face_rgba[..., :3].astype(np.float32)[(alpha > 0.5) & (lum > 0.8)]
    tint = tint.mean(0) if len(tint) else PAPER
    rgb = tint.reshape(1, 1, 3) * (1 - ink_out[..., None]) + INK.reshape(1, 1, 3) * ink_out[..., None]
    a_out = np.clip(np.maximum(sil, ink_out), 0, 1)
    a_out = np.clip(_blur(a_out, 1), 0, 1)
    return np.clip(np.concatenate([rgb, a_out[..., None] * 255.0], 2), 0, 255).astype(np.uint8)


# --- main --------------------------------------------------------------------

def main(faces="faces", bodies="bodies"):
    os.makedirs(bodies, exist_ok=True)
    for role in ROLES:
        write_png(os.path.join(bodies, "%s_torso_f.png" % role), draw_torso(role, False))
        write_png(os.path.join(bodies, "%s_torso_b.png" % role), draw_torso(role, True))
        write_png(os.path.join(bodies, "%s_arm.png" % role), draw_arm(role))
        write_png(os.path.join(bodies, "%s_leg.png" % role), draw_leg(role))
        print("costume", role)
    n = 0
    for name in sorted(os.listdir(faces)):
        if name.startswith("face_") and name.endswith(".png"):
            idx = name[5:7]
            write_png(os.path.join(faces, "back_%s.png" % idx), head_back(read_png(os.path.join(faces, name))))
            n += 1
    print("head backs", n)


if __name__ == "__main__":
    main(*sys.argv[1:])
