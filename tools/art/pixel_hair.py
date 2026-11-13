"""Cheveux, barbes, moustaches et chapeaux en pixel art : des silhouettes ANGULAIRES (mèches, franges en pointes), pas des
calottes rondes. Les points sont (x, v) avec v mesuré depuis le haut du crâne (voir pixel_parts.T) ; vue S de face, E de profil
(face à droite), N de dos."""
import numpy as np

from pixel_parts import layer, head_top, T
from pixel_pirate import (m_poly, m_ell, m_limb, fill, poly, ell, rbox, limb, mir, line, nb, dil, PX, PY, H, W)


def hair_fill(cv, pts, strands=(), lights=(), bias=0, outline=True):
    """Une masse de cheveux : aplat + liseré, puis des mèches sombres et des reflets clairs tracés dans la masse."""
    m = m_poly(pts)
    fill(cv, m, bias=bias, outline=outline)
    for a, b in strands:
        line(cv, a, b, max(1, 3 + bias), m)
    for a, b in lights:
        line(cv, a, b, min(5, 5 + bias), m)
    return m


# ------------------------------------------------------------------ la calotte (base de presque toutes les coiffures)
def cap_pts(view):
    if view == "S":
        return [(24.8, 11.0), (24.0, 6.0), (24.2, 3.0), (26.0, 0.2), (29.0, -1.8), (32.0, -2.4), (35.0, -1.8), (38.0, 0.2),
                (39.8, 3.0), (40.0, 6.0), (39.2, 11.0), (37.8, 8.6), (37.6, 5.6), (36.6, 4.6), (35.8, 3.4), (34.6, 5.0), (33.6, 3.4),
                (32.4, 5.2), (31.4, 3.6), (30.2, 5.2), (29.2, 3.6), (28.0, 5.2), (27.0, 4.0), (26.4, 5.8), (26.2, 8.6)]
    if view == "N":
        return [(24.2, 13.0), (23.8, 6.0), (24.2, 3.0), (26.0, 0.2), (29.0, -1.8), (32.0, -2.4), (35.0, -1.8), (38.0, 0.2),
                (39.8, 3.0), (40.2, 6.0), (39.8, 13.0), (38.4, 14.4), (36.0, 13.4), (34.0, 15.0), (32.0, 13.8), (30.0, 15.0),
                (28.0, 13.4), (25.6, 14.4)]
    return [(38.2, 3.6), (37.2, 0.8), (35.0, -1.4), (32.0, -2.4), (28.6, -1.8), (25.8, 0.2), (23.8, 3.4), (23.2, 7.0), (23.6, 11.0),
            (24.6, 14.4), (26.6, 14.2), (27.8, 11.6), (28.2, 8.0), (28.6, 5.6), (30.0, 4.6), (31.8, 5.0), (32.6, 7.2), (33.6, 4.4),
            (34.8, 5.6), (35.6, 3.8), (36.6, 5.0), (37.4, 3.2)]


def cap_strands(view):
    if view == "S":
        return ([((30.4, -1.6), (28.4, 0.6)), ((28.4, 0.6), (26.6, 3.4)), ((33.6, -1.6), (35.8, 0.6)), ((35.8, 0.6), (37.4, 3.6)),
                 ((31.4, -1.2), (30.6, 2.4)), ((32.8, -1.2), (33.6, 2.4))],
                [((26.2, 1.4), (29.0, -1.0)), ((29.5, -1.4), (31.0, -1.7))])
    if view == "N":
        return ([((32, -1.6), (32, 4)), ((30.4, -1.2), (28.4, 4)), ((33.6, -1.2), (35.6, 4)), ((28, 6), (27, 11)), ((36, 6), (37, 11)),
                 ((32, 7), (32, 12))], [((26.2, 1.4), (29.0, -1.0)), ((29.5, -1.4), (31.0, -1.7))])
    return ([((31, -1.6), (28.4, 1.4)), ((28.4, 1.4), (26.2, 5.4)), ((33, -1.4), (34.6, 1.4)), ((27.0, 6.4), (26.4, 11.4))],
            [((26.0, 1.2), (29.0, -1.2)), ((29.5, -1.6), (32, -1.8))])


def hair_cap(cv, view, P, bias=0, outline=True):
    top = head_top(P)
    st, li = cap_strands(view)
    return hair_fill(cv, T(cap_pts(view), top), [(T([a], top)[0], T([b], top)[0]) for a, b in st],
                     [(T([a], top)[0], T([b], top)[0]) for a, b in li], bias=bias, outline=outline)


@layer("hair", "short", "hair")
def hair_short(cv, view, P):
    hair_cap(cv, view, P)


@layer("hair", "buzz", "hair")
def hair_buzz(cv, view, P):
    """Un crâne rasé : une ombre de cheveux, collée au crâne, sans contour."""
    top = head_top(P)
    cap = m_poly(T(cap_pts(view), top))
    skull = m_ell(32 if view != "E" else 31.2, top + 7.0, 8.7, 8.4)
    m = cap & skull & (PY < top + (11.5 if view == "N" else 4.2))
    cv.put(m, 3, False)
    cv.put(m & ~nb(m, 0, -1), 2, False)


@layer("hair", "long", "hair")
def hair_long(cv, view, P):
    top = head_top(P)
    if view == "S":
        for pts in ([(24.4, 6.0), (24.0, 14), (23.4, 22), (26.4, 22.6), (26.2, 12)], mir([(24.4, 6.0), (24.0, 14), (23.4, 22), (26.4, 22.6), (26.2, 12)])):
            poly(cv, T(pts, top), bias=-1)
    elif view == "E":
        poly(cv, T([(25.0, 4.0), (23.4, 12), (23.4, 22.5), (28.4, 23), (28.6, 10)], top), bias=-1)
    else:
        poly(cv, T([(23.8, 5.0), (23.2, 14), (23.6, 23), (27, 22), (30, 24), (32, 22), (34, 24), (37, 22), (40.4, 23), (40.8, 14), (40.2, 5)], top), bias=-1)
    hair_cap(cv, view, P)


@layer("hair", "ponytail", "hair")
def hair_ponytail(cv, view, P):
    top = head_top(P)
    if view == "E":
        poly(cv, T([(25.0, 2.0), (21.0, 3.5), (18.0, 8), (17.4, 14), (19.4, 13.2), (21.6, 9.0), (24.4, 7.0)], top), bias=-1)
    elif view == "N":
        poly(cv, T([(29.6, 1.0), (34.4, 1.0), (35.4, 9), (34.6, 20), (32, 22), (29.4, 20), (28.6, 9)], top), bias=-1)
    hair_cap(cv, view, P)
    if view == "N":
        rbox(cv, 30, int(top) + 2, 33, int(top) + 3, 0.0, flat=5, outline=False)
    elif view == "E":
        cv.px(24, int(top) + 3, 5)


@layer("hair", "bun", "hair")
def hair_bun(cv, view, P):
    top = head_top(P)
    bx = 29.5 if view == "E" else 32.0
    hair_cap(cv, view, P)
    poly(cv, T([(bx - 3.4, -2.6), (bx - 2.4, -5.4), (bx, -6.6), (bx + 2.4, -5.4), (bx + 3.4, -2.6), (bx + 1.8, -1.6), (bx - 1.8, -1.6)], top))


@layer("hair", "mohawk", "hair")
def hair_mohawk(cv, view, P):
    top = head_top(P)
    hair_buzz(cv, view, P)
    if view == "E":
        pts = [(26.0, 4.0), (24.0, -2.0), (27.0, -1.0), (28.5, -7.0), (31.0, -2.0), (33.0, -8.0), (35.0, -2.0), (37.0, -5.0), (37.4, 1.0)]
    else:
        pts = [(29.4, 2.0), (28.6, -3.0), (30.2, -2.0), (30.8, -8.0), (32, -3.0), (33.2, -8.0), (33.8, -2.0), (35.4, -3.0), (34.6, 2.0)]
    poly(cv, T(pts, top))


@layer("hair", "afro", "hair")
def hair_afro(cv, view, P):
    top = head_top(P)
    cx = 31.0 if view == "E" else 32.0
    big = m_ell(cx - (1.2 if view == "E" else 0), top + 4.0, 12.0, 11.0)
    if view == "S":
        big = big & ~(m_ell(32, top + 9.5, 6.4, 6.4) & (PY > top + 3.0))
    elif view == "E":
        big = big & ~(m_ell(34.5, top + 9.5, 5.6, 6.4) & (PY > top + 3.0) & (PX > 29))
    fill(cv, big, outline=True)
    for dx, dv in ((-6, -4), (-2, -6), (3, -5), (7, -3), (-8, 2), (8, 3)):
        cv.px(cx + dx, top + dv + 5, 5)
        cv.px(cx + dx + 1, top + dv + 5, 5)


@layer("hair", "pigtails", "hair")
def hair_pigtails(cv, view, P):
    top = head_top(P)
    if view == "E":
        poly(cv, T([(25.0, 4.0), (22.0, 6.0), (21.0, 12.0), (22.6, 20.0), (25.4, 19.0), (25.6, 11.0)], top), bias=-1)
    else:
        for pts in ([(24.6, 4.0), (21.4, 6.0), (20.6, 12.0), (21.8, 19.0), (24.8, 20.0), (25.2, 12.0)],
                    mir([(24.6, 4.0), (21.4, 6.0), (20.6, 12.0), (21.8, 19.0), (24.8, 20.0), (25.2, 12.0)])):
            poly(cv, T(pts, top), bias=-1)
    hair_cap(cv, view, P)
    if view != "E":
        for x in (23, 40):
            cv.px(x, int(top) + 5, 5)
            cv.px(x, int(top) + 6, 5)


@layer("hair", "pompadour", "hair")
def hair_pompadour(cv, view, P):
    top = head_top(P)
    hair_cap(cv, view, P)
    if view == "E":
        poly(cv, T([(28.0, 2.0), (30.0, -4.0), (35.0, -6.6), (40.4, -3.4), (41.0, 0.4), (37.0, -0.6), (33.0, 1.0)], top))
    else:
        poly(cv, T([(25.6, 1.0), (26.6, -4.0), (30.0, -6.6), (34.0, -6.6), (37.4, -4.0), (38.4, 1.0), (35.0, -1.6), (29.0, -1.6)], top))


@layer("hair", "dreads", "hair")
def hair_dreads(cv, view, P):
    top = head_top(P)
    if view == "S":
        for x, ln in ((23.2, 18), (25.4, 20), (38.6, 20), (40.8, 18)):
            limb(cv, [(x, top + 3), (x + (0.4 if x < 32 else -0.4), top + ln)], (2.8, 2.2), bias=-1)
    elif view == "E":
        for k, x in enumerate((24.6, 26.8, 29.0)):
            limb(cv, [(x, top + 5), (x - 0.4, top + 15 + (k % 2) * 3)], (2.8, 2.2), bias=-1)
    else:
        for k, x in enumerate((24.6, 27.4, 30.2, 33.8, 36.6, 39.4)):
            limb(cv, [(x, top + 5), (x, top + 17 + (k % 2) * 3)], (2.8, 2.2), bias=-1)
    hair_cap(cv, view, P)


@layer("hair", "bob", "hair")
def hair_bob(cv, view, P):
    top = head_top(P)
    if view == "S":
        for pts in ([(24.6, 4.0), (23.6, 10), (23.8, 17), (27.0, 17.4), (26.4, 9)], mir([(24.6, 4.0), (23.6, 10), (23.8, 17), (27.0, 17.4), (26.4, 9)])):
            poly(cv, T(pts, top), bias=-1)
    elif view == "E":
        poly(cv, T([(25.4, 4.0), (23.4, 10), (23.6, 17.4), (28.6, 17.6), (28.6, 9)], top), bias=-1)
    else:
        poly(cv, T([(23.8, 5.0), (23.4, 12), (23.8, 18), (27, 17), (32, 18.4), (37, 17), (40.2, 18), (40.6, 12), (40.2, 5)], top), bias=-1)
    hair_cap(cv, view, P)


@layer("hair", "curly", "hair")
def hair_curly(cv, view, P):
    top = head_top(P)
    hair_cap(cv, view, P)
    cx = 31.0 if view == "E" else 32.0
    for a in np.linspace(np.radians(190), np.radians(350), 7):
        bx = cx + 9.4 * np.cos(a)
        by = top + 4.2 + 8.0 * np.sin(a)
        ell(cv, bx, by, 2.4, 2.4)
    ell(cv, cx - (1.0 if view == "E" else 0), top - 3.2, 3.0, 2.6)


# ------------------------------------------------------------------ barbes
def beard_mask_s(top, ext=0.8, drop=0.0):
    """Le bas du visage vu de face : la barbe commence aux joues et passe sous le nez."""
    pts = [(25.2, 8.0), (24.6, 12.6), (26.6, 15.4), (29.4, 17.6 + drop), (32.0, 18.6 + drop), (34.6, 17.6 + drop), (37.4, 15.4),
           (39.4, 12.6), (38.8, 8.0), (37.0, 10.4), (35.2, 12.0), (33.4, 11.6), (32.0, 12.4), (30.6, 11.6), (28.8, 12.0), (27.0, 10.4)]
    return T(pts, top)


def beard_body(cv, view, P, drop=0.0):
    top = head_top(P)
    if view == "S":
        hair_fill(cv, beard_mask_s(top, drop=drop), strands=[((29, top + 14), (28, top + 17)), ((35, top + 14), (36, top + 17))])
    elif view == "E":
        pts = [(25.6, 8.0), (26.0, 14.0), (29.0, 17.4 + drop), (33.4, 18.2 + drop), (37.4, 16.2 + drop), (39.2, 13.0), (38.4, 11.0),
               (36.6, 11.6), (34.6, 11.0), (32.0, 9.8), (29.0, 9.0)]
        hair_fill(cv, T(pts, top), strands=[((30, top + 12), (31, top + 16)), ((34, top + 13), (35, top + 16))])


@layer("beard", "stubble", "hair")
def beard_stubble(cv, view, P):
    top = head_top(P)
    m = m_poly(beard_mask_s(top)) if view == "S" else (m_poly(T([(25.6, 8.0), (26.0, 14.0), (29.0, 16.4), (33.4, 17.2), (37.4, 15.2), (38.6, 12.0), (36.6, 11.6),
                                                                  (34.6, 11.0), (32.0, 9.8), (29.0, 9.0)], top)) if view == "E" else None)
    if m is None:
        return
    # des poils épars : un pixel sur trois, en quinconce, plus serrés vers le menton
    jaw = m & (PY > top + 10.5) & (PX > (28.5 if view == "E" else 0))
    ys, xs = np.arange(72)[:, None], np.arange(64)[None, :]
    sparse = (xs % 2 == 0) & (ys % 2 == 0)                           # un pixel sur quatre sur les joues
    chin = ((xs + ys) % 2 == 0) & (PY > top + 13.0)                   # un pixel sur deux au menton
    cv.put(jaw & (sparse | chin), 3, False)
    cv.put(jaw & ((xs + ys) % 2 == 0) & (PY > top + 14.6), 2, False)


@layer("beard", "goatee", "hair")
def beard_goatee(cv, view, P):
    top = head_top(P)
    if view == "S":
        hair_fill(cv, T([(29.6, 12.0), (34.4, 12.0), (34.8, 16.0), (33.0, 20.0), (32, 20.8), (31.0, 20.0), (29.2, 16.0)], top))
    elif view == "E":
        hair_fill(cv, T([(34.6, 11.6), (38.4, 12.0), (38.2, 16.0), (36.6, 19.6), (35.2, 19.0), (34.2, 15.0)], top))


@layer("beard", "full", "hair")
def beard_full(cv, view, P):
    beard_body(cv, view, P, drop=1.0)


@layer("beard", "long", "hair")
def beard_long(cv, view, P):
    top = head_top(P)
    if view == "S":
        poly(cv, T([(26.4, 14.0), (37.6, 14.0), (36.6, 20.0), (34.6, 26.0), (32, 29.0), (29.4, 26.0), (27.4, 20.0)], top))
    elif view == "E":
        poly(cv, T([(30.0, 14.0), (38.6, 13.0), (38.0, 20.0), (35.8, 26.0), (33.0, 28.0), (31.0, 22.0)], top))
    beard_body(cv, view, P, drop=1.4)


@layer("beard", "braid", "hair")
def beard_braid(cv, view, P):
    top = head_top(P)
    beard_body(cv, view, P, drop=0.4)
    x = 32.0 if view == "S" else 36.4
    if view in ("S", "E"):
        for i in range(5):
            ell(cv, x, top + 20.0 + i * 2.2, 2.4 - i * 0.2, 1.5, bias=-1 if i % 2 else 0)


@layer("beard", "twin", "hair")
def beard_twin(cv, view, P):
    top = head_top(P)
    beard_body(cv, view, P, drop=0.3)
    xs = (29.6, 34.4) if view == "S" else (34.4, 37.2)
    if view in ("S", "E"):
        for x in xs:
            for i in range(4):
                ell(cv, x, top + 20.0 + i * 2.2, 1.8 - i * 0.12, 1.4, bias=-1 if i % 2 else 0)


@layer("beard", "forked", "hair")
def beard_forked(cv, view, P):
    top = head_top(P)
    beard_body(cv, view, P, drop=0.8)
    if view == "S":
        poly(cv, T([(26.4, 16.0), (31.8, 17.0), (30.0, 24.0), (26.0, 27.0)], top))
        poly(cv, T([(37.6, 16.0), (32.2, 17.0), (34.0, 24.0), (38.0, 27.0)], top))
    elif view == "E":
        poly(cv, T([(31.0, 16.0), (38.0, 15.0), (37.4, 24.0), (33.0, 27.0)], top))


@layer("beard", "chinstrap", "hair")
def beard_chinstrap(cv, view, P):
    top = head_top(P)
    if view == "S":
        ring = m_poly(T([(24.8, 8.0), (24.4, 12.6), (26.6, 15.8), (29.4, 18.0), (32, 18.8), (34.6, 18.0), (37.4, 15.8), (39.6, 12.6), (39.2, 8.0),
                         (37.6, 8.0), (37.4, 12.6), (35.4, 15.2), (32, 16.2), (28.6, 15.2), (26.6, 12.6), (26.4, 8.0)], top))
        fill(cv, ring)
    elif view == "E":
        ring = m_poly(T([(25.6, 8.0), (26.0, 14.0), (29.0, 17.6), (33.4, 18.4), (37.4, 16.4), (39.0, 12.4), (37.0, 12.0), (35.4, 14.6), (33.4, 15.6),
                         (29.4, 14.6), (28.0, 8.0)], top))
        fill(cv, ring)


@layer("beard", "chops", "hair")
def beard_chops(cv, view, P):
    top = head_top(P)
    if view == "S":
        for pts in ([(24.6, 6.0), (26.6, 6.0), (27.4, 12.0), (26.0, 14.6), (24.4, 12.0)], mir([(24.6, 6.0), (26.6, 6.0), (27.4, 12.0), (26.0, 14.6), (24.4, 12.0)])):
            poly(cv, T(pts, top))
    elif view == "E":
        poly(cv, T([(31.0, 5.0), (33.4, 5.4), (34.2, 12.0), (32.0, 14.4), (30.6, 12.0)], top))


@layer("beard", "bushy", "hair")
def beard_bushy(cv, view, P):
    top = head_top(P)
    if view == "S":
        hair_fill(cv, T([(24.0, 8.0), (22.6, 13.0), (24.0, 18.0), (28.0, 22.4), (32, 23.4), (36.0, 22.4), (40.0, 18.0), (41.4, 13.0), (40.0, 8.0),
                         (37.4, 10.4), (35.0, 11.6), (33.4, 11.2), (32, 12.0), (30.6, 11.2), (29.0, 11.6), (26.6, 10.4)], top),
                  strands=[((28, top + 14), (27, top + 19)), ((36, top + 14), (37, top + 19)), ((32, top + 16), (32, top + 21))])
    elif view == "E":
        hair_fill(cv, T([(25.0, 8.0), (24.6, 14.0), (27.0, 19.0), (31.0, 22.6), (36.0, 22.0), (40.0, 18.0), (40.6, 13.0), (38.6, 10.6), (36.0, 11.2),
                         (33.6, 10.4), (30.0, 9.0)], top))


# ------------------------------------------------------------------ moustaches
@layer("mustache", "thin", "hair")
def must_thin(cv, view, P):
    y = int(head_top(P)) + 12
    if view == "S":
        cv.bmp(29, y, ["444444"])
    elif view == "E":
        cv.bmp(35, y, ["444"])


@layer("mustache", "handlebar", "hair")
def must_handlebar(cv, view, P):
    y = int(head_top(P)) + 12
    if view == "S":
        cv.bmp(29, y, ["444444"])
        for x, yy, t in ((28, y, 4), (27, y - 1, 4), (27, y - 2, 5), (35, y, 4), (36, y - 1, 4), (36, y - 2, 5)):
            cv.px(x, yy, t)
    elif view == "E":
        cv.bmp(35, y, ["4444"])
        cv.px(38, y - 1, 5)


@layer("mustache", "walrus", "hair")
def must_walrus(cv, view, P):
    y = int(head_top(P)) + 11
    if view == "S":
        cv.bmp(27, y, ["44444444", "33333333", ".3....3."])
    elif view == "E":
        cv.bmp(34, y, ["5444", "3333"])


@layer("mustache", "chevron", "hair")
def must_chevron(cv, view, P):
    y = int(head_top(P)) + 11
    if view == "S":
        cv.bmp(29, y, ["444444", "544445", "33..33"])
    elif view == "E":
        cv.bmp(35, y, ["444", "443", "3.."])


# ------------------------------------------------------------------ chapeaux (silhouettes de pirate)
def _edge(cv, pts, idx=5, dv=0.0):
    for (x0, y0), (x1, y1) in zip(pts[:-1], pts[1:]):
        line(cv, (x0, y0 + dv), (x1, y1 + dv), idx)


def tricorn_parts(view, top):
    """Le tricorne : calotte basse + bord relevé en trois pointes (devant, et de chaque côté)."""
    if view == "E":
        crown = [(26.0, -0.5), (27.0, -5.0), (31.0, -7.0), (35.0, -6.0), (37.0, -2.0), (36.0, 1.0), (28.0, 1.0)]
        brim = [(18.0, -4.0), (21.0, 0.6), (27.0, 3.0), (34.0, 3.2), (40.0, 1.6), (44.0, -2.4), (41.0, -1.8), (36.0, -3.6), (26.0, -3.6), (21.0, -2.6)]
        flap = [(36.0, -4.0), (44.0, -2.4), (40.0, 1.6), (36.0, 2.4)]
        return crown, [brim, flap]
    front = 4.4 if view == "S" else 3.0
    crown = [(25.0, -0.6), (26.0, -5.4), (29.6, -7.6), (34.4, -7.6), (38.0, -5.4), (39.0, -0.6), (32.0, 1.0)]
    brim = [(17.4, -5.6), (19.4, 1.0), (24.0, 2.6), (28.4, 3.6), (32.0, front), (35.6, 3.6), (40.0, 2.6), (44.6, 1.0), (46.6, -5.6), (41.0, -3.4),
            (23.0, -3.4)]
    wing_l = [(17.4, -5.6), (19.4, 1.0), (24.6, -1.0), (24.0, -4.4)]
    wing_r = mir(wing_l)
    flap = [(26.0, -4.6), (38.0, -4.6), (35.0, 3.0), (32.0, front), (29.0, 3.0)]
    return crown, [brim, wing_l, wing_r] + ([flap] if view == "S" else [])


@layer("hat", "tricorn", "hat")
def hat_tricorn(cv, view, P):
    top = head_top(P)
    crown, parts = tricorn_parts(view, top)
    poly(cv, T(crown, top))
    for i, p in enumerate(parts):
        poly(cv, T(p, top), bias=1 if i > 0 else 0)


@layer("hat", "tricorn", "trim")
def hat_tricorn_trim(cv, view, P):
    top = head_top(P)
    if view == "E":
        _edge(cv, T([(18.0, -4.0), (21.0, 0.6), (27.0, 3.0), (34.0, 3.2), (40.0, 1.6), (44.0, -2.4)], top))
        return
    front = 4.4 if view == "S" else 3.0
    _edge(cv, T([(17.4, -5.6), (19.4, 1.0), (24.0, 2.6), (28.4, 3.6), (32.0, front), (35.6, 3.6), (40.0, 2.6), (44.6, 1.0), (46.6, -5.6)], top))


@layer("hat", "bicorn", "hat")
def hat_bicorn(cv, view, P):
    """Le bicorne de capitaine : un grand croissant porté en travers (large de face, mince de profil)."""
    top = head_top(P)
    if view == "E":
        poly(cv, T([(26.0, -9.0), (36.0, -9.6), (40.0, -2.0), (37.0, 2.4), (27.0, 2.4), (23.6, -3.0)], top))
        return
    poly(cv, T([(16.4, 2.0), (18.6, -4.6), (24.0, -9.2), (32.0, -10.8), (40.0, -9.2), (45.4, -4.6), (47.6, 2.0), (43.4, -1.0), (38.0, -2.4),
    top += 6.0   # (13/11 : hors profil, le bicorne flottait 6 pixels au-dessus de la tête ; les images du jeu ont été recalées de même)
                (32.0, -2.8), (26.0, -2.4), (20.6, -1.0)], top))


@layer("hat", "bicorn", "trim")
def hat_bicorn_trim(cv, view, P):
    top = head_top(P)
    if view == "E":
        _edge(cv, T([(26.0, -9.0), (36.0, -9.6), (40.0, -2.0)], top))
        limb(cv, [(33, top - 8), (40, top - 14)], (2.6, 1.6), flat=5, outline=False)
    top += 6.0   # (13/11 : hors profil, le bicorne flottait 6 pixels au-dessus de la tête ; les images du jeu ont été recalées de même)
        return
    _edge(cv, T([(16.4, 2.0), (18.6, -4.6), (24.0, -9.2), (32.0, -10.8), (40.0, -9.2), (45.4, -4.6), (47.6, 2.0)], top), dv=1.0)
    limb(cv, [(38, top - 8), (45, top - 15)], (2.6, 1.6), flat=5, outline=False)           # la plume
    cv.bmp(36, int(top) - 6, ["54"])                                                            # la cocarde


@layer("hat", "bandana", "hat")
def hat_bandana(cv, view, P):
    top = head_top(P)
    cap = m_poly(T(cap_pts(view), top))
    skull = m_ell(32 if view != "E" else 31.2, top + 6.6, 9.4, 9.0)
    body = (cap | skull) & (PY < top + 5.4 + (np.abs(PX - 32) / 9.0) ** 2 * 2.0)
    fill(cv, body, outline=True)
    if view == "S":
        for pts in ([(40.0, 3.0), (43.4, 5.0), (42.6, 9.0), (40.0, 6.6)], mir([(40.0, 3.0), (43.4, 5.0), (42.6, 9.0), (40.0, 6.6)])):
            poly(cv, T(pts, top), bias=-1)
    elif view == "E":
        poly(cv, T([(24.4, 2.0), (19.0, 3.0), (17.0, 8.0), (21.0, 6.4)], top), bias=-1)
        poly(cv, T([(24.4, 2.6), (20.0, 6.0), (20.4, 11.0), (24.0, 7.0)], top), bias=-1)
    else:
        ell(cv, 32, top + 3.0, 2.8, 2.4)
        poly(cv, T([(31, 4), (28.4, 8), (28.0, 12), (31.4, 7)], top), bias=-1)
        poly(cv, T([(33, 4), (35.6, 8), (36.0, 12), (32.6, 7)], top), bias=-1)


@layer("hat", "straw", "hat")
def hat_straw(cv, view, P):
    top = head_top(P)
    poly(cv, T([(26.0, 0.4), (27.0, -5.2), (32, -6.6), (37.0, -5.2), (38.0, 0.4)], top))
    poly(cv, T([(15.0, -1.0), (22.0, -3.0), (42.0, -3.0), (49.0, -1.0), (46.0, 2.4), (32, 3.4), (18.0, 2.4)], top), bias=1)


@layer("hat", "straw", "trim")
def hat_straw_trim(cv, view, P):
    top = head_top(P)
    for x in range(26, 38):
        cv.px(x, int(top) - 2, 5)
        cv.px(x, int(top) - 3, 4)


@layer("hat", "cap", "hat")
def hat_cap(cv, view, P):
    """Le bonnet : un dôme de tissu serré, avec un large revers."""
    top = head_top(P)
    cx = 31.0 if view == "E" else 32.0
    dome = m_ell(cx, top + 4.0, 10.4, 9.6) & (PY < top + 2.6)
    fill(cv, dome, outline=True)


@layer("hat", "cap", "trim")
def hat_cap_trim(cv, view, P):
    top = head_top(P)
    cx = 31.0 if view == "E" else 32.0
    band = m_ell(cx, top + 4.0, 10.8, 10.0) & (PY >= top + 2.6) & (PY < top + 6.2)
    fill(cv, band, outline=True)


@layer("hat", "plume", "hat")
def hat_plume(cv, view, P):
    """Le chapeau à plume : une haute calotte, un bord plus étroit relevé d'un côté."""
    top = head_top(P)
    poly(cv, T([(24.8, 0.6), (25.2, -7.0), (29.0, -10.6), (35.0, -10.6), (38.8, -7.0), (39.2, 0.6)], top))
    if view == "E":
        poly(cv, T([(20.0, -0.4), (26.0, -2.6), (38.0, -2.6), (45.0, -0.6), (42.0, 2.6), (30.0, 3.4), (22.0, 2.4)], top), bias=1)
    else:
        poly(cv, T([(19.0, -0.4), (25.0, -2.6), (39.0, -2.6), (46.0, -0.6), (44.0, 2.6), (32.0, 3.8), (21.0, 2.6)], top), bias=1)
        poly(cv, T([(18.4, -5.0), (19.0, -0.4), (25.0, -2.6), (23.4, -5.6)], top), bias=2)


@layer("hat", "plume", "trim")
def hat_plume_trim(cv, view, P):
    top = head_top(P)
    for x in range(25, 40):
        cv.px(x, int(top) - 2, 5)
    # la plume : elle part du ruban, monte, puis retombe en arrière en s'effilant ; une nervure sombre la parcourt
    feather = [(33.5, -2.0), (34.6, -6.6), (37.6, -10.6), (42.0, -12.4), (46.0, -11.2), (48.4, -7.6), (49.0, -3.6), (47.6, -6.4),
               (44.6, -8.4), (41.0, -8.2), (38.0, -5.4), (36.2, -1.6)]
    m = m_poly(T(feather, top))
    fill(cv, m, bias=1, outline=True)
    for a, b in (((35.4, -3.0), (38.0, -8.0)), ((38.0, -8.0), (43.0, -10.4)), ((43.0, -10.4), (47.4, -8.4))):
        line(cv, (a[0], top + a[1]), (b[0], top + b[1]), 3, m)


@layer("hat", "turban", "hat")
def hat_turban(cv, view, P):
    top = head_top(P)
    cx = 31.0 if view == "E" else 32.0
    poly(cv, T([(cx - 9.6, 2.4), (cx - 9.0, -3.6), (cx - 5.0, -6.4), (cx, -7.4), (cx + 5.0, -6.4), (cx + 9.0, -3.6), (cx + 9.6, 2.4)], top))
    poly(cv, T([(cx - 8.4, -3.0), (cx - 4.0, -8.0), (cx + 2.0, -11.0), (cx + 6.0, -8.0), (cx + 8.4, -3.0), (cx, -4.6)], top), bias=1)
    line(cv, (cx - 8, top - 1), (cx + 8, top - 4), 3)
    line(cv, (cx - 8, top + 1), (cx + 8, top - 2), 3)


@layer("hat", "turban", "trim")
def hat_turban_trim(cv, view, P):
    top = head_top(P)
    if view == "S":
        cv.bmp(31, int(top) - 2, ["55", "54"])
    elif view == "E":
        cv.bmp(36, int(top) - 1, ["55", "54"])


@layer("hat", "headband", "hat")
def hat_headband(cv, view, P):
    top = head_top(P)
    cx = 31.0 if view == "E" else 32.0
    band = m_ell(cx, top + 6.6, 9.6, 9.1) & (PY >= top + 1.4) & (PY < top + 4.2)
    fill(cv, band, outline=True)
    if view == "S":
        poly(cv, T([(40.0, 1.8), (43.6, 3.6), (43.0, 9.0), (40.4, 5.4)], top), bias=-1)
    elif view == "E":
        poly(cv, T([(24.6, 1.8), (19.0, 3.6), (19.4, 9.0), (24.0, 4.4)], top), bias=-1)
    else:
        poly(cv, T([(31, 3), (28.4, 7), (28.4, 11), (31.4, 6)], top), bias=-1)
        poly(cv, T([(33, 3), (35.6, 7), (35.6, 11), (32.6, 6)], top), bias=-1)
