"""Dessine en pixel art, par du code, un port pirate au crépuscule (vue de face, façon Eastward).

Résolution native 480x270, agrandie ensuite en pixels entiers. Pipeline :
1. le décor est peint avec des formes simples (PIL, sans lissage) ;
2. une couche « lumière » (fenêtres, lanternes) est ajoutée avec des halos ;
3. le tout est ramené à une palette limitée avec un tramage de Bayer.

Usage : python make_port_scene.py <dossier de sortie>
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

W, H = 480, 270
HORIZON = 118
PALETTE_SIZE = 56
rng = random.Random(7)

base = Image.new("RGB", (W, H))
emis = Image.new("RGB", (W, H), (0, 0, 0))
d = ImageDraw.Draw(base)
e = ImageDraw.Draw(emis)
lights: list[tuple[float, float, float, tuple[int, int, int], float]] = []


def R(x, y, w, h, c, draw=None):
    (draw or d).rectangle([x, y, x + w - 1, y + h - 1], fill=c)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


def light(x, y, r, color, strength=1.0):
    lights.append((x, y, r, color, strength))


# ---------------------------------------------------------------- ciel et mer
SKY = [(0.0, (16, 14, 46)), (0.45, (58, 38, 96)), (0.75, (150, 64, 104)),
       (0.92, (232, 124, 94)), (1.0, (255, 190, 116))]


def sky_color(t):
    for i in range(len(SKY) - 1):
        t0, c0 = SKY[i]
        t1, c1 = SKY[i + 1]
        if t <= t1:
            return lerp(c0, c1, (t - t0) / (t1 - t0))
    return SKY[-1][1]


for y in range(HORIZON + 1):
    d.line([(0, y), (W, y)], fill=sky_color(y / HORIZON))
for _ in range(90):
    x, y = rng.randrange(W), rng.randrange(0, 70)
    d.point((x, y), fill=lerp((120, 120, 180), (255, 255, 235), rng.random()))
# lune
d.ellipse([52, 22, 68, 38], fill=(244, 236, 214))
d.ellipse([57, 19, 73, 35], fill=sky_color(0.2))
# nuages : bande sombre, ventre rose
for cx, cy, cw in [(120, 62, 90), (330, 48, 120), (240, 84, 70), (440, 76, 60), (30, 84, 70)]:
    for k in range(cw // 6):
        px = cx - cw // 2 + k * 6 + rng.randrange(-2, 3)
        ph = 4 + int(5 * math.sin(k / (cw / 6) * math.pi))
        d.ellipse([px, cy - ph, px + 14, cy + 2], fill=(52, 34, 84))
        d.line([(px + 1, cy + 2), (px + 13, cy + 2)], fill=(214, 100, 112))
        d.line([(px + 2, cy + 1), (px + 11, cy + 1)], fill=(150, 66, 104))

# îles lointaines
d.polygon([(300, HORIZON), (330, 106), (352, 100), (372, 108), (392, HORIZON)], fill=(44, 30, 74))
d.polygon([(380, HORIZON), (410, 108), (452, 104), (480, 110), (480, HORIZON)], fill=(36, 26, 66))
# phare
R(433, 86, 5, 24, (226, 218, 214))
R(433, 92, 5, 3, (170, 52, 60))
R(433, 100, 5, 3, (170, 52, 60))
R(431, 83, 9, 3, (60, 40, 70))
R(434, 79, 3, 4, (255, 226, 140), e)
R(434, 79, 3, 4, (255, 226, 140))
light(435, 81, 40, (255, 196, 110), 0.55)

# mer : dégradé + vaguelettes
SEA_TOP, SEA_BOT = (176, 92, 112), (14, 30, 62)
for y in range(HORIZON + 1, H):
    t = (y - HORIZON) / (H - HORIZON)
    d.line([(0, y), (W, y)], fill=lerp(SEA_TOP, SEA_BOT, min(1.0, t ** 0.55)))
for _ in range(900):
    y = rng.randrange(HORIZON + 2, H)
    t = (y - HORIZON) / (H - HORIZON)
    x = rng.randrange(W)
    ln = rng.randrange(3, 4 + int(10 * t))
    col = lerp((246, 150, 118), (70, 110, 168), t ** 0.7)
    d.line([(x, y), (x + ln, y)], fill=col)
for _ in range(500):
    y = rng.randrange(HORIZON + 2, H)
    x = rng.randrange(W)
    d.line([(x, y), (x + rng.randrange(3, 9), y)], fill=(10, 24, 54))
# reflet du soleil couchant, derrière le phare
for y in range(HORIZON + 2, 200, 2):
    t = (y - HORIZON) / 82
    half = int(2 + 22 * t)
    for _ in range(max(2, 7 - int(t * 4))):
        x = 436 + rng.randrange(-half, half)
        d.line([(x, y), (x + rng.randrange(2, 7), y)], fill=lerp((255, 214, 130), (236, 120, 110), t))

# ---------------------------------------------------------------- le quai
PIER_TOP, PIER_FRONT = 170, 216
PIER_RIGHT = 336
wood = (122, 82, 62)
wood_d = (84, 54, 50)
wood_l = (160, 112, 78)
R(0, PIER_TOP, PIER_RIGHT, PIER_FRONT - PIER_TOP, wood)
for y in range(PIER_TOP, PIER_FRONT, 6):
    d.line([(0, y), (PIER_RIGHT, y)], fill=wood_d)
    d.line([(0, y + 1), (PIER_RIGHT, y + 1)], fill=wood_l if (y // 6) % 2 else wood)
    x = rng.randrange(0, 40)
    while x < PIER_RIGHT:
        d.line([(x, y + 1), (x, y + 5)], fill=wood_d)
        x += rng.randrange(34, 70)
# dégradé de lumière du fond (ombre des bâtiments)
for y in range(PIER_TOP, PIER_TOP + 10):
    for x in range(0, PIER_RIGHT, 2):
        if (x + y) % 4 == 0:
            d.point((x, y), fill=shade(wood_d, 0.8))
# face avant du quai
R(0, PIER_FRONT, PIER_RIGHT, 16, (66, 42, 48))
for x in range(0, PIER_RIGHT, 10):
    d.line([(x, PIER_FRONT), (x, PIER_FRONT + 15)], fill=(46, 30, 40))
d.line([(0, PIER_FRONT), (PIER_RIGHT, PIER_FRONT)], fill=(176, 122, 84))
d.line([(0, PIER_FRONT + 15), (PIER_RIGHT, PIER_FRONT + 15)], fill=(30, 20, 34))
# pilotis
for x in range(14, PIER_RIGHT, 52):
    R(x, PIER_FRONT + 14, 8, 22, (50, 34, 44))
    R(x, PIER_FRONT + 14, 2, 22, (72, 50, 58))
    d.line([(x - 1, PIER_FRONT + 30), (x + 8, PIER_FRONT + 30)], fill=(150, 110, 90))
    for k in range(6):  # écume au pied du pilotis
        d.point((x + rng.randrange(-4, 12), PIER_FRONT + 35 + rng.randrange(0, 3)), fill=(220, 190, 190))

# ---------------------------------------------------------------- bâtiments


def planks_v(x, y, w, h, c, step=5):
    R(x, y, w, h, c)
    for xx in range(x, x + w, step):
        d.line([(xx, y), (xx, y + h - 1)], fill=shade(c, 0.78))
        d.line([(xx + 1, y), (xx + 1, y + h - 1)], fill=shade(c, 1.08))
    for _ in range(w * h // 90):
        d.point((x + rng.randrange(w), y + rng.randrange(h)), fill=shade(c, 0.7))


def stone(x, y, w, h, c):
    R(x, y, w, h, c)
    row = 0
    for yy in range(y, y + h, 6):
        d.line([(x, yy), (x + w - 1, yy)], fill=shade(c, 0.7))
        off = 5 if row % 2 else 0
        for xx in range(x + off, x + w, 11):
            d.line([(xx, yy), (xx, min(yy + 5, y + h - 1))], fill=shade(c, 0.7))
        row += 1


def roof(x0, x1, wall_y, rh, c, overhang=7):
    cx = (x0 + x1) / 2
    apex = wall_y - rh
    half_w = (x1 - x0) / 2 + overhang
    d.polygon([(cx - half_w, wall_y), (cx, apex), (cx + half_w, wall_y)], fill=c)
    row = 0
    for y in range(apex + 3, wall_y, 5):
        half = (y - apex) / rh * half_w
        d.line([(cx - half, y), (cx + half, y)], fill=shade(c, 0.66))
        off = 3 if row % 2 else 0
        xx = int(cx - half) + off
        while xx < cx + half:
            d.line([(xx, y), (xx, y + 4)], fill=shade(c, 0.74))
            xx += 6
        d.line([(cx - half + 1, y + 1), (cx + half - 1, y + 1)], fill=shade(c, 1.18))
        row += 1
    d.line([(cx - half_w, wall_y), (cx, apex)], fill=shade(c, 1.35))
    d.line([(cx + half_w, wall_y), (cx, apex)], fill=shade(c, 0.5))
    R(int(cx - half_w), wall_y, int(half_w * 2) + 1, 3, shade(c, 0.5))  # débord
    return apex


def window(x, y, w, h, glow=True):
    R(x - 2, y - 2, w + 4, h + 4, (52, 34, 44))
    R(x, y, w, h, (28, 20, 40))
    if glow:
        R(x, y, w, h, (255, 190, 88), e)
        R(x, y, w, h, (255, 190, 88))
        d.line([(x + w // 2, y), (x + w // 2, y + h - 1)], fill=(120, 60, 50))
        d.line([(x, y + h // 2), (x + w - 1, y + h // 2)], fill=(120, 60, 50))
        e.line([(x + w // 2, y), (x + w // 2, y + h - 1)], fill=(0, 0, 0))
        e.line([(x, y + h // 2), (x + w - 1, y + h // 2)], fill=(0, 0, 0))
        light(x + w / 2, y + h / 2, 30, (255, 168, 80), 0.7)
    R(x - 3, y + h + 2, w + 6, 3, (96, 62, 56))  # appui


def door(x, y, w, h, c, glow=False):
    R(x - 2, y - 2, w + 4, h + 2, (40, 26, 38))
    planks_v(x, y, w, h, c, 4)
    d.ellipse([x + w - 6, y + h // 2, x + w - 4, y + h // 2 + 2], fill=(236, 190, 90))
    if glow:
        light(x + w / 2, y + h, 24, (255, 168, 80), 0.5)


def lantern(x, y, strength=0.9):
    R(x, y, 5, 7, (255, 206, 110), e)
    R(x - 1, y - 2, 7, 2, (40, 28, 40))
    R(x - 1, y + 7, 7, 2, (40, 28, 40))
    R(x, y, 5, 7, (255, 214, 120))
    R(x + 2, y, 1, 7, (170, 90, 60))
    light(x + 2.5, y + 3.5, 34, (255, 176, 84), strength)


WALL_Y = PIER_TOP

# 1. la taverne (gauche) : planches bleu-gris, toit rouge, auvent rayé
stone(4, WALL_Y - 10, 116, 10, (84, 82, 112))
planks_v(4, 104, 116, 56, (98, 90, 118))
roof(4, 120, 104, 40, (150, 62, 70))
R(98, 50, 9, 24, (64, 44, 66))  # cheminée
R(96, 48, 13, 3, (96, 70, 84))
window(16, 116, 18, 16)
window(84, 116, 18, 16)
window(16, 140, 18, 14, glow=False)
door(52, 130, 24, 30, (112, 66, 56), glow=True)
# auvent
d.polygon([(40, 122), (88, 122), (94, 130), (34, 130)], fill=(230, 218, 200))
for xx in range(34, 94, 12):
    d.polygon([(xx + 6, 122), (xx + 12, 122), (xx + 14, 130), (xx + 8, 130)], fill=(196, 62, 68))
d.line([(34, 131), (94, 131)], fill=(52, 34, 44))
# enseigne : chope sur potence
R(122, 112, 12, 2, (50, 34, 44))
R(124, 114, 14, 14, (110, 72, 56))
R(126, 116, 10, 10, (236, 182, 70))
R(128, 118, 6, 6, (255, 244, 200))
R(131, 120, 3, 4, (170, 90, 50))
d.line([(125, 114), (125, 111)], fill=(50, 34, 44))
lantern(8, 134)

# 2. l'atelier du charpentier de marine (centre) : pierre et bois, toit bleu ardoise
stone(124, WALL_Y - 8, 78, 8, (92, 96, 118))
planks_v(124, 88, 78, 74, (120, 92, 80))
roof(124, 202, 88, 36, (60, 82, 128))
window(138, 104, 16, 14)
window(172, 104, 16, 14, glow=False)
door(150, 126, 34, 36, (92, 64, 58), glow=True)
# poulie et caisse suspendue
R(190, 82, 18, 3, (60, 42, 50))
d.line([(206, 85), (206, 118)], fill=(180, 150, 110))
R(200, 118, 12, 10, (134, 92, 60))
d.rectangle([200, 118, 211, 127], outline=(70, 46, 44))
# gouvernail accroché au mur
d.ellipse([160, 96, 172, 108], outline=(176, 126, 80), width=2)
for a in range(0, 360, 45):
    d.line([(166, 102), (166 + 8 * math.cos(math.radians(a)), 102 + 8 * math.sin(math.radians(a)))],
           fill=(176, 126, 80))

# 3. l'entrepôt (droite) : grandes portes, toit vert-de-gris
planks_v(206, 96, 124, 66, (104, 78, 78))
roof(206, 330, 96, 30, (62, 112, 112))
R(212, 118, 42, 44, (60, 40, 50))
planks_v(214, 120, 18, 42, (96, 64, 58), 4)
planks_v(234, 120, 18, 42, (96, 64, 58), 4)
d.line([(214, 138), (252, 138)], fill=(50, 34, 44))
d.line([(214, 148), (252, 148)], fill=(50, 34, 44))
window(272, 110, 16, 14)
window(300, 110, 16, 14, glow=False)
door(278, 130, 22, 32, (112, 70, 58), glow=True)
lantern(262, 128)
# drapeau pirate au sommet
d.line([(268, 66), (268, 46)], fill=(52, 36, 44))
d.polygon([(268, 46), (296, 52), (268, 60)], fill=(30, 24, 40))
d.point((278, 53), fill=(240, 232, 220))
d.line([(274, 55), (282, 51)], fill=(240, 232, 220))

# ---------------------------------------------------------------- accessoires du quai


def barrel(x, y, w=14, h=18):
    c = (130, 82, 60)
    d.ellipse([x, y, x + w, y + h], fill=c)
    d.line([(x + 2, y + h // 3), (x + w - 2, y + h // 3)], fill=(60, 40, 48))
    d.line([(x + 1, y + 2 * h // 3), (x + w - 1, y + 2 * h // 3)], fill=(60, 40, 48))
    d.line([(x + w // 3, y + 1), (x + w // 3, y + h - 1)], fill=shade(c, 1.25))
    d.ellipse([x + 1, y - 1, x + w - 1, y + 4], fill=(104, 64, 52))
    d.arc([x + 1, y - 1, x + w - 1, y + 4], 180, 360, fill=(170, 120, 84))


def crate(x, y, s=16, c=(142, 98, 70)):
    R(x, y, s, s, c)
    d.rectangle([x, y, x + s - 1, y + s - 1], outline=(64, 42, 48))
    d.line([(x, y), (x + s - 1, y + s - 1)], fill=(88, 58, 54))
    d.line([(x + s - 1, y), (x, y + s - 1)], fill=(88, 58, 54))
    d.line([(x + 1, y + 1), (x + s - 2, y + 1)], fill=shade(c, 1.3))


barrel(10, 152)
barrel(26, 156)
crate(240, 150)
crate(258, 154, 14)
crate(244, 134, 14, (156, 110, 76))
barrel(300, 150)
barrel(316, 154)
# tas de cordage
d.ellipse([120, 162, 140, 172], fill=(168, 136, 96))
d.ellipse([125, 164, 135, 170], fill=(120, 90, 70))
# filet pendu
for k in range(5):
    d.line([(222 + k * 4, 126), (220 + k * 4, 150)], fill=(150, 124, 96))
for k in range(4):
    d.line([(220, 130 + k * 6), (240, 130 + k * 6)], fill=(150, 124, 96))
# poteaux-lanternes sur le quai
for px in (96, 214, 322):
    R(px, 150, 4, 44, (50, 34, 44))
    lantern(px - 2, 142, 1.0)
# bollard à l'extrémité
R(328, 192, 8, 16, (50, 34, 44))
d.ellipse([326, 188, 338, 196], fill=(76, 52, 56))

# guirlande lumineuse entre les toits
for (xa, ya, xb, yb) in [(6, 98, 126, 96), (126, 96, 214, 92), (214, 92, 330, 94)]:
    pts = []
    for k in range(0, 41):
        t = k / 40
        x = xa + (xb - xa) * t
        y = ya + (yb - ya) * t + 7 * math.sin(math.pi * t)
        pts.append((x, y))
    d.line(pts, fill=(40, 28, 40))
    for k in range(2, 40, 4):
        x, y = pts[k]
        c = [(255, 220, 120), (255, 150, 110), (150, 230, 210)][(k // 4) % 3]
        R(int(x), int(y) + 1, 2, 3, c, e)
        R(int(x), int(y) + 1, 2, 3, c)
        light(x + 1, y + 2, 10, c, 0.35)

# ---------------------------------------------------------------- le navire
hull = (70, 42, 46)
hull_l = (118, 76, 62)
# ombre dans l'eau sous la coque
d.ellipse([318, 232, 478, 258], fill=(8, 18, 44))
d.polygon([(326, 204), (470, 196), (480, 188), (474, 216), (448, 242), (410, 254),
           (356, 250), (330, 232)], fill=hull)
for k, y in enumerate(range(206, 252, 7)):
    left = 328 + k * 3
    right = 470 - k * 5
    d.line([(left, y), (right, y)], fill=shade(hull, 0.6))
    d.line([(left, y + 1), (right, y + 1)], fill=hull_l if k % 2 == 0 else shade(hull_l, 0.8))
    x = left + rng.randrange(8, 24)
    while x < right:
        d.line([(x, y + 1), (x, y + 6)], fill=shade(hull, 0.6))
        x += rng.randrange(30, 60)
d.line([(326, 204), (470, 196)], fill=(214, 164, 80), width=2)  # liston doré
d.line([(332, 232), (356, 250), (410, 254), (448, 242)], fill=(28, 18, 36), width=2)
# sabords
for x in range(350, 440, 20):
    R(x, 218, 9, 8, (24, 16, 32))
    R(x + 1, 224, 7, 2, (110, 70, 60))
# poupe : cabine du capitaine
planks_v(324, 178, 34, 28, (96, 64, 58), 4)
R(322, 174, 38, 5, (150, 62, 70))
window(331, 186, 8, 8)
window(345, 186, 8, 8)
lantern(336, 168, 1.0)
R(333, 170, 1, 8, (40, 28, 40))
# figure de proue : tête de dragon simple
d.polygon([(470, 196), (484, 184), (490, 186), (486, 192), (478, 200)], fill=(110, 70, 62))
d.point((486, 187), fill=(255, 226, 120))
# mâts
R(392, 56, 5, 148, (96, 64, 56))
R(393, 56, 1, 148, (146, 102, 78))
R(440, 128, 4, 70, (96, 64, 56))
# vergues et voiles
R(356, 76, 78, 4, (110, 76, 62))
d.polygon([(358, 80), (432, 80), (428, 112), (424, 118), (396, 122), (366, 116), (362, 112)],
          fill=(214, 190, 170))
for k, (xa, xb) in enumerate([(358, 372), (372, 388), (388, 404), (404, 418), (418, 432)]):
    d.line([(xa, 80), (xa + 1, 114 + (2 if k % 2 else 0))], fill=(176, 148, 130))
for y in range(86, 118, 8):
    d.line([(362, y), (428, y + 2)], fill=(190, 162, 146))
R(372, 94, 10, 10, (150, 116, 104))  # pièce
d.rectangle([372, 94, 381, 103], outline=(110, 80, 76))
d.polygon([(358, 80), (364, 80), (362, 112), (358, 100)], fill=(168, 140, 124))
R(366, 130, 56, 3, (110, 76, 62))
d.polygon([(368, 133), (420, 133), (418, 150), (396, 154), (370, 148)], fill=(196, 170, 152))
for xa in range(372, 420, 12):
    d.line([(xa, 133), (xa + 1, 150)], fill=(166, 138, 122))
R(428, 130, 44, 3, (110, 76, 62))
d.polygon([(430, 133), (470, 133), (468, 146), (450, 148), (432, 144)], fill=(204, 178, 160))
# pavillon noir en haut du grand mât
d.line([(394, 56), (394, 38)], fill=(60, 42, 50))
d.polygon([(394, 38), (418, 44), (394, 52)], fill=(26, 20, 38))
d.ellipse([401, 42, 406, 47], fill=(238, 230, 216))
d.line([(399, 49), (408, 42)], fill=(238, 230, 216))
d.line([(399, 42), (408, 49)], fill=(238, 230, 216))
# haubans
for (x0, y0, x1, y1) in [(394, 58, 330, 176), (394, 58, 350, 198), (394, 58, 444, 128),
                         (394, 58, 468, 194), (394, 80, 420, 196)]:
    d.line([(x0, y0), (x1, y1)], fill=(54, 38, 50))
# amarre vers le quai
d.line([(332, 196), (330, 192)], fill=(190, 150, 100))
d.line([(334, 206), (333, 196)], fill=(190, 150, 100))

# reflets des lumières dans l'eau
for (rx, ry, col) in [(336, 172, (255, 190, 100)), (96, 196, (255, 176, 90)),
                      (214, 196, (255, 176, 90)), (322, 196, (255, 176, 90))]:
    pass  # les reflets du quai sont cachés par le quai
for k in range(26):
    y = 236 + k
    x = 338 + rng.randrange(-4, 6) + int(2 * math.sin(k))
    d.line([(x, y), (x + rng.randrange(3, 8), y)], fill=(255, 190, 100) if k < 12 else (210, 130, 90))

# ---------------------------------------------------------------- lumière et palette
arr = np.asarray(base).astype(np.float32)
arr += np.asarray(emis).astype(np.float32) * 0.0  # l'émissif est déjà peint dans base
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
for (lx, ly, r, col, strength) in lights:
    dist = np.sqrt((xx - lx) ** 2 + (yy - ly) ** 2)
    a = np.clip(1.0 - dist / r, 0.0, 1.0) ** 2 * strength
    arr += a[..., None] * (np.array(col, dtype=np.float32) * 0.55)
# vignette sombre
cx, cy = W / 2, H / 2
v = 1.0 - 0.32 * np.clip(np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2) - 0.55, 0, 1)
arr *= v[..., None]
arr = np.clip(arr, 0, 255)

bayer = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]], dtype=np.float32) / 16.0 - 0.5
pattern = np.tile(bayer, (H // 4 + 1, W // 4 + 1))[:H, :W]
arr += pattern[..., None] * 9.0
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
img = img.quantize(colors=PALETTE_SIZE, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")

out = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
out.mkdir(parents=True, exist_ok=True)
img.save(out / "port_native.png")
img.resize((W * 3, H * 3), Image.Resampling.NEAREST).save(out / "port_x3.png")
print("ok", W, H, "couleurs:", len(set(img.getdata())))
