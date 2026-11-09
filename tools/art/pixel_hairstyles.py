"""Les coiffures à l'échelle de la référence (voir pixel_head.py) : des mèches fines aux bouts irréguliers, sans bloc ni contour.
Un crâne de x = 27..36 ; les cheveux dépassent d'un pixel de chaque côté. Un ton plus sombre (3) trace les mèches dans la masse, un
ton clair (5) quelques reflets. Chaque coiffure est dessinée pour les vues S (face, symétrique autour de x = 32), E (profil, le
pirate regarde à droite) et N (dos)."""
from pixel_parts import layer
from pixel_head import hh, pts
from pixel_body import box


def R(cv, x0, y0, x1, y1, tone, h=0):
    cv.put(box(x0, y0 + h, x1, y1 + h), tone, False)


def Rm(cv, x0, y0, x1, y1, tone, h=0):
    """Un rectangle et son symétrique (x -> 63 - x)."""
    R(cv, x0, y0, x1, y1, tone, h)
    R(cv, 63 - x1, y0, 63 - x0, y1, tone, h)


def Pm(cv, coords, tone, h=0):
    for x, y in coords:
        cv.px(x, y + h, tone)
        cv.px(63 - x, y + h, tone)


def cap(cv, view, h, fringe=True, tone=4, narrow=False):
    """La calotte commune à presque toutes les coiffures : le dessus de la tête et les tempes."""
    if view == "S":
        Rm(cv, 29, 18, 31, 18, tone, h)
        Rm(cv, 28, 19, 31, 19, tone, h)
        Rm(cv, 27, 20, 31, 20, tone, h)
        Rm(cv, 27 if narrow else 26, 21, 31, 22, tone, h)
        Pm(cv, [(29, 20), (29, 21), (28, 22), (31, 19), (31, 21)], 3, h)
        Pm(cv, [(30, 19)], 5, h)
        if fringe:                                         # la frange : des pointes inégales sur le front
            Pm(cv, [(26, 23), (27, 23), (29, 23), (31, 23), (26, 24), (27, 24), (29, 24), (26, 25), (27, 25), (26, 26)], tone, h)
        else:                                              # les cheveux tirés en arrière : seulement les tempes
            Pm(cv, [(26, 23), (27, 23), (26, 24), (27, 24), (26, 25)], tone, h)
    elif view == "E":
        R(cv, 29, 18, 34, 18, tone, h)
        R(cv, 28, 19, 35, 19, tone, h)
        R(cv, 27, 20, 36, 20, tone, h)
        R(cv, 27 if narrow else 26, 21, 36, 21, tone, h)
        R(cv, 27 if narrow else 26, 22, 34, 22, tone, h)
        pts(cv, 3, [(29, 20), (31, 19), (30, 21), (33, 20)], h)
        pts(cv, 5, [(31, 18)], h)
        if fringe:
            pts(cv, tone, [(35, 22), (33, 23), (35, 23), (36, 22)], h)
        R(cv, 26, 23, 29, 23, tone, h)
    else:
        R(cv, 29, 18, 34, 18, tone, h)
        R(cv, 28, 19, 35, 19, tone, h)
        R(cv, 27, 20, 36, 20, tone, h)
        R(cv, 27 if narrow else 26, 21, 36 if narrow else 37, 24, tone, h)
        pts(cv, 3, [(28, 20), (30, 21), (32, 20), (34, 21), (29, 23), (33, 23), (36, 22)], h)
        pts(cv, 5, [(30, 19), (33, 19)], h)


def back(cv, view, h, bottom=28, strands=True, ragged=True):
    """La masse de cheveux derrière la tête (vue de dos : toute la nuque ; de profil : derrière l'oreille)."""
    if view == "N":
        R(cv, 26, 25, 37, bottom, 4, h)
        if strands:
            pts(cv, 3, [(x, y) for x in (28, 31, 34) for y in range(25, bottom)] + [(29, bottom), (33, bottom)], h)
        if ragged:
            R(cv, 26, bottom, 37, bottom, 3, h)
            pts(cv, 4, [(27, bottom + 1), (30, bottom + 1), (33, bottom + 1), (36, bottom + 1), (28, bottom + 2), (35, bottom + 2)], h)
    elif view == "E":
        R(cv, 26, 23, 29, bottom - 1, 4, h)
        if strands:
            pts(cv, 3, [(27, y) for y in range(24, bottom - 1)], h)
        if ragged:
            pts(cv, 4, [(26, bottom), (28, bottom), (27, bottom + 1)], h)


@layer("hair", "short", "hair", native=True)
def hair_short(cv, view, P):
    h = hh(P)
    cap(cv, view, h)
    back(cv, view, h, bottom=29)


@layer("hair", "buzz", "hair", native=True)
def hair_buzz(cv, view, P):
    """Un crâne rasé : une ombre de cheveux collée au crâne."""
    h = hh(P)
    if view == "E":
        R(cv, 28, 19, 35, 19, 3, h)
        R(cv, 27, 20, 35, 21, 3, h)
        R(cv, 26, 22, 31, 25, 3, h)
        R(cv, 28, 20, 34, 20, 2, h)
        return
    Rm(cv, 29, 19, 31, 19, 3, h)
    Rm(cv, 28, 20, 31, 21, 3, h)
    Rm(cv, 27, 22, 31, 22, 3, h)
    Rm(cv, 29, 19, 31, 19, 2, h)
    if view == "N":
        R(cv, 27, 23, 36, 25, 3, h)
    else:
        Pm(cv, [(27, 23), (27, 24)], 3, h)


@layer("hair", "ponytail", "hair", native=True)
def hair_ponytail(cv, view, P):
    h = hh(P)
    cap(cv, view, h, fringe=False)
    if view == "N":
        back(cv, view, h, bottom=28, strands=False, ragged=False)
        R(cv, 30, 25, 33, 27, 4, h)
        R(cv, 30, 24, 33, 24, 5, h)                         # l'élastique
        R(cv, 30, 28, 33, 30, 4, h)
        R(cv, 31, 31, 32, 36, 4, h)
        pts(cv, 3, [(31, y) for y in range(25, 36)], h)
        pts(cv, 4, [(31, 37), (32, 38)], h)
    elif view == "E":
        R(cv, 26, 22, 27, 25, 4, h)
        pts(cv, 5, [(25, 23), (25, 24)], h)
        R(cv, 23, 24, 25, 28, 4, h)
        R(cv, 22, 29, 24, 33, 4, h)
        pts(cv, 3, [(24, 25), (23, 28), (23, 30), (23, 32)], h)
        pts(cv, 4, [(22, 34), (23, 35)], h)


@layer("hair", "bun", "hair", native=True)
def hair_bun(cv, view, P):
    h = hh(P)
    cap(cv, view, h, fringe=False)
    if view == "E":
        R(cv, 25, 14, 28, 14, 4, h)
        R(cv, 24, 15, 29, 17, 4, h)
        R(cv, 25, 18, 28, 18, 4, h)
        pts(cv, 3, [(26, 15), (27, 16)], h)
        pts(cv, 5, [(25, 15)], h)
    else:
        R(cv, 30, 14, 33, 14, 4, h)
        R(cv, 29, 15, 34, 17, 4, h)
        R(cv, 30, 18, 33, 18, 4, h)
        pts(cv, 3, [(31, 15), (32, 16), (30, 17)], h)
        pts(cv, 5, [(30, 15), (33, 15)], h)
        if view == "N":
            back(cv, view, h, bottom=29, strands=False, ragged=False)


@layer("hair", "mohawk", "hair", native=True)
def hair_mohawk(cv, view, P):
    h = hh(P)
    hair_buzz(cv, view, P)
    if view == "E":
        for x0, top in ((29, 13), (31, 11), (33, 12), (35, 15)):
            R(cv, x0, top, x0 + 1, 19, 4, h)
        pts(cv, 5, [(32, 11), (30, 13)], h)
    else:
        R(cv, 31, 11, 32, 22, 4, h)
        R(cv, 30, 14, 30, 22, 4, h)
        R(cv, 33, 14, 33, 22, 4, h)
        R(cv, 29, 18, 29, 22, 4, h)
        R(cv, 34, 18, 34, 22, 4, h)
        pts(cv, 3, [(31, 15), (32, 17), (31, 20)], h)
        pts(cv, 5, [(31, 11), (30, 14)], h)


@layer("hair", "afro", "hair", native=True)
def hair_afro(cv, view, P):
    h = hh(P)
    if view == "E":
        R(cv, 27, 11, 34, 12, 4, h)
        R(cv, 25, 13, 36, 14, 4, h)
        R(cv, 23, 15, 36, 23, 4, h)
        R(cv, 22, 17, 22, 26, 4, h)
        R(cv, 23, 24, 29, 30, 4, h)
        R(cv, 24, 31, 27, 31, 4, h)
        pts(cv, 3, [(26, 13), (30, 15), (24, 18), (28, 20), (25, 22), (32, 17), (34, 21)], h)
        pts(cv, 5, [(28, 12), (33, 14), (24, 16)], h)
        return
    Rm(cv, 28, 12, 31, 12, 4, h)
    Rm(cv, 26, 13, 31, 14, 4, h)
    Rm(cv, 24, 15, 31, 16, 4, h)
    Rm(cv, 23, 17, 31, 23, 4, h)
    if view == "N":
        R(cv, 23, 24, 40, 29, 4, h)
        R(cv, 25, 30, 38, 31, 4, h)
        pts(cv, 3, [(26, 25), (31, 26), (36, 25), (29, 28), (34, 29), (27, 19), (38, 20)], h)
    else:
        Rm(cv, 23, 24, 27, 28, 4, h)
        Rm(cv, 25, 29, 26, 30, 4, h)
    Pm(cv, [(26, 13), (29, 15), (24, 18), (28, 20), (25, 22), (31, 12)], 3, h)
    Pm(cv, [(29, 11), (26, 14), (23, 17)], 5, h)


@layer("hair", "pigtails", "hair", native=True)
def hair_pigtails(cv, view, P):
    h = hh(P)
    cap(cv, view, h)
    if view == "E":
        R(cv, 24, 24, 26, 28, 4, h)
        R(cv, 23, 29, 25, 33, 4, h)
        pts(cv, 5, [(25, 24)], h)
        pts(cv, 3, [(24, 26), (24, 30)], h)
        pts(cv, 4, [(23, 34), (24, 35)], h)
        return
    Rm(cv, 22, 24, 25, 24, 5, h)                                    # les élastiques
    Rm(cv, 21, 25, 25, 29, 4, h)
    Rm(cv, 21, 30, 24, 34, 4, h)
    Pm(cv, [(22, 26), (23, 28), (22, 31), (23, 33)], 3, h)
    Pm(cv, [(21, 35), (23, 36), (22, 37)], 4, h)


@layer("hair", "pompadour", "hair", native=True)
def hair_pompadour(cv, view, P):
    h = hh(P)
    cap(cv, view, h, fringe=False)
    if view == "E":
        R(cv, 29, 14, 36, 14, 4, h)
        R(cv, 28, 15, 38, 17, 4, h)
        R(cv, 30, 18, 38, 18, 4, h)
        R(cv, 36, 19, 38, 20, 4, h)
        pts(cv, 3, [(31, 15), (34, 16), (36, 17), (33, 18)], h)
        pts(cv, 5, [(30, 14), (35, 14)], h)
    else:
        Rm(cv, 28, 13, 31, 13, 4, h)
        Rm(cv, 27, 14, 31, 16, 4, h)
        Rm(cv, 26, 17, 31, 17, 4, h)
        Pm(cv, [(29, 14), (30, 16), (27, 15), (28, 17)], 3, h)
        Pm(cv, [(29, 13), (30, 15)], 5, h)
        if view == "N":
            back(cv, view, h, bottom=29, strands=False, ragged=False)


@layer("hair", "dreads", "hair", native=True)
def hair_dreads(cv, view, P):
    h = hh(P)
    cap(cv, view, h)
    if view == "E":
        for x, ln in ((26, 33), (28, 31), (30, 29)):
            R(cv, x, 24, x + 1, ln, 4, h)
            pts(cv, 5, [(x, ln - 1)], h)
        return
    if view == "S":
        for x, ln in ((24, 35), (26, 31)):
            Rm(cv, x, 23, x + 1, ln, 4, h)
            Pm(cv, [(x, ln - 2)], 5, h)
            Pm(cv, [(x + 1, y) for y in range(25, ln, 3)], 3, h)
    else:
        R(cv, 26, 25, 37, 27, 4, h)
        for x, ln in ((26, 34), (28, 31), (30, 35), (32, 32), (34, 35), (36, 31)):
            R(cv, x, 28, x + 1, ln, 4, h)
            pts(cv, 5, [(x, ln - 1)], h)
            pts(cv, 3, [(x + 1, y) for y in range(29, ln, 3)], h)


@layer("hair", "bob", "hair", native=True)
def hair_bob(cv, view, P):
    h = hh(P)
    cap(cv, view, h)
    if view == "S":
        Rm(cv, 25, 23, 27, 30, 4, h)
        Pm(cv, [(26, y) for y in range(24, 30, 2)], 3, h)
        Pm(cv, [(25, 31), (27, 31)], 4, h)
    elif view == "E":
        R(cv, 25, 23, 30, 30, 4, h)
        pts(cv, 3, [(27, y) for y in range(24, 30)] + [(25, 31)], h)
        pts(cv, 4, [(26, 31), (29, 31)], h)
    else:
        R(cv, 25, 25, 38, 30, 4, h)
        pts(cv, 3, [(x, y) for x in (29, 34) for y in range(26, 30)], h)
        R(cv, 25, 31, 38, 31, 3, h)
        pts(cv, 4, [(26, 32), (29, 32), (32, 32), (35, 32)], h)


@layer("hair", "curly", "hair", native=True)
def hair_curly(cv, view, P):
    h = hh(P)
    if view == "E":
        R(cv, 28, 16, 35, 17, 4, h)
        R(cv, 25, 18, 36, 19, 4, h)
        R(cv, 23, 20, 36, 24, 4, h)
        R(cv, 23, 25, 29, 29, 4, h)
        R(cv, 24, 30, 27, 31, 4, h)
        pts(cv, 3, [(27, 17), (31, 19), (25, 21), (29, 22), (33, 20), (26, 26), (28, 28)], h)
        pts(cv, 5, [(30, 16), (26, 19), (34, 18)], h)
        return
    Rm(cv, 28, 16, 31, 17, 4, h)
    Rm(cv, 26, 18, 31, 19, 4, h)
    Rm(cv, 24, 20, 31, 24, 4, h)
    if view == "N":
        R(cv, 24, 25, 39, 29, 4, h)
        R(cv, 25, 30, 38, 31, 4, h)
        pts(cv, 3, [(26, 26), (30, 27), (34, 26), (38, 27), (28, 29), (35, 29)], h)
    else:
        Rm(cv, 24, 25, 26, 28, 4, h)
        Pm(cv, [(25, 26), (25, 28)], 3, h)
    Pm(cv, [(27, 17), (29, 19), (25, 21), (28, 23), (31, 17)], 3, h)
    Pm(cv, [(29, 16), (26, 19), (24, 21)], 5, h)


# ------------------------------------------------------------------ les cheveux longs de la référence (avec une calotte étroite, cachée par le bandana)
LONG_SIDE = [".." + r for r in ("44", "3.", "43.", "44.", "34.", "34.", "443", "4444", "4.4.")]
LONG_SIDE = ["..44", "..3.", ".43.", ".44.", ".34.", ".34.", ".443", "4444", "4.4."]


@layer("hair", "long", "hair", native=True)
def hair_long(cv, view, P):
    h = hh(P)
    if view == "S":
        cap(cv, view, h, fringe=False, narrow=True)
        Pm(cv, [(26, 23), (27, 23)], 4, h)
        cv.bmp(25, 24 + h, LONG_SIDE, mirror=True)
        cv.px(32, 24 + h, 4)
    elif view == "E":
        cap(cv, view, h, fringe=False, narrow=True)
        R(cv, 26, 23, 30, 30, 4, h)
        pts(cv, 3, [(28, 24), (28, 25), (28, 26), (28, 27), (28, 28), (30, 25), (30, 26), (30, 27), (30, 28), (30, 29)], h)
        pts(cv, 4, [(26, 31), (28, 31), (29, 31), (26, 32), (29, 32)], h)
        pts(cv, 4, [(33, 24), (35, 24), (36, 24)], h)
    else:
        cap(cv, view, h, fringe=False, narrow=True)
        R(cv, 26, 25, 37, 31, 4, h)
        pts(cv, 3, [(28, y) for y in range(25, 31)] + [(31, y) for y in range(25, 31)] + [(34, y) for y in range(25, 31)], h)
        pts(cv, 4, [(26, 32), (27, 32), (29, 32), (30, 32), (32, 32), (33, 32), (35, 32), (36, 32), (26, 33), (29, 33), (33, 33), (36, 33)], h)
