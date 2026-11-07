"""Port pirate au crépuscule, en vue 3/4 oblique façon Eastward.

Le sol est un plan vu en perspective : les façades sont de face, les toits montrent leur pente,
le quai et la mer s'étendent vers le joueur, et le navire est amarré en bas, vu d'au-dessus.
Résolution native 480x270, agrandie en pixels entiers. Palette limitée + tramage de Bayer.

Usage : python make_port_scene.py <dossier de sortie>
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 480, 270
HORIZON = 50
PALETTE_SIZE = 64
rng = random.Random(11)

base = Image.new("RGB", (W, H))
d = ImageDraw.Draw(base)
lights: list[tuple[float, float, float, tuple[int, int, int], float]] = []

STREET_TOP = 138   # pied des façades
QUAY_EDGE = 206    # bord du quai
QUAY_FRONT = 224   # bas de la face du quai


def R(x, y, w, h, c):
    d.rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def light(x, y, r, color, strength=1.0):
    lights.append((x, y, r, color, strength))


def shadow(x, y, w, h):
    d.ellipse([x - w // 2, y - h // 2, x + w // 2, y + h // 2], fill=(58, 50, 78))


# ============================================================ ciel, mer lointaine
SKY = [(0.0, (16, 14, 46)), (0.5, (62, 40, 98)), (0.8, (156, 66, 104)),
       (0.94, (236, 128, 94)), (1.0, (255, 192, 118))]


def sky_color(t):
    for i in range(len(SKY) - 1):
        t0, c0 = SKY[i]
        t1, c1 = SKY[i + 1]
        if t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0))
    return SKY[-1][1]


for y in range(HORIZON + 1):
    d.line([(0, y), (W, y)], fill=sky_color(y / HORIZON))
for _ in range(60):
    d.point((rng.randrange(W), rng.randrange(0, 34)),
            fill=lerp((110, 110, 170), (255, 255, 235), rng.random() ** 2))
d.ellipse([34, 12, 48, 26], fill=(244, 236, 214))
d.ellipse([39, 9, 53, 23], fill=sky_color(0.2))
for cx, cy, cw in [(150, 30, 70), (330, 24, 90), (420, 40, 50), (60, 42, 60)]:
    for k in range(cw // 6):
        px = cx - cw // 2 + k * 6 + rng.randrange(-2, 3)
        ph = 3 + int(4 * math.sin(k / (cw / 6) * math.pi))
        d.ellipse([px, cy - ph, px + 13, cy + 2], fill=(52, 34, 84))
        d.line([(px + 1, cy + 2), (px + 12, cy + 2)], fill=(214, 100, 112))

SEA_TOP, SEA_BOT = (178, 94, 112), (16, 32, 66)
for y in range(HORIZON + 1, H):
    t = (y - HORIZON) / (H - HORIZON)
    d.line([(0, y), (W, y)], fill=lerp(SEA_TOP, SEA_BOT, min(1.0, t ** 0.5)))
for _ in range(1100):
    y = rng.randrange(HORIZON + 2, H)
    t = (y - HORIZON) / (H - HORIZON)
    x = rng.randrange(W)
    ln = rng.randrange(3, 4 + int(10 * t))
    d.line([(x, y), (x + ln, y)], fill=lerp((246, 150, 118), (74, 112, 170), t ** 0.7))
for _ in range(500):
    y = rng.randrange(HORIZON + 2, H)
    x = rng.randrange(W)
    d.line([(x, y), (x + rng.randrange(3, 9), y)], fill=(12, 26, 56))
d.polygon([(300, HORIZON), (336, 40), (366, 36), (392, 44), (420, HORIZON)], fill=(46, 30, 76))
d.polygon([(400, HORIZON), (440, 42), (480, 38), (480, HORIZON)], fill=(38, 26, 68))
for y in range(HORIZON + 2, 130, 2):
    t = (y - HORIZON) / 80
    half = int(2 + 20 * t)
    for _ in range(max(2, 6 - int(t * 4))):
        x = 360 + rng.randrange(-half, half)
        d.line([(x, y), (x + rng.randrange(2, 7), y)], fill=lerp((255, 214, 130), (236, 120, 110), t))
# digue de pierre derrière (côté droit)
R(300, 122, 180, 16, (74, 66, 96))
for xx in range(300, 480, 12):
    d.line([(xx, 122), (xx, 137)], fill=(54, 46, 76))
d.line([(300, 122), (479, 122)], fill=(130, 118, 150))
d.line([(300, 129), (479, 129)], fill=(54, 46, 76))


# ============================================================ textures utilitaires


def planks_v(x, y, w, h, c, step=5):
    R(x, y, w, h, c)
    for xx in range(x, x + w, step):
        d.line([(xx, y), (xx, y + h - 1)], fill=shade(c, 0.78))
        d.line([(xx + 1, y), (xx + 1, y + h - 1)], fill=shade(c, 1.1))
    for _ in range(w * h // 80):
        d.point((x + rng.randrange(w), y + rng.randrange(h)), fill=shade(c, 0.7))


def stone_wall(x, y, w, h, c):
    R(x, y, w, h, c)
    row = 0
    for yy in range(y, y + h, 6):
        d.line([(x, yy), (x + w - 1, yy)], fill=shade(c, 0.68))
        off = 5 if row % 2 else 0
        for xx in range(x + off, x + w, 11):
            d.line([(xx, yy), (xx, min(yy + 5, y + h - 1))], fill=shade(c, 0.68))
        for _ in range(w // 18):
            sx = x + rng.randrange(w)
            d.line([(sx, yy + 1), (sx + rng.randrange(2, 6), yy + 1)], fill=shade(c, 1.2))
        row += 1


def roof_slope(x0, x1, eave_y, h, c):
    """Pente avant du toit vue d'en haut : trapèze en retrait vers le faîte, tuiles en rangs."""
    inset = 7
    d.polygon([(x0 - 6, eave_y), (x1 + 6, eave_y), (x1 - inset, eave_y - h), (x0 + inset, eave_y - h)], fill=c)
    row = 0
    for y in range(eave_y - h + 2, eave_y, 5):
        t = (y - (eave_y - h)) / h
        xl = x0 + inset - (inset + 6) * t
        xr = x1 - inset + (inset + 6) * t
        d.line([(xl, y), (xr, y)], fill=shade(c, 0.62))
        xx = int(xl) + (3 if row % 2 else 0)
        while xx < xr:
            d.line([(xx, y), (xx, y + 4)], fill=shade(c, 0.74))
            xx += 6
        d.line([(xl + 1, y + 1), (xr - 1, y + 1)], fill=shade(c, 1.2))
        row += 1
    # faîte
    d.line([(x0 + inset, eave_y - h), (x1 - inset, eave_y - h)], fill=shade(c, 1.45), width=2)
    d.line([(x0 + inset, eave_y - h - 1), (x1 - inset, eave_y - h - 1)], fill=shade(c, 0.5))
    # débord d'avant-toit avec ombre
    R(x0 - 6, eave_y, x1 - x0 + 12, 3, shade(c, 0.5))
    R(x0 - 5, eave_y + 3, x1 - x0 + 10, 3, (44, 36, 62))


def window(x, y, w, h, glow=True):
    R(x - 2, y - 2, w + 4, h + 4, (52, 34, 44))
    R(x, y, w, h, (28, 20, 40))
    if glow:
        R(x, y, w, h, (255, 190, 88))
        d.line([(x + w // 2, y), (x + w // 2, y + h - 1)], fill=(120, 60, 50))
        d.line([(x, y + h // 2), (x + w - 1, y + h // 2)], fill=(120, 60, 50))
        light(x + w / 2, y + h / 2 + 4, 32, (255, 168, 80), 0.7)
    R(x - 3, y + h + 2, w + 6, 3, (96, 62, 56))
    d.line([(x - 3, y + h + 2), (x + w + 2, y + h + 2)], fill=(150, 108, 84))


def door(x, y, w, h, c):
    R(x - 2, y - 2, w + 4, h + 2, (40, 26, 38))
    planks_v(x, y, w, h, c, 4)
    d.ellipse([x + w - 6, y + h // 2, x + w - 4, y + h // 2 + 2], fill=(236, 190, 90))
    R(x - 3, y + h, w + 6, 3, (120, 108, 134))  # seuil
    light(x + w / 2, y + h + 4, 26, (255, 168, 80), 0.45)


def lantern(x, y, strength=0.9, r=36):
    R(x - 1, y - 2, 7, 2, (40, 28, 40))
    R(x - 1, y + 7, 7, 2, (40, 28, 40))
    R(x, y, 5, 7, (255, 214, 120))
    R(x + 2, y, 1, 7, (170, 90, 60))
    light(x + 2.5, y + 3.5, r, (255, 176, 84), strength)


# ============================================================ bâtiments (façades + toits vus d'en haut)
WALL_H = 44
# 1. la taverne
x0, x1 = 6, 124
wy = STREET_TOP - WALL_H
planks_v(x0, wy, x1 - x0, WALL_H, (98, 90, 120))
stone_wall(x0, STREET_TOP - 8, x1 - x0, 8, (84, 82, 112))
roof_slope(x0, x1, wy, 36, (156, 64, 72))
R(96, 40, 10, 22, (64, 44, 66))
R(94, 38, 14, 3, (98, 72, 86))
# lucarne éclairée sur le toit
R(52, 74, 24, 18, (112, 54, 62))
d.polygon([(50, 74), (64, 66), (78, 74)], fill=(176, 80, 84))
window(57, 77, 14, 12)
window(18, 104, 18, 16)
window(94, 104, 18, 16)
door(52, 112, 26, 26, (112, 66, 56))
d.polygon([(40, 104), (90, 104), (98, 114), (32, 114)], fill=(232, 220, 202))
for xx in range(32, 98, 13):
    d.polygon([(xx + 6, 104), (xx + 13, 104), (xx + 15, 114), (xx + 8, 114)], fill=(198, 64, 70))
R(32, 114, 66, 2, (56, 38, 48))
R(126, 104, 12, 2, (50, 34, 44))   # enseigne
R(124, 106, 14, 14, (110, 72, 56))
R(126, 108, 10, 10, (236, 182, 70))
R(129, 111, 4, 4, (255, 244, 200))
lantern(8, 114)

# 2. l'atelier
x0, x1 = 134, 212
wy = STREET_TOP - 48
planks_v(x0, wy, x1 - x0, 48, (122, 94, 84))
stone_wall(x0, STREET_TOP - 8, x1 - x0, 8, (92, 96, 120))
roof_slope(x0, x1, wy, 34, (62, 84, 132))
R(180, 44, 9, 16, (64, 44, 66))
window(146, 100, 16, 14)
window(184, 100, 16, 14, glow=False)
door(158, 112, 30, 26, (92, 64, 58))
R(204, 90, 14, 3, (60, 42, 50))
d.line([(216, 92), (216, 118)], fill=(184, 154, 112))
R(210, 118, 12, 10, (134, 92, 60))
d.rectangle([210, 118, 221, 127], outline=(70, 46, 44))
d.ellipse([166, 90, 178, 102], outline=(176, 126, 80), width=2)
for a in range(0, 360, 45):
    d.line([(172, 96), (172 + 8 * math.cos(math.radians(a)), 96 + 8 * math.sin(math.radians(a)))],
           fill=(176, 126, 80))

# 3. l'entrepôt
x0, x1 = 222, 302
wy = STREET_TOP - 52
planks_v(x0, wy, x1 - x0, 52, (104, 80, 80))
roof_slope(x0, x1, wy, 32, (64, 114, 114))
R(228, 108, 44, 30, (60, 40, 50))
planks_v(230, 110, 20, 28, (96, 64, 58), 4)
planks_v(252, 110, 20, 28, (96, 64, 58), 4)
d.line([(230, 122), (271, 122)], fill=(50, 34, 44))
window(284, 96, 14, 12)
window(236, 90, 12, 10, glow=False)
d.line([(262, 60), (262, 38)], fill=(52, 36, 44))
d.polygon([(262, 38), (290, 44), (262, 52)], fill=(30, 24, 40))
d.point((274, 45), fill=(240, 232, 220))
d.line([(268, 47), (278, 43)], fill=(240, 232, 220))

# ============================================================ le sol : pavés en perspective
street_c = (96, 88, 114)
R(0, STREET_TOP, W, QUAY_EDGE - STREET_TOP, street_c)
y = STREET_TOP
row = 0
while y < QUAY_EDGE:
    rh = 5 + (y - STREET_TOP) // 22
    d.line([(0, y), (W, y)], fill=shade(street_c, 0.7))
    off = (7 * row) % 13
    x = -off
    while x < W:
        sw = 10 + rng.randrange(0, 6) + (y - STREET_TOP) // 14
        k = rng.random()
        if k < 0.3:
            R(max(x + 1, 0), y + 1, sw - 1, rh - 1, shade(street_c, 1.08))
        elif k < 0.45:
            R(max(x + 1, 0), y + 1, sw - 1, rh - 1, shade(street_c, 0.9))
        d.line([(x, y), (x, y + rh)], fill=shade(street_c, 0.7))
        x += sw
    y += rh
    row += 1
# ombre portée au pied des façades
for yy in range(STREET_TOP, STREET_TOP + 9):
    for xx in range(0, 304):
        if (xx + yy) % 2 == 0 or yy < STREET_TOP + 4:
            d.point((xx, yy), fill=(54, 46, 76))
# sentier de terre vers le quai
for yy in range(150, QUAY_EDGE):
    t = (yy - 150) / (QUAY_EDGE - 150)
    half = int(14 + 22 * t)
    for xx in range(214 - half, 214 + half):
        if rng.random() < 0.55:
            d.point((xx, yy), fill=(116, 92, 90) if rng.random() < 0.6 else (86, 70, 80))

# ============================================================ le phare (à droite, sur la digue)
LX = 448
shadow(LX, 154, 52, 12)
d.polygon([(LX - 17, 150), (LX + 17, 150), (LX + 11, 50), (LX - 11, 50)], fill=(226, 218, 214))
for y0 in range(58, 150, 24):
    t0, t1 = (y0 - 50) / 100, (y0 + 10 - 50) / 100
    d.polygon([(LX - 11 - 6 * t0, y0), (LX + 11 + 6 * t0, y0), (LX + 11 + 6 * t1, y0 + 10), (LX - 11 - 6 * t1, y0 + 10)],
              fill=(176, 56, 64))
d.polygon([(LX - 17, 150), (LX - 6, 150), (LX - 2, 50), (LX - 11, 50)], fill=(150, 142, 156))  # côté ombré
R(LX - 14, 46, 28, 4, (60, 44, 66))
R(LX - 9, 30, 18, 16, (255, 226, 140))
d.line([(LX, 30), (LX, 45)], fill=(150, 90, 60))
d.polygon([(LX - 12, 30), (LX, 18), (LX + 12, 30)], fill=(150, 62, 70))
light(LX, 40, 90, (255, 200, 110), 0.8)
stone_wall(LX - 22, 150, 44, 12, (84, 78, 106))
d.line([(LX - 22, 150), (LX + 21, 150)], fill=(150, 140, 170))

# ============================================================ accessoires du sol (triés par profondeur)


def barrel(x, y, w=14, h=18):
    shadow(x + w // 2 + 2, y + h, w + 8, 6)
    c = (132, 84, 62)
    d.ellipse([x, y, x + w, y + h], fill=c)
    d.line([(x + 2, y + h // 3), (x + w - 2, y + h // 3)], fill=(60, 40, 48))
    d.line([(x + 1, y + 2 * h // 3), (x + w - 1, y + 2 * h // 3)], fill=(60, 40, 48))
    d.line([(x + w // 3, y + 1), (x + w // 3, y + h - 1)], fill=shade(c, 1.25))
    d.ellipse([x + 1, y - 1, x + w - 1, y + 4], fill=(104, 64, 52))
    d.arc([x + 1, y - 1, x + w - 1, y + 4], 180, 360, fill=(170, 120, 84))


def crate(x, y, s=16, c=(142, 98, 70)):
    shadow(x + s // 2 + 3, y + s, s + 8, 6)
    R(x, y, s, s, c)
    d.rectangle([x, y, x + s - 1, y + s - 1], outline=(64, 42, 48))
    d.line([(x, y), (x + s - 1, y + s - 1)], fill=(88, 58, 54))
    d.line([(x + s - 1, y), (x, y + s - 1)], fill=(88, 58, 54))
    d.line([(x + 1, y + 1), (x + s - 2, y + 1)], fill=shade(c, 1.3))


def table(x, y):
    shadow(x, y + 16, 34, 10)
    for lx in (x - 10, x + 10):
        R(lx - 1, y + 4, 3, 12, (70, 46, 48))
    d.ellipse([x - 16, y - 4, x + 16, y + 8], fill=(136, 92, 68))
    d.arc([x - 16, y - 4, x + 16, y + 8], 180, 360, fill=(178, 128, 92))
    d.ellipse([x - 3, y - 3, x + 3, y + 1], fill=(230, 190, 90))
    d.line([(x, y - 2), (x, y - 1)], fill=(255, 244, 200))
    light(x, y - 2, 18, (255, 190, 100), 0.4)


def stool(x, y):
    shadow(x, y + 8, 14, 5)
    R(x - 1, y + 2, 2, 7, (70, 46, 48))
    d.ellipse([x - 6, y - 2, x + 6, y + 3], fill=(150, 104, 76))


def lamp_post(x, base_y):
    shadow(x + 2, base_y, 12, 5)
    R(x, base_y - 46, 4, 46, (50, 34, 44))
    R(x - 1, base_y - 46, 6, 2, (96, 70, 78))
    R(x - 5, base_y - 52, 14, 2, (50, 34, 44))
    lantern(x - 1, base_y - 60, 1.0, 40)


props = [
    (146, lambda: barrel(10, 140)), (148, lambda: barrel(26, 144)),
    (150, lambda: crate(232, 134)), (152, lambda: crate(252, 142, 14)),
    (153, lambda: barrel(278, 138)), (154, lambda: barrel(292, 142)),
    (178, lambda: (table(48, 166), stool(30, 176), stool(66, 178))),
    (186, lambda: (table(112, 182), stool(94, 192), stool(130, 192))),
    (200, lambda: lamp_post(176, 190)),
    (204, lambda: lamp_post(326, 188)),
]
for _, fn in sorted(props, key=lambda p: p[0]):
    fn()
# guirlande lumineuse entre les toits
for (xa, ya, xb, yb) in [(10, 92, 130, 94), (130, 94, 218, 92), (218, 92, 302, 92)]:
    pts = []
    for k in range(0, 41):
        t = k / 40
        pts.append((xa + (xb - xa) * t, ya + (yb - ya) * t + 7 * math.sin(math.pi * t)))
    d.line(pts, fill=(40, 28, 40))
    for k in range(2, 40, 4):
        x, y = pts[k]
        c = [(255, 220, 120), (255, 150, 110), (150, 230, 210)][(k // 4) % 3]
        R(int(x), int(y) + 1, 2, 3, c)
        light(x + 1, y + 2, 10, c, 0.35)

# ============================================================ face du quai et mer de devant
d.rectangle([0, QUAY_EDGE, W, QUAY_FRONT], fill=(70, 62, 92))
stone_wall(0, QUAY_EDGE + 2, W, QUAY_FRONT - QUAY_EDGE - 2, (70, 64, 96))
d.line([(0, QUAY_EDGE), (W, QUAY_EDGE)], fill=(158, 146, 176), width=2)
for _ in range(60):
    mx = rng.randrange(W)
    d.line([(mx, QUAY_FRONT - 2), (mx + rng.randrange(3, 9), QUAY_FRONT - 2)], fill=(60, 100, 96))
# ombre du quai sur l'eau
for yy in range(QUAY_FRONT, QUAY_FRONT + 6):
    d.line([(0, yy), (W, yy)], fill=(10, 20, 46))
# bollards
for bx in (100, 290, 420):
    R(bx, QUAY_EDGE - 10, 8, 10, (52, 38, 50))
    d.ellipse([bx - 2, QUAY_EDGE - 14, bx + 10, QUAY_EDGE - 8], fill=(86, 66, 72))
lantern(30, QUAY_EDGE - 22, 0.9, 30)
R(32, QUAY_EDGE - 14, 2, 14, (44, 30, 40))

# ponton perpendiculaire au quai
PX0, PX1 = 200, 240
R(PX0, QUAY_FRONT, PX1 - PX0, H - QUAY_FRONT, (130, 90, 66))
for yy in range(QUAY_FRONT + 2, H, 6):
    d.line([(PX0, yy), (PX1, yy)], fill=(86, 56, 52))
    d.line([(PX0, yy + 1), (PX1, yy + 1)], fill=(164, 116, 82))
d.line([(PX0, QUAY_FRONT), (PX0, H)], fill=(60, 40, 46), width=2)
d.line([(PX1, QUAY_FRONT), (PX1, H)], fill=(60, 40, 46), width=2)
for yy in range(QUAY_FRONT + 6, H, 18):
    for xx in (PX0 - 2, PX1 - 2):
        R(xx, yy, 5, 6, (52, 36, 46))
lantern(PX0 - 2, H - 34, 1.0, 34)
R(PX0, H - 28, 3, 22, (44, 30, 40))

# reflets de lanternes dans l'eau, devant le quai
for lx_, col in [(32, (255, 190, 100)), (330, (255, 176, 90))]:
    for k in range(14):
        d.line([(lx_ + rng.randrange(-3, 4), QUAY_FRONT + 8 + k * 2),
                (lx_ + 6 + rng.randrange(-2, 5), QUAY_FRONT + 8 + k * 2)],
               fill=col if k < 7 else (190, 120, 86))

# ============================================================ le navire : goélette amarrée au quai
SX0, SX1 = 254, 412
hull = (72, 44, 48)
hull_l = (122, 80, 64)
# ombre dans l'eau
d.ellipse([SX0 - 12, 250, SX1 + 18, 272], fill=(8, 18, 44))
# coque (flanc visible)
d.polygon([(SX0, 234), (SX0 + 70, 242), (SX1 - 10, 234), (SX1 + 8, 228),
           (SX1 - 2, 248), (SX1 - 20, 260), (SX0 + 60, 266), (SX0 + 10, 256), (SX0 - 2, 246)], fill=hull)
for k, yy in enumerate(range(246, 266, 6)):
    d.line([(SX0 + 2 + k * 6, yy), (SX1 - 6 - k * 10, yy)], fill=shade(hull, 0.6))
    d.line([(SX0 + 2 + k * 6, yy + 1), (SX1 - 6 - k * 10, yy + 1)], fill=hull_l if k % 2 == 0 else shade(hull_l, 0.8))
# pont vu d'en haut (plan clair avec lames)
d.polygon([(SX0 + 2, 233), (SX0 + 70, 241), (SX1 - 10, 233), (SX1 - 6, 224), (SX0 + 70, 228), (SX0 + 6, 224)],
          fill=(158, 112, 82))
for k in range(1, 4):
    t = k / 4
    d.line([(SX0 + 4 + 2 * t, 233 - 9 * t), (SX1 - 8, 233 - 9 * t)], fill=(102, 70, 60))
# pavois avant (flanc proche) avec liston doré
d.polygon([(SX0 - 2, 234), (SX0 + 70, 243), (SX1 - 10, 235), (SX1 + 8, 228), (SX1 + 4, 231),
           (SX1 - 10, 239), (SX0 + 70, 248), (SX0 - 2, 240)], fill=(88, 54, 54))
d.line([(SX0 - 2, 234), (SX0 + 70, 243), (SX1 - 10, 235), (SX1 + 8, 228)], fill=(220, 170, 84), width=2)
for xx in range(SX0 + 20, SX1 - 20, 22):
    R(xx, 251, 9, 7, (24, 16, 32))
# lisse d'amure arrière et haubans de pont (rambarde lointaine)
d.line([(SX0 + 6, 224), (SX0 + 70, 228), (SX1 - 6, 224)], fill=(196, 150, 110), width=1)
for xx in range(SX0 + 12, SX1 - 8, 12):
    d.line([(xx, 224), (xx, 229)], fill=(120, 80, 64))
# dunette arrière avec cabine
planks_v(SX0 + 2, 206, 40, 22, (98, 66, 60), 4)
d.polygon([(SX0 - 2, 206), (SX0 + 44, 206), (SX0 + 38, 196), (SX0 + 4, 196)], fill=(152, 64, 72))
R(SX0 + 8, 211, 8, 8, (255, 190, 88))
R(SX0 + 26, 211, 8, 8, (255, 190, 88))
light(SX0 + 20, 215, 30, (255, 168, 80), 0.7)
lantern(SX0 + 41, 198, 1.0, 36)
# bout-dehors
d.line([(SX1 + 6, 230), (SX1 + 34, 214)], fill=(110, 76, 62), width=3)
# mâts
for mx, top in ((318, 82), (378, 94)):
    R(mx, top, 5, 150 - (top - 82) - 4 + 0, (98, 66, 58)) if False else R(mx, top, 5, 236 - top, (98, 66, 58))
    R(mx + 1, top, 1, 236 - top, (150, 106, 80))
    d.ellipse([mx - 1, top - 3, mx + 6, top + 3], fill=(130, 90, 70))
# grand-voile (de face, étarquée à moitié) : bôme + voile + cargue
R(262, 198, 58, 3, (112, 78, 64))
d.polygon([(318, 90), (318, 198), (268, 198), (276, 168), (292, 128)], fill=(220, 198, 176))
for xx in range(272, 318, 9):
    t = (xx - 268) / 50
    d.line([(xx, 198), (318 - (318 - xx) * 0.1, 96 + (1 - t) * 70)], fill=(188, 164, 146))
for yy in range(110, 198, 10):
    d.line([(318, yy), (270 + max(0, (yy - 130) * 0.05), yy)] if yy > 140 else [(318, yy), (298 - (yy - 110) * 0.3, yy)],
           fill=(194, 170, 152))
R(300, 150, 11, 11, (150, 116, 104))
d.rectangle([300, 150, 310, 160], outline=(110, 80, 76))
d.line([(318, 90), (318, 198)], fill=(120, 90, 74), width=2)
# voile d'étai (misaine)
R(326, 204, 58, 3, (112, 78, 64))
d.polygon([(378, 102), (378, 204), (330, 204), (338, 176), (352, 140)], fill=(214, 190, 168))
for xx in range(334, 378, 9):
    d.line([(xx, 204), (378 - (378 - xx) * 0.1, 108 + (xx - 330) * 0.0)], fill=(182, 158, 140))
d.line([(378, 102), (378, 204)], fill=(120, 90, 74), width=2)
# foc
d.polygon([(384, 104), (SX1 + 32, 214), (384, 214)], fill=(226, 204, 184))
d.line([(384, 104), (SX1 + 32, 214)], fill=(110, 80, 70))
for yy in range(124, 214, 12):
    d.line([(384, yy), (384 + (yy - 104) * 0.3, yy)], fill=(190, 166, 148))
# pavillon noir
d.line([(320, 82), (320, 62)], fill=(60, 42, 50))
d.polygon([(320, 62), (346, 68), (320, 76)], fill=(26, 20, 38))
d.ellipse([327, 66, 332, 71], fill=(238, 230, 216))
d.line([(325, 73), (334, 65)], fill=(238, 230, 216))
d.line([(325, 65), (334, 73)], fill=(238, 230, 216))
# haubans
for (a, b, c_, e_) in [(320, 86, 262, 206), (320, 86, 296, 222), (380, 98, 420, 226), (380, 98, 340, 222),
                       (320, 86, 380, 98)]:
    d.line([(a, b), (c_, e_)], fill=(54, 38, 50))
# amarres vers les bollards
d.line([(290, QUAY_EDGE - 4), (292, 224), (294, 232)], fill=(196, 152, 104), width=1)
d.line([(420, QUAY_EDGE - 4), (416, 226), (410, 232)], fill=(196, 152, 104), width=1)
# écume et reflets
for k in range(26):
    yy = 262 + (k % 8)
    xx = SX0 + 8 + rng.randrange(0, SX1 - SX0 - 20)
    d.line([(xx, yy), (xx + rng.randrange(3, 8), yy)], fill=(210, 190, 196))
for k in range(18):
    yy = 266 + k // 4
    d.line([(SX0 + 28 + rng.randrange(-4, 6), yy), (SX0 + 34 + rng.randrange(0, 5), yy)], fill=(255, 190, 100))

# ============================================================ lumière, vignette, palette
arr = np.asarray(base).astype(np.float32)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
for (lx, ly, r, col, strength) in lights:
    dist = np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2)
    a = np.clip(1.0 - dist / r, 0.0, 1.0) ** 2 * strength
    arr += a[..., None] * (np.array(col, dtype=np.float32) * 0.55)
cx, cy = W / 2, H / 2
v = 1.0 - 0.3 * np.clip(np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2) - 0.6, 0, 1)
arr *= v[..., None]
bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
pattern = np.tile(bayer, (H // 4 + 1, W // 4 + 1))[:H, :W]
arr += pattern[..., None] * 9.0
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
img = img.quantize(colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out.mkdir(parents=True, exist_ok=True)
img.save(out / "port_native.png")
img.resize((W * 3, H * 3), Image.Resampling.NEAREST).save(out / "port_x3.png")
print("ok", W, H)
