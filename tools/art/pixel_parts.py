"""Les couches du pirate en pixel art (voir pixel_pirate.py). Chaque fonction dessine UNE couche pour une vue (S, E, N) et une
pose, sur une image 64x72. Le centre est la frontière entre les colonnes 31 et 32 (x = 32.0) : une colonne c a pour symétrique
63 - c. Proportions : environ 3,6 têtes (le crâne mesure 15 pixels, le pirate 54 de la pointe des cheveux aux pieds)."""
import math

from pixel_pirate import ANIMS, W, H, Cv, nb, dil, m_poly, m_ell, m_rbox, m_limb, fill, poly, ell, rbox, limb, mir, line, PX, PY

LAYERS = {}   # id -> (catégorie, variante, emplacement, fonction)


def layer(cat, var, slot):
    def deco(fn):
        LAYERS[f"{cat}-{var}.{slot}"] = (cat, var, slot, fn)
        return fn
    return deco


HEAD_TOP = 14.0     # le haut du crâne (les cheveux dépassent de 2 pixels)
SHOULDER = 32.0
WAIST = 45.5
ANKLE = 63.0
GROUND = 67         # dernière ligne des pieds


class Pose:
    """Où sont le corps, la tête, les pieds et les mains à cette image de cette animation."""

    def __init__(self, anim, f):
        self.anim, self.f = anim, f
        n = ANIMS[anim]
        ph = 2 * math.pi * f / n
        self.carry = anim.startswith("carry")
        self.helm = anim == "helm"
        self.climb = anim == "climb"
        self.jump = anim == "jump"
        self.walking = anim in ("walk", "carry_walk")
        self.dy = 0            # le corps entier (haut du corps et tête) descend de dy pixels
        self.hdy = 0           # la tête seule
        self.lift = [0, 0]     # pieds levés (vues S et N) : [gauche, droit]
        self.plift = [0, 0]    # pieds levés (vue E) : [proche, loin]
        self.stride = 0        # vue E : avance du pied proche (le pied loin fait l'inverse)
        self.swing = 0         # balancement des bras
        self.crouch = 0        # genoux pliés (saut)
        self.arms_up = [0.0, 0.0]
        self.tq = None         # vue 3/4 en cours : SE ou NE (sinon None)
        if self.walking:
            s = math.sin(ph)
            self.dy = -1 if abs(s) < 0.4 else 0
            self.lift = [round(3.0 * max(0.0, s)), round(3.0 * max(0.0, -s))]
            self.stride = round(5.0 * s)
            self.swing = round(2.6 * s)
            self.plift = [round(2.5 * max(0.0, math.cos(ph))), round(2.5 * max(0.0, -math.cos(ph)))]
        elif anim in ("idle", "carry_idle"):
            self.hdy = [0, 0, 1, 1][f % 4]
        if self.jump:
            self.dy = [4, -2, 3][f]
            self.crouch = [4, 0, 3][f]
            self.lift = [0, 0] if f != 1 else [5, 4]
            self.plift = list(self.lift)
            self.arms_up = [[0.0, 0.0], [1.0, 1.0], [0.4, 0.4]][f]
        if self.climb:
            s = math.sin(ph)
            self.arms_up = [0.6 + 0.4 * max(0.0, s), 0.6 + 0.4 * max(0.0, -s)]
            self.lift = [round(3 * max(0.0, -s)), round(3 * max(0.0, s))]
            self.plift = list(self.lift)
            self.dy = -1 if f % 2 else 0


def head_top(P):
    return HEAD_TOP + P.dy + P.hdy


def hx(view):
    """Le centre horizontal de la tête."""
    return 31.0 if view == "E" else 32.0


# ------------------------------------------------------------------ la tête (peau)
SKULL_S = [(26.2, 2.2), (28.0, 0.3), (36.0, 0.3), (37.8, 2.2), (38.6, 6.0), (38.2, 10.0), (36.8, 13.2), (34.5, 15.0), (32, 15.6),
           (29.5, 15.0), (27.2, 13.2), (25.8, 10.0), (25.4, 6.0)]
SKULL_E = [(26.0, 2.0), (29.0, 0.3), (34.0, 0.3), (37.0, 2.0), (38.4, 5.0), (38.2, 7.0), (38.9, 9.0), (38.2, 11.2), (38.6, 12.4),
           (37.2, 13.8), (35.5, 15.2), (32.0, 15.5), (29.0, 13.8), (26.0, 11.0), (24.8, 7.5), (24.6, 4.0)]


def T(pts, top, dx=0.0):
    """Des points (x, v) avec v mesuré depuis le haut du crâne, en points de l'image."""
    return [(x + dx, top + v) for x, v in pts]


@layer("head", "round", "skin")
def head_skin(cv, view, P):
    top = head_top(P)
    # le cou, plus sombre
    poly(cv, T([(30.0, 13.0), (34.0, 13.0), (34.2, 18.5), (29.8, 18.5)], top), bias=-1, outline=False)
    if view == "E":
        poly(cv, T(SKULL_E, top), outline=True)
        # l'oreille, de profil
        poly(cv, T([(28.8, 5.6), (31.2, 5.8), (31.6, 9.0), (29.6, 10.0), (28.6, 8.6)], top), bias=-1, outline=False)
    else:
        for s in (1, -1):
            poly(cv, T([(25.6 if s > 0 else 38.4, 6.0), (24.2 if s > 0 else 39.8, 6.8), (24.0 if s > 0 else 40.0, 8.8),
                        (25.0 if s > 0 else 39.0, 10.2), (25.9 if s > 0 else 38.1, 9.6)], top), bias=-1, outline=True)
        poly(cv, T(SKULL_S, top), outline=True)
