"""Le visage du pirate, pixel par pixel. Comme dans Eastward : un visage MINUSCULE (des yeux de deux pixels, un trait de nez,
un trait de bouche) pour laisser la place aux cheveux et au chapeau. Vue S : symétrique autour de x = 32 (colonne c <-> 63 - c).
Vue E : un seul œil, le nez dépasse du profil. Vue N : rien."""
from pixel_parts import layer, head_top
from pixel_pirate import poly, rbox, limb, line, W


def flip_row(s):
    return s[::-1]


def eye_row(P):
    return int(head_top(P)) + 8


def pair(cv, x, y, rows, mirrored=False):
    """Deux yeux (ou sourcils) : l'un à la colonne x, l'autre à son symétrique. Les tons ne sont pas retournés (la lumière vient
    de la gauche) ; `mirrored` retourne la FORME du second (sourcils froncés)."""
    width = max(len(r) for r in rows)
    cv.bmp(x, y, rows)
    cv.bmp(W - x - width, y, [flip_row(r) for r in rows] if mirrored else rows)


# ------------------------------------------------------------------ yeux : le blanc (côté extérieur) et l'iris
EYES = {   # variante: (blanc S, iris S, blanc E, iris E) ; lignes relatives à la ligne des yeux
    "round": (["3", "3"], ["52", "44"], ["3", "3"], ["52", "44"]),
    "narrow": (["", "3"], ["..", "44"], ["", "3"], ["..", "44"]),
    "angry": (["", "3"], ["22", "44"], ["", "3"], ["22", "44"]),
    "wide": (["3", "3", "3"], ["52", "44", "44"], ["3", "3", "3"], ["52", "44", "44"]),
    "sleepy": (["", ""], ["..", "33"], ["", ""], ["..", "33"]),
}


def _eyes(slot):
    for name, (wS, iS, wE, iE) in EYES.items():
        @layer("eyes", name, slot)
        def draw(cv, view, P, wS=wS, iS=iS, wE=wE, iE=iE, name=name):
            y = eye_row(P) - (1 if name == "wide" else 0)
            if view == "S":
                if slot == "white":
                    for j, r in enumerate(wS):
                        if r:
                            cv.px(27, y + j, 3)
                            cv.px(36, y + j, 3)
                else:
                    pair(cv, 28, y, iS)
            elif view == "E":
                if slot == "white":
                    for j, r in enumerate(wE):
                        if r:
                            cv.px(36, y + j, 3)
                else:
                    cv.bmp(34, y, iE)


_eyes("white")
_eyes("iris")


# ------------------------------------------------------------------ sourcils
BROWS = {   # variante: (S, ligne relative, symétrie de forme, E)
    "normal": (["333"], -2, False, ["333"]),
    "thick": (["444", "333"], -3, False, ["444", "333"]),
    "angry": (["3..", ".33"], -3, True, ["3..", ".33"]),
    "raised": ([".33", "3.."], -3, True, [".33", "3.."]),
}
for _name, (_s, _dy, _mir, _e) in BROWS.items():
    @layer("brows", _name, "hair")
    def _brow(cv, view, P, _s=_s, _dy=_dy, _mir=_mir, _e=_e):
        y = eye_row(P) + _dy
        if view == "S":
            pair(cv, 27, y, _s, mirrored=_mir)
        elif view == "E":
            cv.bmp(34, y, _e)


# ------------------------------------------------------------------ nez
S_NOSE = {"small": (31, 3, ["33"]), "big": (30, 2, [".55.", "3333"]), "pointy": (31, 1, ["54", "33", "33"]),
          "round": (31, 2, ["54", "33"]), "flat": (30, 3, ["3333"])}
E_NOSE = {   # polygone (relatif à la ligne des yeux) qui dépasse du profil
    "small": [(37.6, 0.2), (40.0, 2.4), (38.2, 3.4)],
    "big": [(37.6, -0.6), (41.2, 2.6), (38.4, 3.8)],
    "pointy": [(37.6, -0.8), (42.0, 2.8), (38.2, 3.4)],
    "round": [(37.6, -0.2), (40.6, 1.4), (40.2, 3.4), (38.2, 3.8)],
    "flat": [(37.8, 0.6), (39.6, 2.0), (38.2, 3.4)],
}
for _name, (_x, _dy, _rows) in S_NOSE.items():
    @layer("nose", _name, "skin")
    def _nose(cv, view, P, _name=_name, _x=_x, _dy=_dy, _rows=_rows):
        y = eye_row(P)
        if view == "S":
            cv.bmp(_x, y + _dy, _rows)
        elif view == "E":
            poly(cv, [(px, y + py) for px, py in E_NOSE[_name]], outline=True)


# ------------------------------------------------------------------ bouche
def _mouth(name, x, rows, dy=4, teeth=None, e_rows=None, e_teeth=None):
    @layer("mouth", name, "mouth")
    def draw(cv, view, P):
        y = eye_row(P) + dy
        if view == "S":
            cv.bmp(x, y, rows)
        elif view == "E":
            cv.bmp(36, y + 1, e_rows if e_rows is not None else rows[-1:][0:1] and ["33"])
    if teeth:
        @layer("mouth", name, "teeth")
        def draw_t(cv, view, P):
            y = eye_row(P) + dy
            if view == "S":
                cv.bmp(x, y, teeth)
            elif view == "E" and e_teeth is not None:
                cv.bmp(36, y + 1, e_teeth)


_mouth("smile", 30, ["2..2", ".33."], e_rows=["..", "33"])
_mouth("neutral", 30, ["....", "3333"], e_rows=["33"])
_mouth("grin", 29, ["3....3", ".3333."], teeth=[".4444.", "......"], e_rows=["3", "33"], e_teeth=["4"])
_mouth("frown", 30, ["....", ".33.", "3..3"][1:], dy=5, e_rows=["33", ".3"])
_mouth("open", 30, ["3333", "3333", ".33."], teeth=[".44."], e_rows=["33", "33"], e_teeth=["44"])


@layer("mouth", "pipe", "mouth")
def mouth_pipe(cv, view, P):
    y = eye_row(P) + 5
    if view == "S":
        cv.bmp(30, y, ["3333"])
    elif view == "E":
        cv.bmp(36, y, ["33"])


@layer("mouth", "pipe", "pipe")
def pipe(cv, view, P):
    y = eye_row(P) + 5
    if view == "S":
        cv.bmp(26, y, ["4444"])
        cv.bmp(25, y + 1, ["43"])
        poly(cv, [(22.5, y + 2), (26.5, y + 2), (26.5, y + 6.5), (23.5, y + 7)], outline=True)
        cv.bmp(23, y + 2, ["55"])
    elif view == "E":
        cv.bmp(36, y, ["4444"])
        poly(cv, [(40, y - 4), (44.5, y - 4.5), (44.5, y + 0.5), (41, y + 0.8)], outline=True)
        cv.bmp(41, y - 4, ["55"])


# ------------------------------------------------------------------ signes particuliers
for _name, _side in (("patch_l", 0), ("patch_r", 1)):
    @layer("mark", _name, "patch")
    def _patch(cv, view, P, _side=_side):
        y = eye_row(P)
        top = head_top(P)
        if view == "S":
            x0 = 26 if _side == 0 else 33
            rbox(cv, x0, y - 1, x0 + 4, y + 3, 1.2, outline=True, flat=3)
            if _side == 0:
                line(cv, (x0 + 5, y - 1), (38, int(top) + 3), 2)
                line(cv, (x0, y), (25, int(top) + 5), 2)
            else:
                line(cv, (x0 - 1, y - 1), (26, int(top) + 3), 2)
                line(cv, (x0 + 5, y), (38, int(top) + 5), 2)
        elif view == "E":
            rbox(cv, 33, y - 1, 37, y + 3, 1.2, outline=True, flat=3)
            line(cv, (33, y), (25, int(top) + 5), 2)
        elif view == "N":
            line(cv, (25, int(top) + 5), (38, int(top) + 3), 2) if _side == 0 else line(cv, (25, int(top) + 3), (38, int(top) + 5), 2)


@layer("mark", "scar", "scar")
def scar(cv, view, P):
    y = eye_row(P)
    if view == "S":
        for i, (dx, dy) in enumerate([(0, -1), (0, 0), (1, 1), (1, 2), (2, 3)]):
            cv.px(34 + dx, y + dy, 3 if i % 2 else 4)
        cv.px(33, y + 1, 5)
    elif view == "E":
        for i, (dx, dy) in enumerate([(0, -1), (0, 0), (1, 1), (1, 2), (2, 3)]):
            cv.px(31 + dx, y + dy, 3 if i % 2 else 4)


@layer("mark", "monocle", "frame")
def monocle(cv, view, P):
    y = eye_row(P)
    ring = [(1, 0), (2, 0), (0, 1), (3, 1), (0, 2), (3, 2), (1, 3), (2, 3)]
    x0 = 33 if view == "S" else 33
    if view in ("S", "E"):
        for dx, dy in ring:
            cv.px(x0 + dx, y - 1 + dy, 5 if dy < 2 else 4)
        for i in range(6):
            cv.px(x0 + 3 + (i // 3), y + 3 + i, 4)


@layer("mark", "earrings", "frame")
def earrings(cv, view, P):
    y = eye_row(P) + 3
    if view in ("S", "N"):
        for x in (23, 40):
            cv.bmp(x, y, ["5", "4"])
    elif view == "E":
        cv.bmp(29, y, ["5", "4"])
