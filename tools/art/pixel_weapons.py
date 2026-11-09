"""Les armes à feu dans les mains du pirate, pour les animations de tir (« shoot_pistolet », « shoot_tromblon », « shoot_fusil »).
Chaque arme est une catégorie « weapon » de deux couches (métal, bois) qui ne se dessinent que dans l'animation du même nom, aux mains
du pirate (voir pixel_body.aim_arms). Elles ne font pas partie de l'apparence du joueur : le jeu les ajoute à la feuille de l'animation.
Vues : de profil et en 3/4, l'arme part droit devant ; de face on regarde dans la bouche du canon (le dessus du canon se voit au-dessus,
la caméra étant en hauteur) ; de dos elle dépasse sur le côté droit, vers le haut de l'image (elle part loin de la caméra)."""
import math

from pixel_pirate import limb, ell, rbox, fill, m_ell
from pixel_parts import layer
from pixel_body import arms

# canon : longueur et épaisseur (pixels), évasement de la bouche ; crosse : longueur et épaisseur
SPEC = {
    "pistolet": {"barrel": 7.5, "thick": 2.6, "flare": 0.0, "stock": 3.5, "stock_w": 3.4},
    "tromblon": {"barrel": 8.0, "thick": 3.2, "flare": 3.0, "stock": 6.0, "stock_w": 3.8},
    "fusil": {"barrel": 15.0, "thick": 2.2, "flare": 0.0, "stock": 7.5, "stock_w": 3.0},
}


def _gun_arm(view, P):
    """Le bras qui tient l'arme : le proche (vue de profil ou 3/4), la main droite (face et dos)."""
    lst = arms(view, P)
    if view == "E" or P.tq:
        return lst[-1]
    return [a for a in lst if a["side"] == "R"][0]


def _direction(view, P):
    if view == "E":
        return (1.0, 0.0)
    if P.tq == "SE":
        return (1.0, 0.32)
    if P.tq == "NE":
        return (1.0, -0.3)
    return None


# le sabre : lame (métal) et poignée (bois). Sa direction change à chaque image du coup : levé, tranchant vers l'avant, retombé.
BLADE = 11.0
SABRE_DIR = {"side": [(0.35, -1.0), (1.0, 0.12), (0.75, 0.75)],      # de profil et en 3/4 (x vers la droite de l'image)
             "front": [(0.1, -1.0), (0.0, 0.0), (0.55, 0.8)],         # de face : levé, pointé vers la caméra, retombé
             "back": [(0.1, -1.0), (0.3, -0.9), (0.55, 0.8)]}


def _draw_sabre(cv, view, P, slot):
    a = _gun_arm(view, P)
    wx, wy = a["pts"][-1]
    kind = "side" if (view == "E" or P.tq) else ("front" if view == "S" else "back")
    dx, dy = SABRE_DIR[kind][P.f]
    n = math.hypot(dx, dy)
    if n < 0.01:   # de face, la pointe vers la caméra : on ne voit que le bout de la lame
        if slot == "metal":
            ell(cv, wx, wy - 1.0, 2.0, 1.8)
            fill(cv, m_ell(wx, wy - 1.0, 0.9, 0.8), flat=1, outline=False)
            limb(cv, [(wx, wy - 1.0 - BLADE * 0.5), (wx, wy - 1.0)], [1.6, 1.6])
        else:
            rbox(cv, int(round(wx)) - 1, int(round(wy)) + 1, int(round(wx)) + 1, int(round(wy)) + 3, 0.5)
        return
    dx, dy = dx / n, dy / n
    if slot == "metal":
        limb(cv, [(wx + dx * 1.5, wy + dy * 1.5), (wx + dx * BLADE, wy + dy * BLADE)], [1.9, 1.1])
    else:
        limb(cv, [(wx - dx * 2.5, wy - dy * 2.5), (wx + dx * 1.5, wy + dy * 1.5)], [2.2, 2.2])
        # la garde : une petite barre en travers
        px, py = -dy, dx
        limb(cv, [(wx + dx * 1.2 - px * 2.0, wy + dy * 1.2 - py * 2.0), (wx + dx * 1.2 + px * 2.0, wy + dy * 1.2 + py * 2.0)], [1.4, 1.4])


def _draw(cv, view, P, variant, slot):
    if variant == "sabre":
        if P.anim == "slash_sabre":
            _draw_sabre(cv, view, P, slot)
        return
    if P.anim != f"shoot_{variant}":
        return
    spec = SPEC[variant]
    a = _gun_arm(view, P)
    wx, wy = a["pts"][-1]
    d = _direction(view, P)
    if d is not None:   # de profil ou en 3/4 : l'arme part droit devant, vers la droite de l'image
        n = math.hypot(*d)
        dx, dy = d[0] / n, d[1] / n
        if slot == "metal":
            p0 = (wx - dx * 1.0, wy - dy * 1.0 - 1.2)
            p1 = (wx + dx * spec["barrel"], wy + dy * spec["barrel"] - 1.2)
            limb(cv, [p0, p1], [spec["thick"], spec["thick"] + spec["flare"]])
        else:
            p0 = (wx - dx * spec["stock"], wy - dy * spec["stock"] + 0.8)
            p1 = (wx + dx * 0.6, wy + dy * 0.6 - 0.4)
            limb(cv, [p0, p1], [spec["stock_w"] * 0.8, spec["stock_w"]])
            if variant == "pistolet":   # la poignée
                rbox(cv, int(round(wx)) - 1, int(round(wy)), int(round(wx)) + 1, int(round(wy)) + 4, 0.5)
        return
    cx, cy = int(round(wx)), int(round(wy))
    if view == "S":   # face à la caméra
        r = spec["thick"] * 0.6 + 0.8 + spec["flare"] * 0.3
        if slot == "metal":
            # le dessus du canon, vu d'en haut, monte depuis la bouche ; la bouche (cercle sombre) est au bout, côté caméra
            limb(cv, [(wx, wy - 1.0 - spec["barrel"] * 0.55), (wx, wy - 1.0)], [spec["thick"] * 0.9, spec["thick"] * 0.9 + spec["flare"] * 0.4])
            ell(cv, wx, wy - 0.5, r, r * 0.9)
            fill(cv, m_ell(wx, wy - 0.5, r * 0.45, r * 0.4), flat=1, outline=False)
        else:
            rbox(cv, cx - 1, cy + 1, cx + 1, cy + 2 + int(spec["stock"] * 0.5), 0.5)
        return
    # de dos : l'arme dépasse sur le côté droit, vers le haut ; la crosse reste dans les mains
    if slot == "metal":
        limb(cv, [(wx, wy - 1.0), (wx + 0.3, wy - 1.0 - spec["barrel"] * 0.85)], [spec["thick"], spec["thick"] + spec["flare"] * 0.6])
    else:
        rbox(cv, cx - 1, cy - 1, cx + 1, cy + 2 + int(spec["stock"] * 0.4), 0.5)


def _register():
    for variant in list(SPEC) + ["sabre"]:
        for slot in ("metal", "wood"):
            layer("weapon", variant, slot)(lambda cv, view, P, v=variant, s=slot: _draw(cv, view, P, v, s))


_register()
