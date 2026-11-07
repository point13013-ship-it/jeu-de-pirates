"""Pirate 3D personnalisable, rendu en couches pour les sprites du jeu.

Usage : blender.exe -b --python make_pirate.py -- <dossier de sortie ABSOLU> [options]
Options :
  --anims idle,walk,carry_idle,carry_walk,helm   (défaut : toutes)
  --layers a,b,c ou "all"                         (défaut : all) ; un id de couche = categorie-variante.emplacement
  --dirs 0,1,...,7                                (défaut : les 8)
  --frames N                                      (limite le nombre d'images par animation, pour les essais)
  --scale 4                                       (suréchantillonnage ; l'assemblage réduit à la taille finale)

Chaque COUCHE (cheveux courts, manteau long, yeux ronds...) est rendue seule, en gris éclairé, sur fond
transparent, avec les pièces qui la cachent en « découpe » (holdout). Le jeu les recolore et les empile
(voir tools/art/assemble_pirate.py et src/character/). Repère : le personnage regarde vers -Y, sa gauche
est +X, la caméra orthographique le regarde d'en haut avec ELEVATION degrés.
Sortie : <dossier>/raw/<anim>/<couche>/f<image>_d<direction>.png et <dossier>/manifest.json
Directions : 0 = vers la caméra (bas de l'écran), puis par pas de 45° vers la droite de l'écran :
S, SE, E, NE, N, NO, O, SO.
"""
import json
import math
import sys
from pathlib import Path

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

# ------------------------------------------------------------------ arguments
ARGV = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGV[0] if ARGV else ".").resolve()
OPT = {}
_i = 1
while _i < len(ARGV):
    if ARGV[_i].startswith("--"):
        OPT[ARGV[_i][2:]] = ARGV[_i + 1] if _i + 1 < len(ARGV) else ""
        _i += 2
    else:
        _i += 1
SS = int(OPT.get("scale", 4))
FINAL_W, FINAL_H = 48, 64        # taille d'une image dans le jeu
PPM = 26.0                       # pixels par mètre dans l'image finale
ELEVATION = 30.0                 # inclinaison de la caméra
FEET_ROW = 54                    # ligne des pieds dans l'image finale (origine du personnage)
FEET_COL = 24

ANIMS = {  # nom -> (nombre d'images, boucle)
    "idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3,
}

# ------------------------------------------------------------------ outils géométrie
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def make_white_material():
    m = bpy.data.materials.new("w")
    m.use_nodes = True
    nt = m.node_tree
    bsdf = nt.nodes["Principled BSDF"]
    col = nt.nodes.new("ShaderNodeVertexColor")
    col.layer_name = "Col"
    nt.links.new(col.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    for k in ("Specular IOR Level", "Specular"):
        if k in bsdf.inputs:
            bsdf.inputs[k].default_value = 0.0
    return m


def make_holdout_material():
    m = bpy.data.materials.new("hold")
    m.use_nodes = True
    nt = m.node_tree
    for n in list(nt.nodes):
        nt.nodes.remove(n)
    hold = nt.nodes.new("ShaderNodeHoldout")
    out = nt.nodes.new("ShaderNodeOutputMaterial")
    nt.links.new(hold.outputs[0], out.inputs["Surface"])
    return m


MAT_W = make_white_material()
MAT_H = make_holdout_material()

# Pivots de l'articulation : nom -> (parent, position monde au repos)
PIV = {
    "root": (None, (0, 0, 0)),
    "hips": ("root", (0, 0, 0.86)),
    "chest": ("hips", (0, 0, 0.86)),
    "neck": ("chest", (0, 0, 1.46)),
    "shL": ("chest", (0.27, 0, 1.38)),
    "shR": ("chest", (-0.27, 0, 1.38)),
    "elL": ("shL", (0.27, 0, 1.10)),
    "elR": ("elR_parent_placeholder", (-0.27, 0, 1.10)),
    "hipL": ("hips", (0.11, 0, 0.86)),
    "hipR": ("hips", (-0.11, 0, 0.86)),
    "knL": ("hipL", (0.11, 0, 0.44)),
    "knR": ("hipR", (-0.11, 0, 0.44)),
}
PIV["elR"] = ("shR", (-0.27, 0, 1.10))
PIVOTS: dict = {}
REST: dict = {}
for _n in ["root", "hips", "chest", "neck", "shL", "shR", "elL", "elR", "hipL", "hipR", "knL", "knR"]:
    _par, _pos = PIV[_n]
    _e = bpy.data.objects.new(_n, None)
    scene.collection.objects.link(_e)
    REST[_n] = Vector(_pos)
    if _par:
        _e.parent = PIVOTS[_par]
        _e.location = Vector(_pos) - REST[_par]
    else:
        _e.location = Vector(_pos)
    PIVOTS[_n] = _e


class Mesh:
    """Assemble plusieurs primitives en un seul objet."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")

    def add(self, kind, size, loc=(0, 0, 0), rot=(0, 0, 0), tone=1.0, smooth=False, seg=10,
            taper=1.0, clip=None, caps=True):
        bm = self.bm
        if kind == "box":
            res = bmesh.ops.create_cube(bm, size=1.0)
        elif kind == "sphere":
            res = bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(4, seg // 2), radius=0.5)
        elif kind == "cyl":
            res = bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg,
                                        radius1=0.5, radius2=0.5 * taper, depth=1.0)
        else:
            raise ValueError(kind)
        verts = res["verts"]
        m = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4() \
            @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0)))
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        faces = {f for v in verts for f in v.link_faces}
        for f in faces:
            f.smooth = smooth
            for lp in f.loops:
                lp[self.col] = (tone, tone, tone, 1.0)
        if clip is not None:
            dead = [v for v in verts if clip(v.co)]
            if dead:
                bmesh.ops.delete(bm, geom=dead, context="VERTS")
        return self

    def build(self, name, pivot, hold=False):
        me = bpy.data.meshes.new(name)
        self.bm.to_mesh(me)
        self.bm.free()
        ob = bpy.data.objects.new(name, me)
        ob.data.materials.append(MAT_H if hold else MAT_W)
        scene.collection.objects.link(ob)
        ob.parent = PIVOTS[pivot]
        ob.matrix_parent_inverse = Matrix.Translation(-REST[pivot])
        ob.hide_render = True
        return ob


# ------------------------------------------------------------------ registre des couches
CATEGORIES = [  # du dessous vers le dessus
    "pants", "boots", "shirt", "coat", "belt", "hands", "head", "nose", "mark", "eyes", "brows",
    "beard", "mouth", "mustache", "hair", "hat", "extra",
]
LAYERS: dict = {}     # id -> {category, variant, slot, objects, hold}


def layer(category, variant, slot, hold=()):
    lid = f"{category}-{variant}.{slot}"
    if lid not in LAYERS:
        LAYERS[lid] = {"category": category, "variant": variant, "slot": slot, "objects": [], "hold": list(hold)}
    return LAYERS[lid]


def add_part(category, variant, slot, pivot, mesh, hold=()):
    L = layer(category, variant, slot, hold)
    L["objects"].append(mesh.build(f"{category}-{variant}.{slot}.{len(L['objects'])}", pivot))


# ------------------------------------------------------------------ pièces de découpe (holdout)
HOLD: dict = {}


def make_holds():
    m = Mesh()
    m.add("box", (0.40, 0.25, 0.60), (0, 0, 1.14))
    HOLD["torso"] = [m.build("hold_torso", "chest", hold=True)]
    m = Mesh()
    for sx, p in ((0.11, "hipL"), (-0.11, "hipR")):
        pass
    mL = Mesh().add("cyl", (0.17, 0.17, 0.80), (0.11, 0, 0.44))
    mR = Mesh().add("cyl", (0.17, 0.17, 0.80), (-0.11, 0, 0.44))
    HOLD["legs"] = [mL.build("hold_legL", "hipL", hold=True), mR.build("hold_legR", "hipR", hold=True)]
    HOLD["head"] = [Mesh().add("sphere", (0.40, 0.38, 0.40), (0, 0, 1.68), smooth=True, seg=12).build(
        "hold_head", "neck", hold=True)]
    aL = Mesh().add("cyl", (0.15, 0.15, 0.62), (0.27, 0, 1.08))
    aR = Mesh().add("cyl", (0.15, 0.15, 0.62), (-0.27, 0, 1.08))
    HOLD["arms"] = [aL.build("hold_armL", "shL", hold=True), aR.build("hold_armR", "shR", hold=True)]


make_holds()

# ------------------------------------------------------------------ couleurs de ton (gris multiplié par la teinte)
T_LIGHT, T_MID, T_DARK = 1.0, 0.82, 0.62

# ------------------------------------------------------------------ MAINS ET TÊTE (peau)


def build_body_skin():
    # mains
    for side, sx, el in (("L", 0.27, "elL"), ("R", -0.27, "elR")):
        m = Mesh().add("sphere", (0.11, 0.11, 0.12), (sx, 0, 0.78), smooth=True, seg=8)
        add_part("hands", "bare", "skin", el, m, hold=["torso", "legs"])
    # tête + cou + oreilles
    m = Mesh()
    m.add("cyl", (0.14, 0.14, 0.12), (0, 0, 1.47), seg=8)
    m.add("sphere", (0.40, 0.38, 0.40), (0, 0, 1.68), smooth=True, seg=14)
    m.add("sphere", (0.05, 0.07, 0.09), (0.20, 0.0, 1.66), smooth=True, seg=6)
    m.add("sphere", (0.05, 0.07, 0.09), (-0.20, 0.0, 1.66), smooth=True, seg=6)
    add_part("head", "round", "skin", "neck", m)
    # nez
    for name, (w, h, d, lift) in {"small": (0.05, 0.06, 0.05, 0.0), "big": (0.07, 0.09, 0.08, 0.0),
                                  "pointy": (0.045, 0.07, 0.10, 0.01)}.items():
        m = Mesh().add("sphere", (w, d, h), (0, -0.19 + d * 0.05, 1.655 + lift), smooth=True, seg=7)
        add_part("nose", name, "skin", "neck", m, hold=["head"])


# ------------------------------------------------------------------ VISAGE


def build_face():
    # yeux : blanc fixe + iris teinté ; 5 formes
    shapes = {
        "round": dict(w=0.085, h=0.085, tilt=0, brow=(0.09, 0.02, 0.0)),
        "narrow": dict(w=0.095, h=0.045, tilt=0, brow=(0.09, 0.02, 0.0)),
        "angry": dict(w=0.085, h=0.06, tilt=-14, brow=(0.10, 0.03, -20)),
        "wide": dict(w=0.10, h=0.10, tilt=0, brow=(0.09, 0.03, 8)),
        "sleepy": dict(w=0.09, h=0.05, tilt=6, brow=(0.09, 0.0, 10)),
    }
    for name, s in shapes.items():
        mw = Mesh()
        mi = Mesh()
        for sx, sgn in ((0.095, 1), (-0.095, -1)):
            mw.add("box", (s["w"], 0.03, s["h"]), (sx, -0.172, 1.70), (0, s["tilt"] * sgn, 0), tone=1.0)
            mi.add("box", (s["w"] * 0.6, 0.032, s["h"] * 0.9), (sx - 0.005 * sgn, -0.178, 1.70),
                   (0, s["tilt"] * sgn, 0), tone=0.9)
        add_part("eyes", name, "white", "neck", mw, hold=["head"])
        add_part("eyes", name, "iris", "neck", mi, hold=["head"])
    # sourcils : 4 formes, teinte des cheveux
    for name, (w, th, ang) in {"normal": (0.10, 0.025, 0), "thick": (0.11, 0.045, 0), "angry": (0.11, 0.04, -22),
                               "raised": (0.10, 0.03, 12)}.items():
        m = Mesh()
        for sx, sgn in ((0.095, 1), (-0.095, -1)):
            m.add("box", (w, 0.03, th), (sx, -0.176, 1.77), (0, ang * sgn, 0), tone=0.9)
        add_part("brows", name, "hair", "neck", m, hold=["head"])
    # bouche
    mouths = {
        "smile": [("box", (0.09, 0.02, 0.018), (0, -0.182, 1.585), (0, 0, 0)),
                  ("box", (0.02, 0.02, 0.02), (0.05, -0.18, 1.6), (0, 0, 0)),
                  ("box", (0.02, 0.02, 0.02), (-0.05, -0.18, 1.6), (0, 0, 0))],
        "neutral": [("box", (0.08, 0.02, 0.016), (0, -0.182, 1.585), (0, 0, 0))],
        "grin": [("box", (0.12, 0.02, 0.04), (0, -0.182, 1.59), (0, 0, 0))],
        "frown": [("box", (0.08, 0.02, 0.016), (0, -0.182, 1.585), (0, 0, 0)),
                  ("box", (0.02, 0.02, 0.02), (0.05, -0.18, 1.57), (0, 0, 0)),
                  ("box", (0.02, 0.02, 0.02), (-0.05, -0.18, 1.57), (0, 0, 0))],
    }
    for name, prims in mouths.items():
        m = Mesh()
        for k, sz, loc, rot in prims:
            m.add(k, sz, loc, rot)
        add_part("mouth", name, "mouth", "neck", m, hold=["head"])
    # signes particuliers : cache-œil (gauche/droit), cicatrice, monocle
    for name, sx in (("patch_l", 0.095), ("patch_r", -0.095)):
        m = Mesh()
        m.add("box", (0.12, 0.035, 0.11), (sx, -0.178, 1.70), (0, 0, 8 if sx > 0 else -8))
        m.add("cyl", (0.415, 0.395, 0.025), (0, 0, 1.78), (0, 0, 0), seg=14)  # lanière autour du crâne
        add_part("mark", name, "patch", "neck", m, hold=["head"])
    m = Mesh()
    m.add("box", (0.02, 0.03, 0.17), (0.11, -0.176, 1.69), (0, 0, 18))
    add_part("mark", "scar", "scar", "neck", m, hold=["head"])
    m = Mesh()
    m.add("cyl", (0.13, 0.03, 0.13), (-0.095, -0.182, 1.70), (90, 0, 0), seg=12)
    add_part("mark", "monocle", "frame", "neck", m, hold=["head"])


# ------------------------------------------------------------------ CHEVEUX, BARBES, MOUSTACHES


def head_clip(z_front, z_back):
    """Garde les points au-dessus d'un plan qui va de z_front (devant, y<0) à z_back (derrière)."""
    return lambda p: p.z < z_back + (z_front - z_back) * max(0.0, min(1.0, (0.19 - p.y) / 0.38))


def build_hair():
    cap = lambda m, k=1.0: m.add("sphere", (0.43 * k, 0.41 * k, 0.43 * k), (0, 0.005, 1.69), smooth=True, seg=14,
                                clip=head_clip(1.77, 1.55))
    HOLDS = ["torso", "head"]
    m = Mesh()
    cap(m)
    add_part("hair", "short", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.425, 0.40, 0.425), (0, 0.01, 1.685), smooth=True, seg=14, clip=head_clip(1.835, 1.60))
    add_part("hair", "buzz", "hair", "neck", m, HOLDS)
    m = Mesh()
    cap(m)
    m.add("box", (0.44, 0.12, 0.62), (0, 0.13, 1.40), tone=0.9)
    m.add("box", (0.05, 0.12, 0.30), (0.215, 0.0, 1.58), tone=0.9)
    m.add("box", (0.05, 0.12, 0.30), (-0.215, 0.0, 1.58), tone=0.9)
    add_part("hair", "long", "hair", "neck", m, HOLDS)
    m = Mesh()
    cap(m)
    m.add("sphere", (0.12, 0.12, 0.12), (0, 0.22, 1.78), smooth=True, seg=8)
    m.add("cyl", (0.09, 0.09, 0.38), (0, 0.27, 1.55), (8, 0, 0), taper=0.35, seg=8)
    add_part("hair", "ponytail", "hair", "neck", m, HOLDS)
    m = Mesh()
    cap(m)
    m.add("sphere", (0.17, 0.17, 0.17), (0, 0.0, 1.97), smooth=True, seg=10)
    add_part("hair", "bun", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.425, 0.40, 0.425), (0, 0.01, 1.685), smooth=True, seg=12, clip=head_clip(1.835, 1.60))
    for i in range(5):
        y = -0.12 + i * 0.075
        m.add("box", (0.05, 0.07, 0.15 + 0.03 * (2 - abs(i - 2))), (0, y, 1.93 + 0.01 * (2 - abs(i - 2))))
    add_part("hair", "mohawk", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.64, 0.60, 0.60), (0, 0.04, 1.80), smooth=True, seg=14, clip=head_clip(1.76, 1.52))
    add_part("hair", "afro", "hair", "neck", m, HOLDS)
    m = Mesh()
    cap(m)
    m.add("sphere", (0.16, 0.16, 0.2), (0.27, -0.02, 1.66), smooth=True, seg=8)
    m.add("sphere", (0.16, 0.16, 0.2), (-0.27, -0.02, 1.66), smooth=True, seg=8)
    m.add("cyl", (0.1, 0.1, 0.34), (0.28, 0.0, 1.46), taper=0.4, seg=8)
    m.add("cyl", (0.1, 0.1, 0.34), (-0.28, 0.0, 1.46), taper=0.4, seg=8)
    add_part("hair", "pigtails", "hair", "neck", m, HOLDS)


def build_beards():
    HOLDS = ["head", "torso"]
    # barbes : sous le nez, autour de la mâchoire
    def jaw(m, depth=0.07, width=0.40, drop=0.0, zc=1.55):
        m.add("sphere", (width, 0.38 + depth, 0.30 + drop), (0, -0.01 - depth * 0.15, zc - drop * 0.45), smooth=True,
              seg=12, clip=lambda p: p.z > 1.64 or (p.y < 0.0 and 1.55 < p.z < 1.625 and abs(p.x) < 0.075))
    m = Mesh()
    jaw(m, depth=0.012, width=0.405)
    add_part("beard", "stubble", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.14, 0.12, 0.17), (0, -0.165, 1.52), smooth=True, seg=8)
    add_part("beard", "goatee", "hair", "neck", m, HOLDS)
    m = Mesh()
    jaw(m, depth=0.06, width=0.43, drop=0.05)
    add_part("beard", "full", "hair", "neck", m, HOLDS)
    m = Mesh()
    jaw(m, depth=0.08, width=0.44, drop=0.10)
    m.add("cyl", (0.20, 0.16, 0.42), (0, -0.14, 1.28), (-6, 0, 0), taper=0.55, seg=8)
    add_part("beard", "long", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.10, 0.10, 0.50), (0, -0.15, 1.20), (-4, 0, 0), taper=0.3, seg=7)
    m.add("sphere", (0.40, 0.32, 0.20), (0, -0.02, 1.52), smooth=True, seg=10,
          clip=lambda p: p.z > 1.60 or p.y > 0.05)
    add_part("beard", "braid", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("box", (0.045, 0.08, 0.20), (0.205, -0.03, 1.62))
    m.add("box", (0.045, 0.08, 0.20), (-0.205, -0.03, 1.62))
    m.add("box", (0.30, 0.04, 0.045), (0, -0.17, 1.50))
    add_part("beard", "chinstrap", "hair", "neck", m, HOLDS)
    # moustaches
    m = Mesh()
    m.add("box", (0.12, 0.03, 0.025), (0, -0.19, 1.615))
    add_part("mustache", "thin", "hair", "neck", m, ["head"])
    m = Mesh()
    m.add("box", (0.10, 0.04, 0.03), (0, -0.19, 1.615))
    m.add("cyl", (0.03, 0.03, 0.09), (0.085, -0.185, 1.625), (0, 0, 0), taper=0.4, seg=6)
    m.add("cyl", (0.03, 0.03, 0.09), (-0.085, -0.185, 1.625), (0, 0, 0), taper=0.4, seg=6)
    m.add("sphere", (0.03, 0.04, 0.03), (0.13, -0.18, 1.665), smooth=True, seg=6)
    m.add("sphere", (0.03, 0.04, 0.03), (-0.13, -0.18, 1.665), smooth=True, seg=6)
    add_part("mustache", "handlebar", "hair", "neck", m, ["head"])
    m = Mesh()
    m.add("box", (0.20, 0.06, 0.07), (0, -0.19, 1.61), tone=0.9)
    add_part("mustache", "walrus", "hair", "neck", m, ["head"])


# ------------------------------------------------------------------ CHAPEAUX


def build_hats():
    HOLDS = ["head"]
    # tricorne : triangle à pointe devant
    m = Mesh()
    m.add("cyl", (0.70, 0.70, 0.035), (0, 0, 1.90), (0, 0, 90), seg=3)
    m.add("cyl", (0.40, 0.40, 0.16), (0, 0, 1.98), seg=12, taper=0.92)
    add_part("hat", "tricorn", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.41, 0.41, 0.04), (0, 0, 1.94), seg=12, taper=1.0, caps=False)
    add_part("hat", "tricorn", "trim", "neck", m, HOLDS)
    # bicorne de capitaine : calotte basse, deux rebords relevés sur les côtés, plume
    m = Mesh()
    m.add("cyl", (0.40, 0.38, 0.14), (0, 0, 1.95), seg=12, taper=0.95)
    m.add("box", (0.20, 0.34, 0.07), (0.28, 0, 1.93), (0, 0, 0), tone=0.9)
    m.add("box", (0.20, 0.34, 0.07), (-0.28, 0, 1.93), (0, 0, 0), tone=0.9)
    m.add("box", (0.14, 0.30, 0.10), (0.35, 0, 1.99), (0, -25, 0), tone=0.85)
    m.add("box", (0.14, 0.30, 0.10), (-0.35, 0, 1.99), (0, 25, 0), tone=0.85)
    add_part("hat", "bicorn", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.41, 0.39, 0.035), (0, 0, 1.92), seg=12, caps=False)
    m.add("sphere", (0.09, 0.09, 0.24), (0.20, 0.10, 2.10), (0, 24, 0), smooth=True, seg=6)
    add_part("hat", "bicorn", "trim", "neck", m, HOLDS)
    # bandana noué
    m = Mesh()
    m.add("sphere", (0.44, 0.42, 0.44), (0, 0.005, 1.69), smooth=True, seg=14, clip=head_clip(1.78, 1.70))
    m.add("sphere", (0.09, 0.09, 0.09), (0.0, 0.215, 1.76), smooth=True, seg=6)
    m.add("box", (0.05, 0.03, 0.17), (0.04, 0.25, 1.67), (0, 0, 14))
    m.add("box", (0.05, 0.03, 0.15), (-0.04, 0.25, 1.67), (0, 0, -18))
    add_part("hat", "bandana", "hat", "neck", m, HOLDS)
    # chapeau de paille
    m = Mesh()
    m.add("cyl", (0.80, 0.80, 0.03), (0, 0, 1.88), seg=16)
    m.add("sphere", (0.44, 0.44, 0.34), (0, 0, 1.94), smooth=True, seg=14, clip=lambda p: p.z < 1.88)
    add_part("hat", "straw", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.445, 0.445, 0.06), (0, 0, 1.925), seg=14, caps=False)
    add_part("hat", "straw", "trim", "neck", m, HOLDS)
    # bonnet / calot
    m = Mesh()
    m.add("sphere", (0.45, 0.43, 0.46), (0, 0.0, 1.70), smooth=True, seg=14, clip=head_clip(1.84, 1.72))
    add_part("hat", "cap", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.46, 0.44, 0.07), (0, 0, 1.80), seg=14, caps=False)
    add_part("hat", "cap", "trim", "neck", m, HOLDS)


# ------------------------------------------------------------------ VÊTEMENTS


def arm_segments(m_up, m_lo, upper_r, lower_r, sleeves, tone=1.0):
    """Ajoute le bras gauche/droit : manche haute (m_up) et basse (m_lo) selon sleeves = (haut, bas)."""
    return


def sleeve_parts(cat, variant, slot, up_r, lo_r, up=True, lo=True, tone=1.0, cuff=None):
    for side, sx, sh, el in (("L", 0.27, "shL", "elL"), ("R", -0.27, "shR", "elR")):
        if up:
            m = Mesh().add("cyl", (up_r, up_r, 0.30), (sx, 0, 1.23), taper=0.92, seg=8, tone=tone)
            add_part(cat, variant, slot, sh, m, hold=[])
        if lo:
            m = Mesh().add("cyl", (lo_r, lo_r, 0.30), (sx, 0, 0.95), taper=0.82, seg=8, tone=tone)
            add_part(cat, variant, slot, el, m, hold=[])


def build_shirts():
    # peau nue
    m = Mesh().add("box", (0.40, 0.24, 0.60), (0, 0, 1.14), smooth=False)
    m.add("sphere", (0.40, 0.26, 0.32), (0, 0, 1.30), smooth=True, seg=8)
    add_part("shirt", "bare", "skin", "chest", m)
    sleeve_parts("shirt", "bare", "skin", 0.13, 0.11)
    # t-shirt
    m = Mesh().add("box", (0.42, 0.26, 0.60), (0, 0, 1.14))
    add_part("shirt", "tee", "cloth", "chest", m)
    m = Mesh().add("box", (0.12, 0.20, 0.05), (0, -0.04, 1.43))
    sleeve_parts("shirt", "tee", "cloth", 0.15, 0.11, lo=False)
    for side, sx, el in (("L", 0.27, "elL"), ("R", -0.27, "elR")):
        add_part("shirt", "tee", "skin", el, Mesh().add("cyl", (0.11, 0.11, 0.30), (sx, 0, 0.95), taper=0.82, seg=8), [])
    add_part("shirt", "tee", "skin", "chest", Mesh().add("box", (0.12, 0.2, 0.08), (0, -0.01, 1.45)))
    # chemise de pirate à manches bouffantes, col ouvert
    m = Mesh().add("box", (0.43, 0.27, 0.60), (0, 0, 1.14))
    m.add("box", (0.46, 0.22, 0.10), (0, 0, 0.88), tone=0.8)
    add_part("shirt", "pirate", "cloth", "chest", m)
    add_part("shirt", "pirate", "skin", "chest", Mesh().add("box", (0.12, 0.1, 0.22), (0, -0.09, 1.34)))
    sleeve_parts("shirt", "pirate", "cloth", 0.19, 0.17)
    # marinière rayée
    m = Mesh().add("box", (0.42, 0.26, 0.60), (0, 0, 1.14))
    add_part("shirt", "striped", "cloth", "chest", m)
    ms = Mesh()
    for i in range(5):
        ms.add("box", (0.43, 0.27, 0.05), (0, 0, 0.90 + i * 0.11), tone=0.85)
    add_part("shirt", "striped", "stripe", "chest", ms)
    sleeve_parts("shirt", "striped", "cloth", 0.14, 0.12)


def build_coats():
    # gilet : sans manches
    m = Mesh().add("box", (0.46, 0.29, 0.52), (0, 0, 1.17))
    m.add("box", (0.46, 0.29, 0.10), (0, 0, 0.89), tone=0.85)
    add_part("coat", "vest", "cloth", "chest", m)
    add_part("coat", "vest", "trim", "chest", Mesh().add("box", (0.05, 0.03, 0.56), (0, -0.152, 1.15)))
    # veste courte à manches longues
    m = Mesh().add("box", (0.47, 0.30, 0.56), (0, 0, 1.16))
    m.add("box", (0.50, 0.30, 0.14), (0, 0, 0.90), tone=0.9)
    m.add("box", (0.50, 0.12, 0.08), (0, -0.07, 1.46), tone=0.85)
    add_part("coat", "jacket", "cloth", "chest", m)
    add_part("coat", "jacket", "trim", "chest", Mesh().add("box", (0.06, 0.03, 0.56), (0, -0.158, 1.15)))
    sleeve_parts("coat", "jacket", "cloth", 0.17, 0.15)
    # manteau de capitaine : long, grand col, parements
    m = Mesh().add("box", (0.48, 0.31, 0.58), (0, 0, 1.15))
    m.add("box", (0.46, 0.32, 0.12), (0, 0, 1.43), tone=0.85)
    add_part("coat", "captain", "cloth", "chest", m)
    ms = Mesh().add("cyl", (0.58, 0.40, 0.40), (0, 0, 0.66), taper=0.8, seg=10, tone=0.92)
    ms.add("box", (0.56, 0.12, 0.10), (0, -0.04, 1.47), (-12, 0, 0), tone=0.8)
    add_part("coat", "captain", "cloth", "hips", ms)
    add_part("coat", "captain", "trim", "chest", Mesh().add("box", (0.07, 0.03, 0.62), (0, -0.162, 1.12)))
    sleeve_parts("coat", "captain", "cloth", 0.18, 0.16)
    for side, sx, el in (("L", 0.27, "elL"), ("R", -0.27, "elR")):
        add_part("coat", "captain", "trim", el, Mesh().add("cyl", (0.17, 0.17, 0.08), (sx, 0, 0.85), seg=8), [])


def build_belts():
    m = Mesh().add("box", (0.47, 0.30, 0.07), (0, 0, 0.94), tone=0.9)
    add_part("belt", "belt", "belt", "chest", m, hold=["arms"])
    add_part("belt", "belt", "buckle", "chest", Mesh().add("box", (0.09, 0.03, 0.08), (0, -0.155, 0.94)), hold=["arms"])
    m = Mesh().add("box", (0.49, 0.31, 0.10), (0, 0, 0.94), tone=0.9)
    m.add("box", (0.09, 0.04, 0.30), (0.17, -0.15, 0.76), (0, 0, 8), tone=0.8)
    add_part("belt", "sash", "belt", "chest", m, hold=["arms"])
    m = Mesh().add("box", (0.50, 0.33, 0.07), (0, 0, 0.94), tone=0.9)
    m.add("box", (0.07, 0.34, 0.68), (0, 0, 1.13), (0, 0, 0), tone=0.9)
    add_part("belt", "baldric", "belt", "chest", Mesh().add("box", (0.075, 0.34, 0.80), (0.0, 0.0, 1.13), (0, 0, 32)),
             hold=["arms"])
    add_part("belt", "baldric", "buckle", "chest", Mesh().add("box", (0.09, 0.03, 0.08), (0, -0.175, 1.14)), hold=["arms"])


def build_pants_boots():
    for variant, (r, bottom, show_skin) in {"long": (0.17, 0.10, False), "shorts": (0.18, 0.60, True),
                                           "rolled": (0.17, 0.30, True)}.items():
        for sx, hp, kn in ((0.11, "hipL", "knL"), (-0.11, "hipR", "knR")):
            top_len = 0.46
            if variant == "shorts":
                add_part("pants", variant, "cloth", hp, Mesh().add("cyl", (r + 0.01, r + 0.01, 0.40), (sx, 0, 0.64), taper=0.95, seg=8), [])
                add_part("pants", variant, "skin", hp, Mesh().add("cyl", (0.13, 0.13, 0.30), (sx, 0, 0.30), seg=8), [])
                add_part("pants", variant, "skin", kn, Mesh().add("cyl", (0.12, 0.12, 0.30), (sx, 0, 0.22), seg=8), [])
            else:
                add_part("pants", variant, "cloth", hp, Mesh().add("cyl", (r, r, 0.46), (sx, 0, 0.64), taper=0.9, seg=8), [])
                low_bottom = 0.10 if variant == "long" else 0.30
                length = 0.44 - (low_bottom - 0.10) * 0 if variant == "long" else 0.26
                zc = 0.10 + length / 2 if variant == "long" else 0.30 + 0.13
                add_part("pants", variant, "cloth", kn, Mesh().add("cyl", (r * 0.9, r * 0.9, length), (sx, 0, zc), taper=0.95, seg=8), [])
                if variant == "rolled":
                    add_part("pants", variant, "skin", kn, Mesh().add("cyl", (0.11, 0.11, 0.2), (sx, 0, 0.17), seg=8), [])
        # bassin
    m = Mesh().add("box", (0.40, 0.25, 0.14), (0, 0, 0.89))
    for v in ("long", "shorts", "rolled"):
        add_part("pants", v, "cloth", "hips", Mesh().add("box", (0.40, 0.25, 0.16), (0, 0, 0.88)))
    # bottes
    for variant in ("high", "shoes", "barefoot", "sandals"):
        for sx, kn in ((0.11, "knL"), (-0.11, "knR")):
            foot = Mesh()
            if variant == "high":
                foot.add("cyl", (0.17, 0.17, 0.36), (sx, 0, 0.26), taper=1.06, seg=8)
                foot.add("box", (0.15, 0.30, 0.10), (sx, -0.06, 0.05))
                foot.add("cyl", (0.20, 0.20, 0.08), (sx, 0, 0.44), seg=8, tone=0.85)
                add_part("boots", variant, "boot", kn, foot, [])
            elif variant == "shoes":
                foot.add("box", (0.14, 0.28, 0.10), (sx, -0.05, 0.05))
                foot.add("box", (0.13, 0.14, 0.09), (sx, 0.0, 0.14), tone=0.9)
                add_part("boots", variant, "boot", kn, foot, [])
            elif variant == "barefoot":
                foot.add("box", (0.12, 0.26, 0.08), (sx, -0.05, 0.04))
                foot.add("box", (0.11, 0.12, 0.09), (sx, 0.0, 0.13))
                add_part("boots", variant, "skin", kn, foot, [])
            else:
                foot.add("box", (0.14, 0.28, 0.025), (sx, -0.05, 0.015))
                add_part("boots", variant, "boot", kn, foot, [])
                f2 = Mesh().add("box", (0.12, 0.26, 0.07), (sx, -0.05, 0.05))
                f2.add("box", (0.11, 0.12, 0.08), (sx, 0.0, 0.12))
                add_part("boots", variant, "skin", kn, f2, [])


build_body_skin()
build_face()
build_hair()
build_beards()
build_hats()
build_shirts()
build_coats()
build_belts()
build_pants_boots()

# ------------------------------------------------------------------ animation


def set_rot(piv, x=0.0, y=0.0, z=0.0):
    PIVOTS[piv].rotation_euler = (math.radians(x), math.radians(y), math.radians(z))


def pose(anim: str, t: float) -> None:
    """t dans [0, 1[. Angles en degrés ; x négatif = vers l'avant (-Y)."""
    for n in PIVOTS:
        if n != "root":
            PIVOTS[n].rotation_euler = (0, 0, 0)
    base = {"hips": REST["hips"] - REST["root"]}
    bob = 0.0
    c = math.cos(2 * math.pi * t)
    s = math.sin(2 * math.pi * t)
    walking = anim in ("walk", "carry_walk")
    carrying = anim.startswith("carry")
    arms_fwd = carrying or anim == "helm"
    lean = 0.0
    if walking:
        sw = 30.0
        set_rot("hipL", -sw * s)
        set_rot("hipR", sw * s)
        set_rot("knL", 38.0 * max(0.0, math.sin(2 * math.pi * t - 1.2)) + 6)
        set_rot("knR", 38.0 * max(0.0, math.sin(2 * math.pi * t + math.pi - 1.2)) + 6)
        bob = 0.035 * abs(math.cos(2 * math.pi * t * 1.0 + 0.0)) - 0.0
        bob = 0.03 * (math.cos(4 * math.pi * t) * 0.5 + 0.5)
        lean = 4.0
        set_rot("chest", -lean, 0, 5.0 * s)
        set_rot("neck", 0, 0, -3.0 * s)
        if not arms_fwd:
            set_rot("shL", 26.0 * s)
            set_rot("shR", -26.0 * s)
            set_rot("elL", -14 - 12 * max(0, -s))
            set_rot("elR", -14 - 12 * max(0, s))
    else:
        breathe = 0.5 + 0.5 * s
        bob = 0.012 * breathe
        if not arms_fwd:
            set_rot("shL", 3 - 2 * breathe, 0, -4)
            set_rot("shR", 3 - 2 * breathe, 0, 4)
            set_rot("elL", -8 - 3 * breathe)
            set_rot("elR", -8 - 3 * breathe)
        set_rot("chest", -1.5 * breathe)
        set_rot("neck", 1.5 * breathe)
    if anim == "climb":
        # grimpe à l'échelle : bras et jambes en alternance, face à l'échelle
        k = math.sin(2 * math.pi * t)
        up, dn = max(k, 0.0), max(-k, 0.0)
        set_rot("shL", -150 + 32 * k, 0, -8)
        set_rot("shR", -150 - 32 * k, 0, 8)
        set_rot("elL", -25)
        set_rot("elR", -25)
        set_rot("hipL", -50 * up - 8)
        set_rot("hipR", -50 * dn - 8)
        set_rot("knL", 80 * up + 12)
        set_rot("knR", 80 * dn + 12)
        set_rot("chest", -7)
        bob = 0.02 * abs(k)
    elif anim == "jump":
        frame = min(2, int(t * 3.0 + 1e-6))
        if frame == 0:    # accroupi, bras en arrière
            set_rot("hipL", -55); set_rot("hipR", -55); set_rot("knL", 100); set_rot("knR", 100)
            set_rot("shL", 28, 0, -6); set_rot("shR", 28, 0, 6); set_rot("elL", -15); set_rot("elR", -15)
            set_rot("chest", -14)
            bob = -0.22
        elif frame == 1:  # en l'air : jambes repliées, bras levés
            set_rot("hipL", -38); set_rot("hipR", -26); set_rot("knL", 70); set_rot("knR", 55)
            set_rot("shL", -150, 0, -12); set_rot("shR", -150, 0, 12); set_rot("elL", -20); set_rot("elR", -20)
            set_rot("chest", -3)
            bob = 0.0
        else:             # réception
            set_rot("hipL", -40); set_rot("hipR", -40); set_rot("knL", 70); set_rot("knR", 70)
            set_rot("shL", -30, 0, -10); set_rot("shR", -30, 0, 10); set_rot("elL", -30); set_rot("elR", -30)
            set_rot("chest", -10)
            bob = -0.15
    elif anim in ("carry_idle", "carry_walk"):
        # bras en avant, serrant quelque chose contre la poitrine
        set_rot("shL", -62, 0, -14)
        set_rot("shR", -62, 0, 14)
        set_rot("elL", -78)
        set_rot("elR", -78)
    elif anim == "helm":
        set_rot("shL", -48, 0, -8)
        set_rot("shR", -48, 0, 8)
        set_rot("elL", -30)
        set_rot("elR", -30)
        set_rot("hipL", -4)
        set_rot("hipR", 4)
    PIVOTS["hips"].location = Vector((0, 0, REST["hips"].z + bob))


# ------------------------------------------------------------------ rendu
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.film_transparent = True
scene.render.resolution_x = FINAL_W * SS
scene.render.resolution_y = FINAL_H * SS
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 4
except AttributeError:
    pass

world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (1, 1, 1, 1)
bg.inputs["Strength"].default_value = 0.42

key = bpy.data.lights.new("key", "SUN")
key.energy = 2.4
key.use_shadow = False
key_ob = bpy.data.objects.new("key", key)
key_ob.rotation_euler = (math.radians(42), 0, math.radians(-38))
scene.collection.objects.link(key_ob)

cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = FINAL_H / PPM
cam_ob = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(cam_ob)
scene.camera = cam_ob
el = math.radians(ELEVATION)
aim_z = (FINAL_H / 2 - FEET_ROW + (FINAL_H - FINAL_H)) / PPM / math.cos(el)  # l'origine tombe sur FEET_ROW
aim_z = (FEET_ROW - FINAL_H / 2) / PPM / math.cos(el)
dist = 20.0
cam_ob.location = (0, -dist * math.cos(el), aim_z + dist * math.sin(el))
cam_ob.rotation_euler = (math.radians(90 - ELEVATION), 0, 0)
# décalage horizontal : l'origine doit tomber sur la colonne FEET_COL
cam.shift_x = (FINAL_W / 2 - FEET_COL) / PPM / cam.ortho_scale * (FINAL_W / FINAL_H) * 0 + 0.0

anims = OPT.get("anims", ",".join(ANIMS)).split(",")
dirs = [int(x) for x in OPT.get("dirs", "0,1,2,3,4,5,6,7").split(",")]
wanted = OPT.get("layers", "all")
if wanted == "all":
    layer_ids = list(LAYERS)
else:
    layer_ids = [x for x in wanted.split(",") if x in LAYERS]
    for want in wanted.split(","):
        if want not in LAYERS:
            # accepte « categorie-variante » : toutes ses couches
            layer_ids += [k for k in LAYERS if k.startswith(want + ".")]
    layer_ids = list(dict.fromkeys(layer_ids))
max_frames = int(OPT.get("frames", 0))

all_objs = [o for L in LAYERS.values() for o in L["objects"]] + [o for v in HOLD.values() for o in v]
for L in LAYERS.values():
    pass

OUT.mkdir(parents=True, exist_ok=True)
manifest = {
    "frame": [FINAL_W, FINAL_H], "feet": [FEET_COL, FEET_ROW], "ppm": PPM, "directions": 8,
    "anims": dict(ANIMS), "categories": CATEGORIES,
    "layers": {k: {"category": v["category"], "variant": v["variant"], "slot": v["slot"]} for k, v in LAYERS.items()},
}
(OUT / "manifest.json").write_text(json.dumps(manifest, indent=1))

for anim in anims:
    nframes = ANIMS[anim] if not max_frames else min(ANIMS[anim], max_frames)
    for f in range(nframes):
        pose(anim, f / ANIMS[anim])
        for d in dirs:
            PIVOTS["root"].rotation_euler = (0, 0, math.radians(45 * d))
            for lid in layer_ids:
                L = LAYERS[lid]
                for o in all_objs:
                    o.hide_render = True
                for o in L["objects"]:
                    o.hide_render = False
                for h in L["hold"]:
                    for o in HOLD[h]:
                        o.hide_render = False
                path = OUT / "raw" / anim / lid
                path.mkdir(parents=True, exist_ok=True)
                scene.render.filepath = str(path / f"f{f}_d{d}.png")
                bpy.ops.render.render(write_still=True)
print("rendu termine", len(layer_ids), "couches")
