"""Pirate en PIXEL ART dessiné par script (style Eastward), personnalisable par couches.

Usage : voir pixel_build.py. Ce module est le moteur de dessin : des masques de pixels (polygones, membres effilés, ellipses)
remplis EN APLATS : un ton de base, un liseré de lumière sur les bords haut et gauche, une bande d'ombre sur les bords bas et
droit, puis un contour d'un ton très foncé (de la couleur de la pièce). Pas de dégradé de sphère : c'est ce qui donnait un
air de 3D. Le jeu tire les couleurs des tons (src/character/pirate_sprite.gd, `shade`) : ombres violettes, lumières chaudes.

Tons d'une feuille : 0 = contour, 1..5 = du plus sombre au plus clair (base = 4).
"""
import math
import os
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(os.environ["PIRATE_ROOT"]).resolve() if os.environ.get("PIRATE_ROOT") else Path(__file__).resolve().parents[2]

W, H = 64, 72                 # une image du pirate
FEET = (32, 68)               # le point au sol
TONES = (0.30, 0.46, 0.60, 0.74, 0.88, 1.0)
ANIMS = {"idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3}
VIEW_OF_DIR = ["S", "SE", "E", "NE", "N", "NE", "E", "SE"]       # direction du jeu -> vue dessinée
FLIP_OF_DIR = [False, False, False, False, False, True, True, True]

# Rotation 3/4 : une déformation horizontale des coordonnées. Les vues SE et NE appellent les fonctions de dessin des vues S et N
# avec cette déformation : le visage glisse vers le côté où le pirate regarde (et se raccourcit de l'autre côté), le torse se
# resserre un peu, la silhouette de la tête ne change pas. set_warp(f) : f envoie x (continu) vers x.
WARP = None


def set_warp(fx):
    global WARP
    WARP = fx


def _wx(x):
    return float(WARP(x)) if WARP is not None else x


YY, XX = np.mgrid[0:H, 0:W]
PX = XX + 0.5
PY = YY + 0.5


def nb(m, dx, dy):
    """nb(m, dx, dy)[y, x] = m[y + dy, x + dx] : l'état du voisin."""
    o = np.roll(m, (-dy, -dx), (0, 1))
    if dy > 0:
        o[-dy:, :] = False
    elif dy < 0:
        o[:-dy, :] = False
    if dx > 0:
        o[:, -dx:] = False
    elif dx < 0:
        o[:, :-dx] = False
    return o


def dil(m):
    return m | nb(m, 1, 0) | nb(m, -1, 0) | nb(m, 0, 1) | nb(m, 0, -1)


class Cv:
    """Une image de tons (-1 = vide, 0 = contour, 1..5 = ombrage)."""

    def __init__(self):
        self.t = np.full((H, W), -1, np.int8)

    def put(self, mask, idx, outline=False):
        if outline:
            self.t[dil(mask) & ~mask] = 0
        self.t[mask] = idx[mask] if isinstance(idx, np.ndarray) else idx

    def outline(self):
        """Un contour autour de tout ce qui est dessiné dans cette couche."""
        m = self.t >= 0
        self.t[dil(m) & ~m] = 0

    def px(self, x, y, idx):
        x, y = int(round(x)) if not isinstance(x, int) else x, int(round(y)) if not isinstance(y, int) else y
        if WARP is not None:
            x = int(math.floor(_wx(x + 0.5)))
        if 0 <= x < W and 0 <= y < H:
            self.t[y, x] = idx

    def bmp(self, x, y, rows, mirror=False):
        """Un petit motif : '.' = rien, '0'..'5' = ton. `mirror` ajoute le symétrique par rapport au centre (x = 32)."""
        for j, row in enumerate(rows):
            for i, ch in enumerate(row):
                if ch != ".":
                    self.px(int(x) + i, int(y) + j, int(ch))
                    if mirror:
                        self.px(W - 1 - (int(x) + i), int(y) + j, int(ch))


# ------------------------------------------------------------------ masques
def m_poly(pts):
    if WARP is not None:
        pts = [(_wx(x), y) for x, y in pts]
    img = Image.new("L", (W, H), 0)
    ImageDraw.Draw(img).polygon([(float(x), float(y)) for x, y in pts], fill=1)
    return np.asarray(img, bool)


def m_ell(cx, cy, rx, ry):
    if WARP is not None:
        a, b = _wx(cx - rx), _wx(cx + rx)
        cx, rx = (a + b) / 2, max(0.5, abs(b - a) / 2)
    return ((PX - cx) / rx) ** 2 + ((PY - cy) / ry) ** 2 <= 1.0


def m_rbox(x0, y0, x1, y1, rad=1.0):
    """Rectangle (pixels x0..x1, y0..y1 inclus) aux coins coupés de `rad`."""
    X0, Y0, X1, Y1 = x0, y0, x1 + 1, y1 + 1
    if WARP is not None:
        X0, X1 = _wx(X0), _wx(X1)
    dx = np.maximum(np.maximum(X0 + rad - PX, 0), PX - (X1 - rad))
    dy = np.maximum(np.maximum(Y0 + rad - PY, 0), PY - (Y1 - rad))
    return (dx * dx + dy * dy <= rad * rad + 1e-9) & (PX > X0) & (PX < X1) & (PY > Y0) & (PY < Y1)


def m_limb(pts, widths):
    """Un membre effilé : une ligne brisée dont la largeur varie d'un point à l'autre."""
    if WARP is not None:
        pts = [(_wx(x), y) for x, y in pts]
    best = np.full((H, W), 1e9)
    for (x0, y0), (x1, y1), w0, w1 in zip(pts[:-1], pts[1:], widths[:-1], widths[1:]):
        px, py = PX - x0, PY - y0
        dx, dy = x1 - x0, y1 - y0
        ll = dx * dx + dy * dy
        t = np.clip((px * dx + py * dy) / ll, 0, 1) if ll > 0 else np.zeros_like(px)
        d = np.hypot(px - t * dx, py - t * dy) - (w0 + (w1 - w0) * t) / 2
        best = np.minimum(best, d)
    return best <= 0


# ------------------------------------------------------------------ remplissage en aplats
def fill(cv, mask, bias=0, outline=True, flat=None, clip=None, light=True):
    """Ton de base (4) ; liseré clair en haut et à gauche ; bande d'ombre en bas et à droite (deux pixels si la forme est large)."""
    if clip is not None:
        mask = mask & clip
    if not mask.any():
        return mask
    if flat is not None:
        cv.put(mask, flat, outline)
        return mask
    base = int(np.clip(4 + bias, 1, 5))
    R = mask & ~nb(mask, 1, 0)
    B = mask & ~nb(mask, 0, 1)
    shadow = R | B
    wide = mask.sum() > 70
    if wide:
        shadow = shadow | (mask & (nb(R, 1, 0) | nb(B, 0, 1)) & ~(mask & ~nb(mask, -1, 0)) & ~(mask & ~nb(mask, 0, -1)))
    idx = np.full((H, W), base, np.int8)
    if light:
        hl = (mask & ~nb(mask, -1, 0)) | (mask & ~nb(mask, 0, -1))
        idx[hl & ~shadow] = min(5, base + 1)
    idx[shadow] = max(1, base - 1)
    cv.put(mask, idx, outline)
    return mask


def poly(cv, pts, **kw):
    return fill(cv, m_poly(pts), **kw)


def ell(cv, cx, cy, rx, ry, **kw):
    return fill(cv, m_ell(cx, cy, rx, ry), **kw)


def rbox(cv, x0, y0, x1, y1, rad=1.0, **kw):
    return fill(cv, m_rbox(x0, y0, x1, y1, rad), **kw)


def limb(cv, pts, widths, **kw):
    return fill(cv, m_limb(pts, widths), **kw)


def mir(pts, cx=32.0):
    """Le symétrique d'une liste de points par rapport à x = cx."""
    return [(2 * cx - x, y) for x, y in pts]


def line(cv, p0, p1, idx, mask=None):
    if WARP is not None:
        p0, p1 = (_wx(p0[0]), p0[1]), (_wx(p1[0]), p1[1])
    n = int(max(abs(p1[0] - p0[0]), abs(p1[1] - p0[1]), 1))
    for i in range(n + 1):
        x = int(round(p0[0] + (p1[0] - p0[0]) * i / n))
        y = int(round(p0[1] + (p1[1] - p0[1]) * i / n))
        if 0 <= x < W and 0 <= y < H and (mask is None or mask[y, x]):
            cv.t[y, x] = idx


def above(y):
    return PY < y


def below(y):
    return PY >= y
