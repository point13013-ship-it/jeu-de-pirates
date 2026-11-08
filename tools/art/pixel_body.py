"""Le corps du pirate en pixel art : jambes, torse, bras, mains, vêtements, ceinture, bottes. Silhouette élancée (environ 3,6
têtes) : épaules à y = 32, taille à y = 45, chevilles à y = 63, pieds sur la ligne 67."""
import math

import numpy as np

from pixel_parts import layer, Pose, SHOULDER, WAIST, ANKLE, GROUND
from pixel_pirate import (m_poly, m_ell, m_limb, fill, poly, ell, rbox, limb, mir, line, dil, PX, PY, H, W)


# ------------------------------------------------------------------ squelette
def lerp(p, q, t):
    return (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)


def sub(pts, widths, a, b):
    """Le tronçon de la polyligne entre les fractions a et b de sa longueur (largeurs interpolées)."""
    lens = [math.dist(p, q) for p, q in zip(pts[:-1], pts[1:])]
    total = sum(lens)

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


def legs(view, P):
    """Les jambes : liste de dicts {side, pts (hanche, genou, cheville), far, lift} ; la jambe lointaine d'abord."""
    dy = P.dy
    out = []
    if view == "E":
        for far in (True, False):
            lift = P.plift[1 if far else 0]
            st = -P.stride if far else P.stride
            hip = (31.4, WAIST + 0.5 + dy)
            ank = (31.4 + st, ANKLE - lift)
            if P.jump or P.climb:
                ank = (31.4 + (-2 if far else 2), ANKLE - P.lift[1 if far else 0])
                lift = P.lift[1 if far else 0]
            knee = lerp(hip, ank, 0.5)
            knee = (knee[0] + (1.2 if st > 0 else 0.4 if st < 0 else 0.0), knee[1] - 0.5 * lift)
            out.append({"side": "far" if far else "near", "pts": [hip, knee, ank], "far": far, "lift": lift})
        return out
    sp = 1.6 if P.jump and P.crouch else 0.0
    tq = P.tq
    near = ("L" if tq == "SE" else "R") if tq else None        # en 3/4 le pirate regarde à droite : la jambe proche est celle du bord proche
    for side, x, sgn in (("L", 29.8, -1), ("R", 34.2, 1)):
        lift = P.lift[0 if side == "L" else 1]
        ank = (x + sgn * sp, ANKLE - lift)
        if tq:
            is_near = side == near
            lift = P.plift[0 if is_near else 1]
            if P.jump or P.climb:
                lift = P.lift[0 if side == "L" else 1]
            ank = (x + sgn * sp + P.stride * 0.55 * (1 if is_near else -1), ANKLE - lift)
        hip = (x, WAIST + 0.5 + dy)
        knee = lerp(hip, ank, 0.5)
        knee = (knee[0] + sgn * sp * 0.8, knee[1] - 0.5 * lift)
        out.append({"side": side, "pts": [hip, knee, ank], "far": tq is not None and side != near, "lift": lift})
    if tq:
        out.sort(key=lambda L: 0 if L["far"] else 1)           # la jambe lointaine d'abord
    return out


def arms(view, P):
    """Les bras : liste de dicts {side, pts (épaule, coude, main), far} ; le bras lointain d'abord (vue E)."""
    dy = P.dy
    res = []
    if view == "E":
        sw = -P.stride * 0.6
        for far in (True, False):
            k = 1.0 if far else -1.0
            s = (31.5, SHOULDER + 1.5 + dy)
            if P.carry or P.helm:
                pts = [s, (32.2 + (0.8 if far else 0), 40.0 + dy), (36.8 + (0.8 if far else 0), 41.5 + dy)]
            elif P.climb or P.jump:
                u = P.arms_up[1 if far else 0]
                pts = [s, (33.0, 36.0 - 4 * u + dy), (35.0, 45.0 - 18 * u + dy)]
            else:
                pts = [s, (31.6 + sw * k * 0.45, 39.5 + dy), (31.6 + sw * k, 45.2 + dy)]
            res.append({"side": "far" if far else "near", "pts": pts, "far": far})
        return res
    for side, sx, sgn in (("L", 25.4, -1), ("R", 38.6, 1)):
        i = 0 if side == "L" else 1
        s = (sx, SHOULDER + 1.5 + dy)
        if P.carry or P.helm:
            if view == "S":
                hand = (28.6 if side == "L" else 35.4, (42.5 if P.carry else 40.5) + dy)
                pts = [s, (sx + sgn * -0.4, 39.5 + dy), hand]
            else:
                pts = [s, (sx + sgn * 0.2, 39.0 + dy), (sx + sgn * -0.6, 41.5 + dy)]
        elif P.climb or P.jump:
            u = P.arms_up[i]
            hand = (sx + sgn * (-0.6 + 1.8 * u), 45.2 - 19 * u + dy * (1 - u))
            pts = [s, (sx + sgn * 1.4, 39.0 - 8 * u + dy), hand]
        else:
            sw = P.swing * (1 if side == "L" else -1)
            pts = [s, (sx + sgn * 0.7, 39.5 + dy + sw * 0.4), (sx + sgn * 0.5, 45.2 + dy + sw)]
            if P.tq:       # en 3/4 les bras balancent aussi d'avant en arrière (le bras proche, à l'opposé de la jambe proche)
                is_near = side == ("L" if P.tq == "SE" else "R")
                bx = -P.stride * 0.35 * (1 if is_near else -1)
                pts = [s, (pts[1][0] + bx * 0.5, pts[1][1]), (pts[2][0] + bx, pts[2][1])]
        res.append({"side": side, "pts": pts, "far": bool(P.tq) and side != ("L" if P.tq == "SE" else "R")})
    if P.tq:
        res.sort(key=lambda a: 0 if a["far"] else 1)
    return res


ARM_W = (3.8, 3.4, 2.8)
LEG_W = (5.4, 4.6, 3.8)


# ------------------------------------------------------------------ torse
def torso_pts(view, P, grow=0.0, bottom=0.0):
    dy = P.dy
    g = grow
    if view == "E":
        pts = [(28.4 - g, 33.0), (30.5, 31.2), (34.0, 31.2), (35.8 + g, 33.0), (35.4 + g, 40.0), (34.6 + g, 45.8 + bottom),
               (28.2 - g, 45.8 + bottom), (28.0 - g, 40.0)]
    else:
        pts = [(25.0 - g, 33.0), (27.5, 31.2), (36.5, 31.2), (39.0 + g, 33.0), (38.3 + g, 39.5), (37.0 + g, 45.8 + bottom),
               (27.0 - g, 45.8 + bottom), (25.7 - g, 39.5)]
    return [(x, y + dy) for x, y in pts]


# ------------------------------------------------------------------ mains
@layer("hands", "bare", "skin")
def hands(cv, view, P):
    for a in arms(view, P):
        if view == "N" and (P.carry or P.helm):
            continue
        x, y = a["pts"][-1]
        if view == "E" and a["far"] and 27.5 < x < 36.5 and y > 36:
            continue          # la main lointaine est cachée derrière le torse
        ell(cv, x, y + 0.8, 1.7, 1.9, bias=-1 if a["far"] else 0)


# ------------------------------------------------------------------ pantalon et bottes
def _pants(variant):
    cut = {"long": 1.0, "shorts": 0.42, "rolled": 0.72}[variant]

    @layer("pants", variant, "cloth")
    def cloth(cv, view, P):
        for L in legs(view, P):
            p, w = sub(L["pts"], LEG_W, 0.0, cut)
            limb(cv, p, w, bias=-1 if L["far"] else 0, outline=False)
        if view == "E":
            poly(cv, [(28.4, 44.2 + P.dy), (34.8, 44.2 + P.dy), (35.0, 49.0 + P.dy), (28.2, 49.0 + P.dy)], outline=False)
        else:
            poly(cv, [(26.6, 44.2 + P.dy), (37.4, 44.2 + P.dy), (37.8, 49.0 + P.dy), (26.2, 49.0 + P.dy)], outline=False)
        if variant == "rolled":
            for L in legs(view, P):
                p, w = sub(L["pts"], LEG_W, cut - 0.07, cut + 0.02)
                limb(cv, p, [x + 0.6 for x in w], bias=1, outline=False)
        cv.outline()

    if variant != "long":
        @layer("pants", variant, "skin")
        def skin(cv, view, P):
            for L in legs(view, P):
                p, w = sub(L["pts"], LEG_W, cut, 1.0)
                limb(cv, p, [x * 0.82 for x in w], bias=-1 if L["far"] else 0, outline=False)
            cv.outline()


for _v in ("long", "shorts", "rolled"):
    _pants(_v)


def _boot_poly(view, ax, ay, kind, lift):
    bot = GROUND + 1 - lift
    top = {"high": ay - 4.6, "shoes": ay + 2.2, "barefoot": ay + 2.2, "sandals": ay + 3.0}[kind]
    if view == "E":
        return [(ax - 2.7, top), (ax + 2.3, top), (ax + 2.5, ay + 1.8), (ax + 5.6, ay + 3.4), (ax + 5.6, bot), (ax - 3.0, bot), (ax - 3.0, top + 2)]
    return [(ax - 2.7, top), (ax + 2.7, top), (ax + 2.9, ay + 1.8), (ax + 3.6, ay + 3.2), (ax + 3.6, bot), (ax - 3.6, bot), (ax - 3.6, ay + 3.2), (ax - 2.9, ay + 1.8)]


def _boots(kind):
    slot = "skin" if kind == "barefoot" else "boot"

    @layer("boots", kind, slot)
    def boot(cv, view, P):
        for L in legs(view, P):
            ax, ay = L["pts"][-1]
            pts = _boot_poly(view, ax, ay, kind, L["lift"])
            if kind == "sandals":
                bot = GROUND + 1 - L["lift"]
                rbox(cv, int(round(ax)) - 3, int(bot) - 1, int(round(ax)) + (5 if view == "E" else 3), int(bot) - 1, 0.0, outline=True)
                continue
            poly(cv, pts, bias=-1 if L["far"] else 0)
            if kind == "high":
                top = ay - 4.6
                rbox(cv, int(round(ax)) - 3, int(top), int(round(ax)) + 2, int(top) + 1, 0.0, bias=1, outline=True)

    if kind == "sandals":
        @layer("boots", kind, "skin")
        def sandal_skin(cv, view, P):
            for L in legs(view, P):
                ax, ay = L["pts"][-1]
                bot = GROUND + 1 - L["lift"]
                poly(cv, [(ax - 2.4, bot - 4), (ax + 2.4, bot - 4), (ax + 3, bot - 1.2), (ax - 3, bot - 1.2)], bias=-1 if L["far"] else 0)


for _k in ("high", "shoes", "barefoot", "sandals"):
    _boots(_k)


# ------------------------------------------------------------------ chemises
def _sleeves(cv, view, P, widths, frac=1.0, far_first=True, bias=0):
    for a in arms(view, P):
        p, w = sub(a["pts"], widths, 0.0, frac)
        limb(cv, p, w, bias=bias - (1 if a["far"] else 0), outline=True)


@layer("shirt", "bare", "skin")
def shirt_bare(cv, view, P):
    for a in arms(view, P):
        if a["far"]:
            limb(cv, a["pts"], ARM_W, bias=-1)
    poly(cv, torso_pts(view, P), outline=True)
    for a in arms(view, P):
        if not a["far"]:
            limb(cv, a["pts"], ARM_W)


def _shirt(variant, widths, frac):
    @layer("shirt", variant, "cloth")
    def cloth(cv, view, P):
        for a in arms(view, P):
            if a["far"]:
                p, w = sub(a["pts"], widths, 0, frac)
                limb(cv, p, w, bias=-1)
        poly(cv, torso_pts(view, P, bottom=0.6), outline=True)
        for a in arms(view, P):
            if not a["far"]:
                p, w = sub(a["pts"], widths, 0, frac)
                limb(cv, p, w)


_shirt("tee", (4.6, 4.2, 3.6), 0.40)
_shirt("pirate", (5.0, 5.6, 4.4), 1.0)
_shirt("striped", (4.2, 3.8, 3.2), 1.0)


@layer("shirt", "tee", "skin")
def tee_skin(cv, view, P):
    for a in arms(view, P):
        p, w = sub(a["pts"], ARM_W, 0.36, 1.0)
        limb(cv, p, w, bias=-1 if a["far"] else 0)


@layer("shirt", "pirate", "skin")
def pirate_skin(cv, view, P):
    """Le col ouvert : un V de peau."""
    if view == "N":
        return
    dy = P.dy
    if view == "S":
        poly(cv, [(29.2, 31.2 + dy), (34.8, 31.2 + dy), (33.6, 35.0 + dy), (32, 37.5 + dy), (30.4, 35.0 + dy)], bias=-1, outline=True)
    else:
        poly(cv, [(32.6, 31.2 + dy), (35.4, 31.6 + dy), (35.6, 35.0 + dy), (34.0, 36.5 + dy)], bias=-1, outline=True)


@layer("shirt", "striped", "stripe")
def stripes(cv, view, P):
    m = m_poly(torso_pts(view, P, bottom=0.6))
    for k in range(4):
        y = 34 + k * 3 + P.dy
        band = (PY >= y) & (PY < y + 1.4) & m
        fill(cv, band, flat=3, outline=False)
    for a in arms(view, P):
        p, w = sub(a["pts"], (4.2, 3.8, 3.2), 0.0, 1.0)
        am = m_limb(p, w)
        for k in range(3):
            y = 37 + k * 3 + P.dy
            fill(cv, am & (PY >= y) & (PY < y + 1.2), flat=3, outline=False)


# ------------------------------------------------------------------ manteaux
@layer("coat", "vest", "cloth")
def coat_vest(cv, view, P):
    dy = P.dy
    m = m_poly(torso_pts(view, P, grow=0.4, bottom=1.0))
    if view == "S":
        m = m & ~m_poly([(30.0, 31 + dy), (34.0, 31 + dy), (33.2, 36 + dy), (32.6, 46.5 + dy), (31.4, 46.5 + dy), (30.8, 36 + dy)])
    fill(cv, m, outline=True)


@layer("coat", "vest", "trim")
def vest_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        for y in (38, 42):
            cv.px(29, y + dy, 5)
            cv.px(34, y + dy, 5)
    elif view == "E":
        for y in (38, 42):
            cv.px(34, y + dy, 5)


@layer("coat", "jacket", "cloth")
def coat_jacket(cv, view, P):
    for a in arms(view, P):
        if a["far"]:
            limb(cv, a["pts"], (5.0, 4.6, 4.0), bias=-1)
    poly(cv, torso_pts(view, P, grow=0.8, bottom=2.0), outline=True)
    for a in arms(view, P):
        if not a["far"]:
            limb(cv, a["pts"], (5.0, 4.6, 4.0))


@layer("coat", "jacket", "trim")
def jacket_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        line(cv, (32, 32 + dy), (32, 47 + dy), 5)
        cv.bmp(28, 31 + dy, ["5555"], mirror=True)
    elif view == "E":
        line(cv, (35, 33 + dy), (35, 47 + dy), 5)
    for a in arms(view, P):
        if view == "E" and a["far"]:
            continue
        x, y = a["pts"][-1]
        p, w = sub(a["pts"], (5.0, 4.6, 4.0), 0.88, 1.0)
        limb(cv, p, w, flat=5, outline=False)


@layer("coat", "captain", "cloth")
def coat_captain(cv, view, P):
    dy = P.dy
    for a in arms(view, P):
        if a["far"]:
            limb(cv, a["pts"], (5.4, 5.0, 4.4), bias=-1)
    skirt = [(25.0, 44 + dy), (39.0, 44 + dy), (40.8, 55), (23.2, 55)] if view != "E" else [(27.6, 44 + dy), (35.6, 44 + dy), (37.2, 55), (26.2, 55)]
    poly(cv, skirt, bias=-1, outline=True)
    poly(cv, torso_pts(view, P, grow=1.0, bottom=1.5), outline=True)
    for a in arms(view, P):
        if not a["far"]:
            limb(cv, a["pts"], (5.4, 5.0, 4.4))


@layer("coat", "captain", "trim")
def captain_trim(cv, view, P):
    dy = P.dy
    if view == "S":
        line(cv, (32, 32 + dy), (32, 54), 5)
        line(cv, (31, 32 + dy), (31, 57), 5) if False else None
        cv.bmp(27, 31 + dy, ["555.", "..55"], mirror=True)                   # le grand col
        for y in (37, 41, 48, 52):
            cv.px(30, y + (dy if y < 46 else 0), 5)
            cv.px(33, y + (dy if y < 46 else 0), 5)
    elif view == "E":
        line(cv, (36, 33 + dy), (36, 54), 5)
    elif view == "N":
        cv.bmp(28, 31 + dy, ["5555"], mirror=False)
    for a in arms(view, P):
        if view == "E" and a["far"]:
            continue
        p, w = sub(a["pts"], (5.4, 5.0, 4.4), 0.85, 0.97)
        limb(cv, p, w, flat=5, outline=False)


# ------------------------------------------------------------------ ceintures
@layer("belt", "belt", "belt")
def belt_belt(cv, view, P):
    dy = P.dy
    x0, x1 = (27, 36) if view == "E" else (26, 37)
    rbox(cv, x0, 43 + dy, x1, 45 + dy, 0.0, bias=-1)


@layer("belt", "belt", "buckle")
def belt_buckle(cv, view, P):
    dy = P.dy
    if view == "S":
        rbox(cv, 30, 42 + dy, 33, 46 + dy, 0.0, flat=5, outline=True)
    elif view == "E":
        rbox(cv, 34, 42 + dy, 36, 46 + dy, 0.0, flat=5, outline=True)


@layer("belt", "sash", "belt")
def belt_sash(cv, view, P):
    dy = P.dy
    x0, x1 = (27, 36) if view == "E" else (25, 38)
    rbox(cv, x0, 42 + dy, x1, 46 + dy, 0.0)
    tail = {"S": [(35, 46), (39, 46), (40, 55), (37, 56)], "E": [(28, 46), (32, 46), (31, 55), (28, 54)],
            "N": [(25, 46), (29, 46), (27, 55), (24, 54)]}[view]
    poly(cv, [(x, y + (dy if y < 47 else 0)) for x, y in tail], bias=-1)


@layer("belt", "baldric", "belt")
def belt_baldric(cv, view, P):
    dy = P.dy
    if view == "S":
        limb(cv, [(27.0, 32 + dy), (37.0, 45 + dy)], (2.8, 2.8))
    elif view == "E":
        limb(cv, [(29.5, 32 + dy), (34.5, 45 + dy)], (2.6, 2.6))
    else:
        limb(cv, [(37.0, 32 + dy), (27.0, 45 + dy)], (2.8, 2.8))


@layer("belt", "baldric", "buckle")
def baldric_buckle(cv, view, P):
    dy = P.dy
    if view in ("S", "E"):
        rbox(cv, 31, 37 + dy, 33, 39 + dy, 0.0, flat=5, outline=True)
