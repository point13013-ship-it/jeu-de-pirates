"""Le corps du pirate en pixel art, à l'échelle EXACTE de la référence du joueur (un pirate de 35x52 pixels) : torse de 10 pixels,
bras et jambes de 2 pixels, jambes bien écartées, petites bottes, AUCUN contour noir (les formes se détachent par leur couleur).

Repère : colonne de la référence + 12 = x ; ligne de la référence + 16 = y. Le centre est x = 32,0 (la colonne c a pour symétrique
63 - c). Haut des épaules y = 35, bas de la chemise y = 49, écharpe y = 46-47, haut du pantalon y = 50, chevilles y = 61, pieds
sur la ligne 67. La tête (pixel_build.HEAD_XF) est réduite pour tomber sur ce cou."""
import math

import numpy as np

from pixel_parts import layer, Pose
from pixel_pirate import m_poly, m_ell, m_rbox, m_limb, fill, poly, line, nb, PX, PY, H, W, rigid_shift, no_warp

SHO = 35        # haut des épaules
HEM = 49        # dernière ligne de la chemise
HIP = 50        # première ligne du pantalon
ANK = 61        # première ligne de la cheville nue
GROUND = 67     # dernière ligne des pieds
CUFF = 47       # dernière ligne de la manche (au repos)


def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def sub(pts, widths, a, b):
    """Le tronçon de la polyligne entre les fractions a et b de sa longueur (largeurs interpolées)."""
    lens = [math.dist(p, q) for p, q in zip(pts[:-1], pts[1:])]
    total = sum(lens) or 1.0

    def at(f):
        f = max(0.0, min(1.0, f)) * total
        acc = 0.0
        for i, ln in enumerate(lens):
            if f <= acc + ln or i == len(lens) - 1:
                t = (f - acc) / ln if ln else 0.0
                return lerp(pts[i], pts[i + 1], t), widths[i] + (widths[i + 1] - widths[i]) * t, i
            acc += ln
    pa, wa, ia = at(a)
    pb, wb, ib = at(b)
    out_p, out_w = [pa], [wa]
    for i in range(ia + 1, ib + 1):
        out_p.append(pts[i])
        out_w.append(widths[i])
    out_p.append(pb)
    out_w.append(wb)
    return out_p, out_w


_DX = 0       # le décalage rigide en cours (voir `rigid`)


class rigid:
    """Un bloc `with rigid(x)` dessine un membre SANS la déformation 3/4, décalé d'un bloc de tout ce que la déformation fait au
    point x : le membre garde ses 2 pixels de large (la déformation les écrasait à 1 : une jambe devenait « hyper fine » en
    pivotant)."""

    def __init__(self, cx):
        self.dx = rigid_shift(cx)

    def __enter__(self):
        global _DX
        self._nw = no_warp()
        self._nw.__enter__()
        self._old, _DX = _DX, self.dx

    def __exit__(self, *exc):
        global _DX
        _DX = self._old
        self._nw.__exit__(*exc)


def box(x0, y0, x1, y1):
    """Un rectangle de pixels (bornes incluses)."""
    return m_rbox(x0 + _DX, y0, x1 + _DX, y1, 0.0)


def stair_poly(pts, widths):
    """Un membre en ESCALIER : pour chaque ligne de pixels, un bloc de largeur entière (2 pixels, 3 pour une manche bouffante) centré
    sur la ligne brisée. Un membre incliné garde ainsi sa largeur partout (le tracé « capsule » le réduisait à un fil de 1 pixel)."""
    pts = [(float(x), float(y)) for x, y in pts]
    ws = [float(w) for w in widths]
    # on prolonge les deux bouts d'un pixel : le membre déborde de ses points, comme un trait épais
    def ext(a, b):
        d = math.hypot(b[0] - a[0], b[1] - a[1]) or 1.0
        return (a[0] + (a[0] - b[0]) / d, a[1] + (a[1] - b[1]) / d)
    pts = [ext(pts[0], pts[1])] + pts + [ext(pts[-1], pts[-2])]
    ws = [ws[0]] + ws + [ws[-1]]
    m = np.zeros((H, W), bool)
    for (x0, y0), (x1, y1), w0, w1 in zip(pts[:-1], pts[1:], ws[:-1], ws[1:]):
        if abs(y1 - y0) < 1e-6:
            continue
        for y in range(int(math.ceil(min(y0, y1) - 0.5)), int(math.floor(max(y0, y1) - 0.5)) + 1):
            if not 0 <= y < H:
                continue
            t = (y + 0.5 - y0) / (y1 - y0)
            xc, w = x0 + (x1 - x0) * t, w0 + (w1 - w0) * t
            wi = max(1, int(math.floor(w + 0.5)))
            left = int(math.floor(xc - wi / 2.0 + 0.5))
            m[y, max(left, 0):max(min(left + wi, W), 0)] = True
    return m


def _lm(pts, widths):
    return stair_poly([(x + _DX, y) for x, y in pts], widths)


def limb_rigid(pts, widths):
    with rigid(sum(p[0] for p in pts) / len(pts)):
        return _lm(pts, widths)


def paint(cv, mask, base=4, edge=None, top=None, bottom=None):
    """Un aplat sans contour : un ton de base, un ton plus sombre sur la colonne de droite (`edge`) et, au choix, sur la ligne du haut
    (`top`) ou du bas (`bottom`) ; aucun liseré clair : la référence est plate."""
    if not mask.any():
        return mask
    idx = np.full((H, W), base, np.int8)
    if top is not None:
        idx[mask & ~nb(mask, 0, -1)] = top
    if bottom is not None:
        idx[mask & ~nb(mask, 0, 1)] = bottom
    if edge is not None:
        idx[mask & ~nb(mask, 1, 0)] = edge
    cv.put(mask, idx, False)
    return mask


# ------------------------------------------------------------------ squelette
def legs(view, P):
    """Les jambes : liste de dicts {side, hx (axe de la hanche), ax, ay (cheville : x et première ligne nue), far, lift} ; la jambe
    lointaine d'abord."""
    out = []
    if view == "E":
        for far in (True, False):
            lift = P.plift[1 if far else 0]
            st = -P.stride if far else P.stride
            ax = 32.0 + st * 0.8
            if P.jump or P.climb:
                lift = P.lift[1 if far else 0]
                ax = 32.0 + (-2 if far else 2)
            out.append({"side": "far" if far else "near", "hx": 32.0, "ax": ax, "ay": ANK - lift, "far": far, "lift": lift})
        return out
    sp = 1.6 if P.jump and P.crouch else 0.0
    tq = P.tq
    near = ("L" if tq == "SE" else "R") if tq else None
    for side, hx, lx, sgn in (("L", 28.5, 28.0, -1), ("R", 35.5, 36.0, 1)):
        lift = P.lift[0 if side == "L" else 1]
        ax = lx + sgn * sp
        if tq:
            is_near = side == near
            lift = P.plift[0 if is_near else 1]
            if P.jump or P.climb:
                lift = P.lift[0 if side == "L" else 1]
            ax = lx + sgn * sp + P.stride * 0.4 * (1 if is_near else -1)
        out.append({"side": side, "hx": hx, "ax": ax, "ay": ANK - lift, "far": tq is not None and side != near, "lift": lift})
    if tq:
        out.sort(key=lambda L: 0 if L["far"] else 1)
    return out


def arms(view, P):
    """Les bras : liste de dicts {side, pts (épaule, coude, poignet), far} ; le bras lointain d'abord (vue E)."""
    dy = P.dy
    res = []
    if P.aim:
        return aim_arms(view, P)
    if view == "E":
        sw = P.stride * 0.5            # le bras proche part à l'opposé du pied proche
        for far in (True, False):
            k = 1.0 if far else -1.0
            s = (32.0, SHO + 1.0 + dy)
            if P.carry or P.helm:
                pts = [s, (32.0 + (0.5 if far else 0), 41.0 + dy), (35.0 + (0.5 if far else 0), 44.0 + dy)]
            elif P.climb or P.jump:
                u = P.arms_up[1 if far else 0]
                pts = [s, (33.5, 40.0 - 4 * u + dy), (35.0, 47.0 - 19 * u + dy)]
            else:
                pts = [s, (32.0 + sw * k * 0.5, 41.5 + dy), (32.0 + sw * k, CUFF + dy)]
            res.append({"side": "far" if far else "near", "pts": pts, "far": far})
        return res
    for side, sx, sgn in (("L", 26.0, -1), ("R", 38.0, 1)):
        i = 0 if side == "L" else 1
        s = (sx, SHO + 1.0 + dy)
        if P.carry or P.helm:
            if view == "S":
                hand = (29.5 if side == "L" else 34.5, (46.0 if P.carry else 43.0) + dy)
                pts = [s, (sx + sgn * 0.2, 41.0 + dy), hand]
            else:
                pts = [s, (sx + sgn * 0.2, 41.0 + dy), (sx - sgn * 0.6, 44.0 + dy)]
        elif P.climb or P.jump:
            u = P.arms_up[i]
            pts = [s, (sx + sgn * 1.5, 40.0 - 8 * u + dy), (sx + sgn * (0.4 + 2.0 * u), CUFF - 20 * u + dy * (1 - u))]
        else:
            sw = P.swing * (1 if side == "L" else -1)
            pts = [s, (sx + sgn * 0.8, 41.5 + dy + sw * 0.4), (sx + sgn * 0.2, CUFF + dy + sw)]
            if P.tq:
                is_near = side == ("L" if P.tq == "SE" else "R")
                bx = -P.stride * 0.35 * (1 if is_near else -1)
                pts = [s, (pts[1][0] + bx * 0.5, pts[1][1]), (pts[2][0] + bx, pts[2][1])]
        res.append({"side": side, "pts": pts, "far": bool(P.tq) and side != ("L" if P.tq == "SE" else "R")})
    if P.tq:
        res.sort(key=lambda a: 0 if a["far"] else 1)
    return res


def aim_arms(view, P):
    """Les bras quand on tire ou lance un pouvoir (P.reach : 0 repos, 1 tendus vers l'avant, négatif ramenés à la taille ;
    P.arm_lift : mains levées en pixels). Vue E : de profil, bras horizontaux vers l'avant ; S : face à la caméra, les bras
    viennent vers elle et les mains se rejoignent devant la poitrine ; N : de dos, les bras partent devant, loin de la caméra ;
    3/4 (SE, NE) : bras tendus vers la droite de l'image. `fist` : poing fermé (un bloc), au lieu de la main pendante."""
    r, lift, dy = P.reach, P.arm_lift, P.dy
    fist = (P.shoot or r > 0.5) and lift < 11.0
    res = []
    if view == "E":
        for far in (True, False):
            s = (32.0, SHO + 1.0 + dy)
            ex = 32.0 + 4.0 * r - (0.5 if far else 0.0)
            wx = 32.0 + 9.0 * r - (1.5 if far else 0.0)
            ey = SHO + 3.5 + dy - lift * 0.4
            wy = SHO + 3.5 + dy - lift + (0.8 if far else 0.0)
            res.append({"side": "far" if far else "near", "pts": [s, (ex, ey), (wx, wy)], "far": far, "fist": fist})
        return res
    for side, sx, sgn in (("L", 26.0, -1), ("R", 38.0, 1)):
        s = (sx, SHO + 1.0 + dy)
        if P.tq:
            near = side == ("L" if P.tq == "SE" else "R")
            k = 1.0 if near else 0.8
            up = 1.0 if P.tq == "NE" else 0.0
            ex = sx + 4.0 * max(r, 0.0) * k + (0.0 if r > 0 else sgn * 0.5)
            wx = sx + 8.5 * r * k + 2.0 * (1 if near else 0)
            ey = SHO + 6.0 + dy - lift * 0.4 - up
            wy = SHO + 8.0 + dy - lift - up - (0.0 if near else 1.0)
            pts = [s, (ex, ey), (wx, wy)]
        elif view == "S":
            ex = sx + sgn * (0.8 - 0.8 * max(r, 0.0))
            ey = SHO + 7.0 + dy - lift * 0.35
            hx = 32.0 - sgn * (1.6 if r > 0.5 else 2.6) + (sgn * 3.5 if r < 0 else 0.0)
            hy = SHO + 9.5 + dy - lift
            pts = [s, (ex, ey), (hx, hy)]
        elif P.shoot:   # N, tir : de dos l'arme part devant, loin de la caméra : on la voit dépasser sur le côté droit, main d'appui dessous
            if sgn > 0:
                pts = [s, (sx + 1.2, SHO + 6.5 + dy - lift * 0.4), (39.5, SHO + 4.5 + dy - lift)]
            else:
                pts = [s, (sx + 3.0, SHO + 8.0 + dy - lift * 0.4), (35.0, SHO + 6.5 + dy - lift)]
        else:   # N : de dos
            ex = sx + sgn * 0.4
            ey = SHO + 5.5 + dy - lift * 0.4
            hx = 32.0 - sgn * (3.0 if r > 0.5 else 3.8)
            hy = SHO + 3.5 + dy - lift
            pts = [s, (ex, ey), (hx, hy)]
        res.append({"side": side, "pts": pts, "far": bool(P.tq) and side != ("L" if P.tq == "SE" else "R"), "fist": fist})
    if P.tq:
        res.sort(key=lambda a: 0 if a["far"] else 1)
    return res


# largeurs des manches (2 pixels comme la référence ; la chemise de pirate est bouffante)
SLV = {"striped": (2.0, 2.0, 2.0), "tee": (2.4, 2.2, 2.0), "pirate": (2.6, 3.2, 2.4), "coat": (2.8, 2.6, 2.4), "bare": (2.0, 2.0, 2.0)}


def sleeve(a, widths, frac=1.0, f0=0.0):
    p, w = sub(a["pts"], widths, f0, frac)
    return limb_rigid(p, w)


def torso_mask(view, P, grow=0, bottom=0):
    dy = P.dy
    x0, x1 = (29, 34) if view == "E" else (27, 36)
    return box(x0 - grow, SHO + dy, x1 + grow, HEM + dy + bottom)


# ------------------------------------------------------------------ mains
def hand_mask(view, a):
    """La main de la référence : un poignet de 2 pixels sur 3 lignes, puis une paume de 3 pixels sur 4 lignes qui s'écarte du corps,
    un pouce qui dépasse. Pour un bras levé : un petit bloc de 3x3."""
    (ex, ey), (x, y) = a["pts"][-2], a["pts"][-1]
    out = -1 if (view != "E" and a["side"] == "L") else 1       # le côté du pouce : à l'extérieur du corps (vue E : vers l'avant)
    with rigid(x):
        if a.get("fist") and ey - y <= 4:                       # poing serré (visée, sort lancé) : un bloc de 3x3 au bout du bras
            x0 = int(math.floor(x - 1.0))
            return box(x0, int(round(y)) - 1, x0 + 2, int(round(y)) + 1)
        if ey - y > 4:                                          # bras levé
            x0 = int(math.floor(x - 1.2))
            return box(x0, int(round(y)) - 2, x0 + 2, int(round(y)))
        cx = int(math.floor(x))                                 # la colonne gauche du poignet
        y0 = int(round(y)) + 1
        if out > 0:
            return box(cx, y0, cx + 1, y0 + 2) | box(cx, y0 + 3, cx + 2, y0 + 6) | box(cx + 3, y0 + 3, cx + 3, y0 + 3)
        return box(cx, y0, cx + 1, y0 + 2) | box(cx - 1, y0 + 3, cx + 1, y0 + 6) | box(cx - 2, y0 + 3, cx - 2, y0 + 3)


@layer("hands", "bare", "skin")
def hands(cv, view, P):
    for a in arms(view, P):
        if view == "N" and (P.carry or P.helm or (P.aim and P.reach > 0.5 and not P.tq and a["side"] == "L")):
            continue
        x, y = a["pts"][-1]
        if view == "E" and a["far"] and 28.5 < x < 35.5 and y > 40:
            continue          # la main lointaine est cachée derrière le torse
        paint(cv, hand_mask(view, a), 4 - (1 if a["far"] else 0), edge=3 - (1 if a["far"] else 0))


# ------------------------------------------------------------------ pantalon, chevilles et bottes
def _leg_mask(L, view, P, top, bottom):
    """Le pantalon d'une jambe de la ligne `top` à la ligne `bottom` (incluse) : 3 pixels de large en haut, 2 en bas."""
    hx, ax = L["hx"], L["ax"]
    if view == "E":
        thigh = box(int(hx) - 1, top, int(hx) + 1, min(bottom, 54 + P.dy))               # une cuisse de 3 pixels, puis 2
        if bottom <= 54 + P.dy:
            return thigh
        return thigh | _lm([(hx, 54 + P.dy), (ax, bottom + 0.5)], (2.0, 2.0))
    with rigid(hx):
        split = 54 + P.dy
        upper = box(int(hx - 1.5), top, int(hx - 1.5) + 2, min(bottom, split))
        if bottom <= split:
            return upper
        lx = 28.0 if hx < 32 else 36.0
        if abs(ax - lx) < 0.3:
            return upper | box(int(lx - 1), split + 1, int(lx), bottom)
        # une jambe en mouvement : UNE ligne brisée de la hanche à la cheville (3 pixels en haut, 2 en bas), pas une barre
        # verticale puis un fil oblique
        mid = ((hx + ax) / 2.0, (top + bottom) / 2.0)
        return _lm([(hx, top), mid, (ax, bottom)], (3.0, 2.6, 2.0)) | box(int(hx - 1.5), top, int(hx - 1.5) + 2, top + 1)


def _pants(variant):
    cut = {"long": ANK - 1, "shorts": 56, "rolled": 58}[variant]

    @layer("pants", variant, "cloth")
    def cloth(cv, view, P):
        dy = P.dy
        for L in legs(view, P):
            bottom = min(cut, L["ay"] - 1)
            m = _leg_mask(L, view, P, HIP + 2 + dy, bottom)
            paint(cv, m, 4 - (1 if L["far"] else 0), edge=3 - (1 if L["far"] else 0))
            if variant == "rolled":
                paint(cv, m & (PY >= bottom - 1), 5, edge=4)
        x0, x1 = (29, 34) if view == "E" else (27, 36)
        paint(cv, box(x0, HIP + dy, x1, HIP + 1 + dy), 4, edge=3)

    if variant != "long":
        @layer("pants", variant, "skin")
        def skin(cv, view, P):
            for L in legs(view, P):
                top = cut + 1
                if top <= L["ay"] - 1:
                    m = _leg_mask(L, view, P, top, L["ay"] - 1)
                    paint(cv, m & (PY >= top), 4 - (1 if L["far"] else 0), edge=3 - (1 if L["far"] else 0))


for _v in ("long", "shorts", "rolled"):
    _pants(_v)


def _foot_masks(view, L, kind):
    """Les masques d'un pied de la référence : (corps, semelle). La botte : 2 pixels de large en haut, puis 3 et 4 en bas qui
    s'écartent vers l'extérieur ; la semelle est la dernière ligne."""
    ax, lift = L["ax"], L["lift"]
    ay = L["ay"]
    top = ay + 3 if kind in ("shoes", "barefoot") else ay - 3
    if kind == "sandals":
        top = ay + 5
    bot = GROUND - lift
    x = int(math.floor(ax)) - 1                 # colonne gauche de la jambe (2 pixels : x, x + 1)
    if view == "E":
        shaft = box(x, top, x + 1, bot - 2)
        foot = box(x, bot - 1, x + 5, bot)
        return shaft | foot, box(x, bot, x + 5, bot)
    out = -1 if L["hx"] < 32 else 1
    with rigid(L["hx"]):
        if kind == "high":
            shaft = box(x - 1, top, x + 1, bot - 2)
            lo, hi = x - 1 + min(out, 0), x + 1 + max(out, 0)
            return shaft | box(lo, bot - 1, hi, bot), box(lo, bot, hi, bot)
        shaft = box(x, top, x + 1, bot - 2)
        if out < 0:
            foot = box(x - 1, bot - 1, x + 1, bot - 1) | box(x - 2, bot, x + 1, bot)
            sole = box(x - 2, bot, x + 1, bot)
        else:
            foot = box(x, bot - 1, x + 2, bot - 1) | box(x, bot, x + 3, bot)
            sole = box(x, bot, x + 3, bot)
        return shaft | foot, sole


def _boots(kind):
    slot = "skin" if kind == "barefoot" else "boot"

    @layer("boots", kind, slot)
    def boot(cv, view, P):
        for L in legs(view, P):
            body, sole = _foot_masks(view, L, kind)
            if kind == "sandals":
                paint(cv, sole, 3)
                continue
            if kind == "barefoot":
                paint(cv, body, 4 - (1 if L["far"] else 0), edge=3 - (1 if L["far"] else 0))
                continue
            paint(cv, body, 4 - (1 if L["far"] else 0), edge=3 - (1 if L["far"] else 0))
            cv.put(sole, 1, False)
            if kind == "high":
                paint(cv, body & (PY < L["ay"] - 1), 5, edge=4)          # le revers de la botte

    if kind in ("shoes", "sandals"):
        @layer("boots", kind, "skin")
        def ankles(cv, view, P):
            for L in legs(view, P):
                x0 = int(math.floor(L["ax"])) - 1
                ay = L["ay"]
                bot = ay + (2 if kind == "shoes" else 4)
                with rigid(L["hx"]):
                    m = box(x0, ay, x0 + 1, bot)
                paint(cv, m, 4 - (1 if L["far"] else 0), edge=3 - (1 if L["far"] else 0))


for _k in ("high", "shoes", "barefoot", "sandals"):
    _boots(_k)


# ------------------------------------------------------------------ chemises
def _shirt_masks(view, P, widths, frac=1.0, grow=0, bottom=0):
    far = [sleeve(a, widths, frac) for a in arms(view, P) if a["far"]]
    near = [sleeve(a, widths, frac) for a in arms(view, P) if not a["far"]]
    return far, torso_mask(view, P, grow, bottom), near


def _cloth(cv, view, P, widths, frac=1.0, grow=0, bottom=0, base=5, shadow=3):
    far, tor, near = _shirt_masks(view, P, widths, frac, grow, bottom)
    for m in far:
        paint(cv, m, base - 1, edge=shadow - 1)
    paint(cv, tor, base, edge=shadow)
    for m in near:
        paint(cv, m, base, edge=shadow)


@layer("shirt", "bare", "skin")
def shirt_bare(cv, view, P):
    _cloth(cv, view, P, SLV["bare"], base=4, shadow=3)


def _shirt(variant, key, frac, base=5):
    @layer("shirt", variant, "cloth")
    def cloth(cv, view, P):
        _cloth(cv, view, P, SLV[key], frac, bottom=0, base=base)


_shirt("tee", "tee", 0.40)
_shirt("pirate", "pirate", 1.0)
_shirt("striped", "striped", 1.0)


@layer("shirt", "tee", "skin")
def tee_skin(cv, view, P):
    for a in arms(view, P):
        paint(cv, sleeve(a, SLV["bare"], 1.0, 0.36), 4 - (1 if a["far"] else 0), edge=3)


@layer("shirt", "pirate", "skin")
def pirate_skin(cv, view, P):
    """Le col ouvert : un V de peau."""
    if view == "N":
        return
    dy = P.dy
    if view == "S":
        paint(cv, box(30, SHO + dy, 33, SHO + 1 + dy) | box(31, SHO + 2 + dy, 32, SHO + 4 + dy), 4, edge=3)
    else:
        paint(cv, box(33, SHO + dy, 34, SHO + 3 + dy), 4)


@layer("shirt", "pirate", "lace")
def pirate_lace(cv, view, P):
    dy = P.dy
    if view == "S":
        line(cv, (30.5, SHO + 1.0 + dy), (32.5, SHO + 4.0 + dy), 4)
        line(cv, (33.5, SHO + 1.0 + dy), (31.5, SHO + 4.0 + dy), 4)


@layer("shirt", "striped", "stripe")
def stripes(cv, view, P):
    """Les rayures de la référence : des bandes de deux lignes, claires et bleutées, sur le torse ET les manches."""
    dy = P.dy
    tor = torso_mask(view, P)
    for a in arms(view, P):
        tor = tor | sleeve(a, SLV["striped"])
    band = (np.floor((PY - SHO - dy) / 2.0).astype(int) % 2 == 0) & tor
    paint(cv, band, 4, edge=3)
    if view == "S":                                  # le col rond : un liseré plus sombre autour du cou (y = 35..37)
        for x, y, t in ((29, 35, 3), (34, 35, 3), (30, 36, 3), (33, 36, 3), (29, 36, 2), (34, 36, 2), (30, 37, 3), (31, 37, 3), (32, 37, 3), (33, 37, 3)):
            cv.px(x, y + dy, t)


# ------------------------------------------------------------------ manteaux
@layer("coat", "vest", "cloth")
def coat_vest(cv, view, P):
    dy = P.dy
    m = torso_mask(view, P, 0, 2)
    if view == "S":
        m = m & ~box(31, SHO + dy, 32, HEM + 2 + dy)
    paint(cv, m, 4, edge=3)


@layer("coat", "vest", "trim")
def vest_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        for y in (40, 44):
            cv.px(29, y + dy, 5)
            cv.px(34, y + dy, 5)
    elif view == "E":
        for y in (40, 44):
            cv.px(33, y + dy, 5)


@layer("coat", "jacket", "cloth")
def coat_jacket(cv, view, P):
    _cloth(cv, view, P, SLV["coat"], 1.0, grow=1, bottom=3, base=4, shadow=3)


@layer("coat", "jacket", "trim")
def jacket_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        line(cv, (31.5, SHO + dy), (31.5, HEM + 3 + dy), 5)
    elif view == "E":
        line(cv, (33.5, SHO + dy), (33.5, HEM + 3 + dy), 5)
    for a in arms(view, P):
        if view == "E" and a["far"]:
            continue
        p, w = sub(a["pts"], SLV["coat"], 0.86, 1.0)
        cv.put(limb_rigid(p, w), 5, False)


@layer("coat", "captain", "cloth")
def coat_captain(cv, view, P):
    dy = P.dy
    far, tor, near = _shirt_masks(view, P, SLV["coat"], 1.0, 1, 3)
    for m in far:
        paint(cv, m, 3, edge=2)
    skirt = [(26.0, 49 + dy), (38.0, 49 + dy), (39.4, 59), (24.6, 59)] if view != "E" else [(28.4, 49 + dy), (35.6, 49 + dy), (36.6, 59), (27.4, 59)]
    paint(cv, m_poly(skirt), 3, edge=2)
    paint(cv, tor, 4, edge=3)
    for m in near:
        paint(cv, m, 4, edge=3)


@layer("coat", "captain", "trim")
def captain_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        line(cv, (31.5, SHO + dy), (31.5, 58), 5)
        cv.bmp(28, SHO + dy, ["55.", "..5"], mirror=True)
        cv.bmp(25, SHO + 1 + dy, ["55"], mirror=True)
        for y in (39, 43, 52, 56):
            cv.px(30, y, 5)
            cv.px(33, y, 5)
    elif view == "E":
        line(cv, (34.5, SHO + dy), (34.5, 58), 5)
    for a in arms(view, P):
        if view == "E" and a["far"]:
            continue
        p, w = sub(a["pts"], SLV["coat"], 0.86, 0.98)
        cv.put(limb_rigid(p, w), 5, False)


# ------------------------------------------------------------------ ceintures
@layer("belt", "belt", "belt")
def belt_belt(cv, view, P):
    dy = P.dy
    x0, x1 = (29, 34) if view == "E" else (27, 36)
    paint(cv, box(x0, 46 + dy, x1, 47 + dy), 3, edge=2)


@layer("belt", "belt", "buckle")
def belt_buckle(cv, view, P):
    dy = P.dy
    if view == "S":
        cv.put(box(30, 45 + dy, 33, 48 + dy), 5, False)
        cv.put(box(31, 46 + dy, 32, 47 + dy), 2, False)
    elif view == "E":
        cv.put(box(33, 45 + dy, 34, 48 + dy), 5, False)


@layer("belt", "sash", "belt")
def belt_sash(cv, view, P):
    """L'écharpe de la référence : deux lignes à bandes claires et sombres en damier, un nœud et deux pans qui pendent."""
    dy = P.dy
    if view == "E":
        paint(cv, box(29, 46 + dy, 34, 47 + dy), 4, edge=3)
        cv.put(box(28, 47 + dy, 29, 52 + dy), 3, False)
        cv.put(box(27, 51 + dy, 28, 54 + dy), 3, False)
        return
    row1 = [4, 4, 4, 3, 3, 3, 3, 4, 4, 4]
    row2 = [3, 3, 3, 4, 4, 4, 4, 3, 3, 3]
    for i, (a, b) in enumerate(zip(row1, row2)):
        x = 27 + i
        cv.put(box(x, 46 + dy, x, 46 + dy), a, False)
        cv.put(box(x, 47 + dy, x, 47 + dy), b, False)
    if view == "S":
        cv.put(box(34, 48 + dy, 35, 48 + dy), 3, False)
        cv.put(box(35, 49 + dy, 35, 54 + dy), 3, False)
        cv.put(box(33, 50 + dy, 33, 50 + dy), 3, False)
        cv.put(box(32, 51, 32, 54), 3, False)
    else:
        cv.put(box(28, 48 + dy, 29, 48 + dy), 3, False)
        cv.put(box(28, 49 + dy, 28, 54 + dy), 3, False)
        cv.put(box(31, 50, 31, 54), 3, False)


@layer("belt", "baldric", "belt")
def belt_baldric(cv, view, P):
    dy = P.dy
    if view == "S":
        cv.put(m_limb([(28.0, SHO + dy), (36.0, HEM + dy)], (1.8, 1.8)), 3, False)
    elif view == "E":
        cv.put(m_limb([(30.0, SHO + dy), (34.0, HEM + dy)], (1.6, 1.6)), 3, False)
    else:
        cv.put(m_limb([(36.0, SHO + dy), (28.0, HEM + dy)], (1.8, 1.8)), 3, False)


@layer("belt", "baldric", "buckle")
def baldric_buckle(cv, view, P):
    dy = P.dy
    if view in ("S", "E"):
        cv.put(box(31, 41 + dy, 32, 43 + dy), 5, False)
