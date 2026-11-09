"""La tête du pirate à l'échelle EXACTE de la référence (voir pixel_body.py) : un visage de 8 pixels de large, des yeux d'UN pixel, un
bandana noir à tête de mort, des mèches fines de chaque côté, un bouc. Tout est dessiné directement dans le repère du corps
(colonne de la référence + 12, ligne + 16) : les couches sont `native=True` (pas de réduction, voir pixel_build).

Repères (vue de face) : chapeau y = 18..23 ; visage x = 28..35, y = 24..31 (sourcils y = 25, yeux y = 26 en x = 30 et 33, nez y = 28,
bouche y = 30) ; mèches de x = 26..27 et 36..37 ; cou x = 30..33, y = 32..34. Vue de profil (E, le pirate regarde à droite) :
crâne x = 27..36, œil en x = 34, nez en x = 37. L'ensemble descend de P.dy (marche) et de P.hdy (respiration)."""
from pixel_parts import layer
from pixel_pirate import m_poly, m_limb, line, nb, PX, PY, H, W
from pixel_body import box, paint


def hh(P):
    """Le décalage vertical de la tête."""
    return P.dy + P.hdy


def pts(cv, tone, coords, dy=0):
    for x, y in coords:
        cv.px(x, y + dy, tone)


# ------------------------------------------------------------------ crâne et cou
@layer("head", "round", "skin", native=True)
def head_skin(cv, view, P):
    h = hh(P)
    paint(cv, box(30, 32 + P.dy, 33, 34 + P.dy), 4, edge=3, top=3)                   # le cou (ombré sous le menton)
    cv.put(box(30, 33 + P.dy, 33, 33 + P.dy), 3, False)
    pts(cv, 4, [(30, 35), (31, 35), (32, 35), (31, 36), (32, 36)], P.dy)               # l'encolure ronde de la référence
    pts(cv, 3, [(33, 35)], P.dy)
    if view == "E":
        skull = box(29, 19 + h, 34, 19 + h) | box(28, 20 + h, 35, 20 + h) | box(27, 21 + h, 36, 30 + h) | box(29, 31 + h, 35, 31 + h)
    else:
        skull = box(29, 19 + h, 34, 19 + h) | box(28, 20 + h, 35, 20 + h) | box(27, 21 + h, 36, 30 + h) | box(28, 31 + h, 35, 31 + h)
    paint(cv, skull, 4, edge=3)
    if view == "S":
        pts(cv, 3, [(35, y) for y in range(25, 32)], h)                              # l'ombre du côté droit du visage
    if view == "E":
        pts(cv, 3, [(31, 26), (31, 27)], h)                                         # l'oreille
    else:
        pts(cv, 3, [(26, 26), (26, 27), (37, 26), (37, 27)], h)                     # les oreilles


# ------------------------------------------------------------------ yeux : UN pixel sombre
def _eyes(slot):
    # variante : (pixels de l'iris S, pixels de l'iris E, ton, pixels du blanc S, du blanc E)
    table = {
        "round": ([(30, 0), (33, 0)], [(34, 0)], 4, [], []),
        "narrow": ([(30, 0), (33, 0)], [(34, 0)], 3, [], []),
        "angry": ([(30, 0), (33, 0), (30, -1), (33, -1)], [(34, 0), (34, -1)], 3, [], []),
        "wide": ([(30, 0), (33, 0)], [(34, 0)], 4, [(29, 0), (34, 0)], [(33, 0), (35, 0)]),
        "sleepy": ([(29, 0), (30, 0), (33, 0), (34, 0)], [(33, 0), (34, 0)], 3, [], []),
    }
    for name, (iS, iE, tone, wS, wE) in table.items():
        @layer("eyes", name, slot, native=True)
        def draw(cv, view, P, iS=iS, iE=iE, tone=tone, wS=wS, wE=wE):
            y = 26 + hh(P)
            if view == "S":
                pts(cv, 5 if slot == "white" else tone, [(x, dy) for x, dy in (wS if slot == "white" else iS)], y)
            elif view == "E":
                pts(cv, 5 if slot == "white" else tone, [(x, dy) for x, dy in (wE if slot == "white" else iE)], y)


_eyes("white")
_eyes("iris")


# ------------------------------------------------------------------ sourcils
BROWS = {
    "normal": ([(29, 0), (30, 0), (33, 0), (34, 0)], [(33, 0), (34, 0)]),
    "thick": ([(29, 0), (30, 0), (33, 0), (34, 0), (29, -1), (30, -1), (33, -1), (34, -1)], [(33, 0), (34, 0), (33, -1), (34, -1)]),
    "angry": ([(29, -1), (30, 0), (33, 0), (34, -1)], [(33, 0), (34, -1)]),
    "raised": ([(29, 0), (30, -1), (33, -1), (34, 0)], [(33, -1), (34, 0)]),
}
for _name, (_s, _e) in BROWS.items():
    @layer("brows", _name, "hair", native=True)
    def _brow(cv, view, P, _s=_s, _e=_e):
        y = 25 + hh(P)
        if view == "S":
            pts(cv, 3, _s, y)
        elif view == "E":
            pts(cv, 3, _e, y)


# ------------------------------------------------------------------ nez : une ombre sous le nez (ligne 28), comme la référence
S_NOSE = {"small": [(31, 2, 3), (32, 2, 3)], "big": [(31, 1, 5), (32, 1, 4), (31, 2, 3), (32, 2, 3), (30, 2, 3), (33, 2, 3)],
          "pointy": [(31, 1, 5), (31, 2, 3), (32, 2, 3), (32, 3, 3)], "round": [(31, 1, 5), (32, 1, 5), (31, 2, 3), (32, 2, 3)],
          "flat": [(30, 2, 3), (31, 2, 3), (32, 2, 3), (33, 2, 3)]}
E_NOSE = {"small": [(37, 1, 4), (37, 2, 3)], "big": [(37, 0, 4), (37, 1, 4), (38, 2, 4), (37, 2, 3)],
          "pointy": [(37, 0, 4), (37, 1, 4), (38, 2, 4), (39, 2, 3)], "round": [(37, 1, 4), (38, 1, 4), (37, 2, 3), (38, 2, 3)],
          "flat": [(36, 2, 3), (37, 2, 3)]}
for _name in S_NOSE:
    @layer("nose", _name, "skin", native=True)
    def _nose(cv, view, P, _name=_name):
        y = 26 + hh(P)
        for x, dy, t in (S_NOSE[_name] if view == "S" else E_NOSE[_name] if view == "E" else []):
            cv.px(x, y + dy, t)


# ------------------------------------------------------------------ bouche
MOUTHS = {   # variante : (pixels S, pixels E, dents S, dents E) ; ligne 29 + décalage
    "smile": ([(30, 0), (31, 1), (32, 1), (33, 0)], [(35, 1), (36, 0)], [], []),
    "neutral": ([(31, 1), (32, 1)], [(35, 1)], [], []),
    "grin": ([(30, 0), (33, 0), (30, 1), (31, 1), (32, 1), (33, 1)], [(35, 1), (36, 0), (36, 1)], [(31, 0), (32, 0)], [(35, 0)]),
    "frown": ([(31, 1), (32, 1), (30, 2), (33, 2)], [(35, 1), (34, 2)], [], []),
    "open": ([(31, 1), (32, 1), (31, 2), (32, 2)], [(35, 1), (35, 2)], [(31, 1), (32, 1)], [(35, 1)]),
}
for _name, (_s, _e, _ts, _te) in MOUTHS.items():
    @layer("mouth", _name, "mouth", native=True)
    def _mouth(cv, view, P, _s=_s, _e=_e):
        y = 29 + hh(P)
        pts(cv, 3, _s if view == "S" else _e if view == "E" else [], y)
    if _ts:
        @layer("mouth", _name, "teeth", native=True)
        def _teeth(cv, view, P, _ts=_ts, _te=_te):
            y = 29 + hh(P)
            pts(cv, 5, _ts if view == "S" else _te if view == "E" else [], y)


@layer("mouth", "pipe", "mouth", native=True)
def mouth_pipe(cv, view, P):
    y = 29 + hh(P)
    pts(cv, 3, [(31, 1), (32, 1)] if view == "S" else [(35, 1)] if view == "E" else [], y)


@layer("mouth", "pipe", "pipe", native=True)
def pipe(cv, view, P):
    y = 29 + hh(P)
    if view == "S":
        pts(cv, 4, [(33, 1), (34, 1), (35, 1)], y)
        cv.put(box(35, 28 + hh(P), 36, 30 + hh(P)), 4, False)
        cv.px(36, 27 + hh(P), 5)
    elif view == "E":
        pts(cv, 4, [(36, 1), (37, 1), (38, 1)], y)
        cv.put(box(38, 28 + hh(P), 39, 30 + hh(P)), 4, False)
        cv.px(39, 27 + hh(P), 5)


# ------------------------------------------------------------------ signes particuliers
for _name, _side in (("patch_l", 0), ("patch_r", 1)):
    @layer("mark", _name, "patch", native=True)
    def _patch(cv, view, P, _side=_side):
        h = hh(P)
        if view == "S":
            x0 = 29 if _side == 0 else 32
            cv.put(box(x0, 25 + h, x0 + 2, 27 + h), 4, False)
            if _side == 0:
                line(cv, (x0 + 3, 25 + h), (36, 22 + h), 3)
                line(cv, (x0 - 1, 25 + h), (27, 23 + h), 3)
            else:
                line(cv, (x0 - 1, 25 + h), (27, 22 + h), 3)
                line(cv, (x0 + 3, 25 + h), (36, 23 + h), 3)
        elif view == "E":
            cv.put(box(33, 25 + h, 35, 27 + h), 4, False)
            line(cv, (33, 25 + h), (27, 23 + h), 3)
        elif view == "N":
            line(cv, (27, 23 + h), (36, 22 + h), 3)


@layer("mark", "scar", "scar", native=True)
def scar(cv, view, P):
    h = hh(P)
    if view == "S":
        pts(cv, 4, [(34, 25), (34, 26), (35, 27), (35, 28)], h)
        cv.px(33, 26 + h, 5)
    elif view == "E":
        pts(cv, 4, [(33, 25), (33, 26), (34, 27), (34, 28)], h)


@layer("mark", "monocle", "frame", native=True)
def monocle(cv, view, P):
    h = hh(P)
    ring = [(32, 25), (33, 25), (34, 25), (32, 26), (34, 26), (32, 27), (33, 27), (34, 27)] if view == "S" else \
           [(33, 25), (34, 25), (35, 25), (33, 26), (35, 26), (33, 27), (34, 27), (35, 27)]
    if view in ("S", "E"):
        pts(cv, 5, ring, h)
        pts(cv, 4, [(35 if view == "S" else 36, 28), (35 if view == "S" else 36, 29), (36 if view == "S" else 37, 30)], h)


@layer("mark", "earrings", "frame", native=True)
def earrings(cv, view, P):
    h = hh(P)
    if view in ("S", "N"):
        pts(cv, 5, [(26, 28), (37, 28)], h)
    elif view == "E":
        pts(cv, 5, [(31, 28)], h)


# ------------------------------------------------------------------ le bandana de la référence (noir, tête de mort blanche, nœud)
BANDANA_S = [(18, 29, 34), (19, 28, 35), (20, 28, 35), (21, 27, 36), (22, 27, 36), (23, 27, 36)]


@layer("hat", "bandana", "hat", native=True)
def hat_bandana(cv, view, P):
    h = hh(P)
    if view == "E":
        rows = [(18, 29, 34), (19, 28, 35), (20, 27, 36), (21, 27, 36), (22, 27, 36), (23, 27, 37)]
        for y, a, b in rows:
            cv.put(box(a, y + h, b, y + h), 4, False)
        pts(cv, 4, [(26, 22), (25, 23), (24, 24), (26, 24), (25, 25), (24, 26)], h)             # le nœud, derrière la tête
        return
    for y, a, b in BANDANA_S:
        cv.put(box(a, y + h, b, y + h), 4, False)
    cv.put(box(37, 23 + h, 37, 23 + h), 4, False)
    pts(cv, 4, [(38, 24), (39, 24), (37, 24), (37, 25), (38, 25), (39, 26)], h)                # le nœud sur le côté


@layer("hat", "bandana", "trim", native=True)
def hat_bandana_trim(cv, view, P):
    """La tête de mort : des points blancs, comme sur la référence."""
    h = hh(P)
    if view == "S":
        pts(cv, 5, [(31, 19), (32, 19), (30, 20), (33, 20), (31, 21), (32, 21), (30, 22), (33, 22)], h)


# ------------------------------------------------------------------ les cheveux longs de la référence : des mèches fines de chaque côté
LONG_SIDE = [                      # x = 25.. : ton 4 = châtain, 3 = mèche sombre
    "..44",
    "..3.",
    ".43.",
    ".44.",
    ".34.",
    ".34.",
    ".443",
    "4444",
    "4.4.",
]


@layer("hair", "long", "hair", native=True)
def hair_long(cv, view, P):
    h = hh(P)
    if view == "S":
        cv.bmp(25, 24 + h, LONG_SIDE, mirror=True)
        cv.px(32, 24 + h, 4)
    elif view == "E":
        cv.put(box(26, 23 + h, 30, 30 + h), 4, False)
        pts(cv, 3, [(28, 24), (28, 25), (28, 26), (28, 27), (28, 28), (30, 25), (30, 26), (30, 27), (30, 28), (30, 29)], h)
        pts(cv, 4, [(26, 31), (28, 31), (29, 31), (26, 32), (29, 32)], h)
        pts(cv, 4, [(33, 24), (35, 24), (36, 24)], h)
    else:
        cv.put(box(26, 23 + h, 37, 30 + h), 4, False)
        pts(cv, 3, [(28, y) for y in range(24, 31)] + [(31, y) for y in range(24, 31)] + [(34, y) for y in range(24, 31)], h)
        pts(cv, 4, [(26, 31), (27, 31), (29, 31), (30, 31), (32, 31), (33, 31), (35, 31), (36, 31), (26, 32), (29, 32), (33, 32), (36, 32)], h)


# ------------------------------------------------------------------ le bouc de la référence : moustache et petite barbe sous la lèvre
GOATEE_S = ["4334", "4..4", "4444", "4334", "4..4"]


@layer("beard", "goatee", "hair", native=True)
def beard_goatee(cv, view, P):
    h = hh(P)
    if view == "S":
        cv.bmp(30, 29 + h, GOATEE_S)
    elif view == "E":
        cv.bmp(34, 29 + h, ["4334", "4..4", "4444", ".334"])
