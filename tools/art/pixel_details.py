"""Les détails des vêtements, tracés APRÈS la forme de chaque couche et seulement sur ses pixels : plis aux coudes et aux genoux,
plis de taille, coutures, revers, poches, semelles, coutures de ceinture. Ce sont des traits d'un pixel (ton plus sombre ou
plus clair) : ils donnent l'impression d'un vêtement dessiné à la main, pas d'un aplat. pixel_build.draw_layer les applique
(sous la même rotation 3/4 que la couche)."""
import numpy as np

from pixel_body import arms, legs, lerp, GROUND
from pixel_pirate import line

DETAILS = []   # (prédicat sur l'identifiant de couche, fonction (cv, view, P))


def detail(pred):
    def deco(fn):
        DETAILS.append((pred, fn))
        return fn
    return deco


def apply(lid, cv, view, P):
    """Ajoute à la couche les détails qui la concernent."""
    for pred, fn in DETAILS:
        if pred(lid):
            fn(cv, view, P, lid)


def _m(cv):
    return cv.t >= 0


def _strokes(cv, m, segs, tone):
    for a, b in segs:
        line(cv, a, b, tone, m)


def _mirror_segs(segs):
    return [((64 - a[0], a[1]), (64 - b[0], b[1])) for a, b in segs]


# ------------------------------------------------------------------ manches
def _sleeve_details(cv, view, P, cuff_at, elbow=True, tone=3):
    m = _m(cv)
    for a in arms(view, P):
        if view == "E" and a["far"]:
            continue
        s, e, h = a["pts"]
        if elbow:
            line(cv, (e[0] - 1.6, e[1] - 0.2), (e[0] + 0.8, e[1] + 0.8), tone, m)
        if cuff_at is not None:
            p = lerp(e, h, cuff_at)
            line(cv, (p[0] - 2.2, p[1]), (p[0] + 2.0, p[1]), tone, m)


@detail(lambda lid: lid.startswith("shirt-pirate.cloth"))
def d_pirate_sleeves(cv, view, P, lid):
    _sleeve_details(cv, view, P, 0.62)           # la manche bouffante est resserrée au poignet
    _torso_wrinkles(cv, view, P)


@detail(lambda lid: lid.startswith("shirt-") and lid.endswith(".cloth") and "pirate" not in lid)
def d_shirt(cv, view, P, lid):
    _sleeve_details(cv, view, P, None)
    _torso_wrinkles(cv, view, P)


@detail(lambda lid: lid.startswith("coat-") and lid.endswith(".cloth") and "vest" not in lid)
def d_coat_sleeves(cv, view, P, lid):
    _sleeve_details(cv, view, P, 0.74)
    _torso_wrinkles(cv, view, P, top=40, bottom=44)


# ------------------------------------------------------------------ torse
def _torso_wrinkles(cv, view, P, tone=3, top=40.5, bottom=44.0):
    m = _m(cv)
    dy = P.dy
    if view == "S":
        segs = [((27.4, top + dy), (28.8, bottom + dy)), ((36.6, top + dy), (35.2, bottom + dy))]
    elif view == "E":
        segs = [((29.6, top + dy), (31.0, bottom + dy))]
    else:   # de dos : une couture au milieu du dos et deux plis
        segs = [((32.0, 33.6 + dy), (32.0, 42.0 + dy)), ((27.4, top + dy), (28.8, bottom + dy)), ((36.6, top + dy), (35.2, bottom + dy))]
    _strokes(cv, m, segs, tone)


@detail(lambda lid: lid == "coat-vest.cloth")
def d_vest(cv, view, P, lid):
    m = _m(cv)
    dy = P.dy
    if view in ("S", "N"):                         # les coutures d'emmanchure
        _strokes(cv, m, [((27.6, 36 + dy), (27.8, 45 + dy)), ((36.4, 36 + dy), (36.2, 45 + dy))], 3)
    if view == "N":
        _strokes(cv, m, [((32, 33.6 + dy), (32, 45 + dy))], 3)


@detail(lambda lid: lid in ("coat-jacket.cloth", "coat-captain.cloth"))
def d_coat_body(cv, view, P, lid):
    m = _m(cv)
    dy = P.dy
    if view == "S":
        # revers de col, poches à rabat
        _strokes(cv, m, [((29.4, 31.6 + dy), (32.0, 36.4 + dy)), ((34.6, 31.6 + dy), (32.0, 36.4 + dy))], 3)
        _strokes(cv, m, [((28.4, 32.2 + dy), (30.8, 36.6 + dy))], 5)
        pocket = [((27.0, 49.0 + dy), (30.4, 49.0 + dy)), ((27.0, 49.0 + dy), (27.0, 51.4 + dy)), ((30.4, 49.0 + dy), (30.4, 51.4 + dy))]
        _strokes(cv, m, pocket + _mirror_segs(pocket), 3)
    elif view == "E":
        _strokes(cv, m, [((29.4, 49.4 + dy), (33.6, 49.4 + dy)), ((33.6, 49.4 + dy), (33.6, 51.6 + dy))], 3)
    else:
        _strokes(cv, m, [((32, 46 + dy), (32, 54 if "captain" in lid else 55))], 2)      # la fente du dos
    if "captain" in lid:
        y = 54
        for x in range(23, 41, 2):                  # le point de couture de l'ourlet
            if view == "S":
                line(cv, (x, y), (x, y), 3, m)


# ------------------------------------------------------------------ pantalon
@detail(lambda lid: lid.startswith("pants-") and lid.endswith(".cloth"))
def d_pants(cv, view, P, lid):
    m = _m(cv)
    for L in legs(view, P):
        hip, knee, ank = L["pts"]
        if view == "E" and L["far"]:
            continue
        if not any(m[int(knee[1]), max(0, int(knee[0]) - 1):int(knee[0]) + 2]):
            continue
        line(cv, (knee[0] - 1.8, knee[1] + 0.1), (knee[0] + 1.4, knee[1] + 0.9), 3, m)       # le pli du genou
        line(cv, (knee[0] - 1.4, knee[1] - 1.2), (knee[0] - 0.6, knee[1] - 1.2), 5, m)       # un reflet au-dessus
        line(cv, (hip[0] - 0.6, hip[1] + 1.2), (hip[0] + 0.4, hip[1] + 3.6), 3, m)           # un pli à l'aine


# ------------------------------------------------------------------ bottes
@detail(lambda lid: lid.startswith("boots-") and lid.endswith(".boot"))
def d_boots(cv, view, P, lid):
    m = _m(cv)
    high = "high" in lid
    for L in legs(view, P):
        ax, ay = L["pts"][-1]
        bot = GROUND + 1 - L["lift"]
        if view == "E" and L["far"]:
            line(cv, (ax - 3.0, bot - 0.5), (ax + 5.4, bot - 0.5), 1, m)
            continue
        line(cv, (ax - 3.6, bot - 0.5), (ax + (5.4 if view == "E" else 3.4), bot - 0.5), 1, m)       # la semelle
        if view != "N":
            tip = ax + (4.0 if view == "E" else 2.0)
            line(cv, (tip - 1.0, bot - 3.0), (tip, bot - 3.0), 5, m)                                 # un reflet sur le bout
        if high:
            top = ay - 4.6
            line(cv, (ax - 2.2, top + 3.0), (ax + 1.4, top + 3.6), 3, m)                             # des plis du cuir
            line(cv, (ax - 2.4, top + 5.2), (ax + 0.8, top + 5.7), 3, m)
            if view != "N":
                line(cv, (ax + 1.4, top + 1.2), (ax + 1.4, top + 2.2), 5, m)                         # la boucle de la sangle


# ------------------------------------------------------------------ ceintures
@detail(lambda lid: lid == "belt-belt.belt")
def d_belt(cv, view, P, lid):
    m = _m(cv)
    dy = P.dy
    if view == "S":
        for x in (34, 36):
            line(cv, (x, 44.5 + dy), (x, 44.5 + dy), 2, m)              # les trous de la ceinture
        line(cv, (27, 43.5 + dy), (29, 43.5 + dy), 5, m)
    elif view == "N":
        line(cv, (27, 43.5 + dy), (37, 43.5 + dy), 5, m)


@detail(lambda lid: lid == "belt-sash.belt")
def d_sash(cv, view, P, lid):
    m = _m(cv)
    dy = P.dy
    if view in ("S", "N"):
        _strokes(cv, m, [((27.0, 43.0 + dy), (29.2, 45.6 + dy)), ((33.6, 42.6 + dy), (36.2, 45.8 + dy)), ((30.0, 42.4 + dy), (31.0, 44.2 + dy))], 3)
        _strokes(cv, m, [((26.4, 42.4 + dy), (28.4, 42.4 + dy))], 5)
    else:
        _strokes(cv, m, [((29.0, 43.0 + dy), (31.0, 45.6 + dy))], 3)


@detail(lambda lid: lid == "belt-baldric.belt")
def d_baldric(cv, view, P, lid):
    m = _m(cv)
    dy = P.dy
    if view == "S":
        p0, p1 = (27.0, 32 + dy), (37.0, 45 + dy)
    elif view == "E":
        p0, p1 = (29.5, 32 + dy), (34.5, 45 + dy)
    else:
        p0, p1 = (37.0, 32 + dy), (27.0, 45 + dy)
    for i in range(1, 13, 3):                                          # les points de couture le long de la bandoulière
        t = i / 13.0
        line(cv, (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t), (p0[0] + (p1[0] - p0[0]) * t, p0[1] + (p1[1] - p0[1]) * t), 5, m)


# ------------------------------------------------------------------ mains
@detail(lambda lid: lid == "hands-bare.skin")
def d_hands(cv, view, P, lid):
    m = _m(cv)
    for a in arms(view, P):
        if view == "N" and (P.carry or P.helm):
            continue
        x, y = a["pts"][-1]
        line(cv, (x - 0.2, y + 1.0), (x - 0.2, y + 2.2), 3, m)         # l'espace entre le pouce et les doigts
