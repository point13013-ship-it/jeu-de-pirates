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
FINAL_W, FINAL_H = 48, 64        # taille d une image dans le jeu (le pirate fait ~54 px à l écran : ne pas l agrandir)
PPM = 24.0                       # pixels par mètre dans l image finale (23,5 et non 26 : la tête est agrandie, le haut du crâne reste à la même hauteur qu avant)
ELEVATION = 30.0                 # inclinaison de la caméra
FEET_ROW = 58                    # ligne des pieds dans l image finale (origine du personnage)
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

# Tête plus grosse (proportions de pixel art : le visage doit se lire en ~13 pixels) : tout ce qui est accroché au cou
# (crâne, visage, cheveux, barbes, chapeaux) grandit autour du cou. Le corps reste à la même taille.
HEAD_K = float(OPT.get("head", 1.58))     # taille finale de la tête par rapport au modèle de base
BODY_K = float(OPT.get("body", 0.86))     # torse et bras
LEG_K = float(OPT.get("legs", 0.76))      # jambes : courtes (silhouette ramassée, tête très lisible)
PIVOTS["hips"].scale = (LEG_K, LEG_K, LEG_K)
PIVOTS["chest"].scale = (BODY_K / LEG_K,) * 3
PIVOTS["neck"].scale = (HEAD_K / BODY_K,) * 3
PIVOTS["neck"].location.z += 0.09     # la tête monte : de face, le visage est vu plus bas qu'il n'est (caméra à 30°) et le col des manteaux lui mangeait la bouche


class Mesh:
    """Assemble plusieurs primitives en un seul objet."""

    def __init__(self):
        self.bm = bmesh.new()
        self.col = self.bm.loops.layers.color.new("Col")

    def add(self, kind, size, loc=(0, 0, 0), rot=(0, 0, 0), tone=1.0, smooth=False, seg=10,
            taper=1.0, clip=None, caps=True, on_head=None):
        bm = self.bm
        if on_head is not None:
            # Posé SUR le crâne (ellipsoïde 0.40 x 0.38 x 0.40 centré en z=1.68) à la hauteur et à la largeur données,
            # à `on_head` mètres de sa surface, tourné pour épouser la courbure : rien ne dépasse de la silhouette de
            # la tête, donc rien ne se voit « à travers » quand on regarde de dos ou de biais.
            x, z = loc[0], loc[2]
            q = max(0.0, 1.0 - (x / 0.2) ** 2 - ((z - 1.68) / 0.2) ** 2)
            r = 0.19 * math.sqrt(q)
            yaw = math.degrees(math.atan2(x / 0.04, r / 0.0361 + 1e-6)) if q > 0 else 70.0
            loc = (x, -(r + on_head), z)
            rot = (rot[0], rot[1], rot[2] + yaw)
        before = set(bm.faces)
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
        rounded = kind == "box" and min(size) >= 0.10
        m = Matrix.Translation(Vector(loc)) @ Euler([math.radians(a) for a in rot], "XYZ").to_matrix().to_4x4() \
            @ Matrix.Diagonal(Vector((size[0], size[1], size[2], 1.0)))
        bmesh.ops.transform(bm, matrix=m, verts=verts)
        if rounded:
            edges = list({e for v in verts for e in v.link_edges})
            bmesh.ops.bevel(bm, geom=edges, offset=min(0.045, min(size) * 0.32), segments=2, profile=0.62,
                            affect="EDGES")
        faces = [f for f in bm.faces if f not in before]
        verts = list({v for f in faces for v in f.verts})
        for f in faces:
            f.smooth = smooth or rounded
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
    # Tout est volontairement GROS : à 48x64 pixels, un détail de moins de ~1,3 pixel (5 cm) disparaît à la réduction.
    # yeux : blanc fixe + iris teinté ; 5 formes
    shapes = {
        "round": dict(w=0.095, h=0.095, tilt=0, ix=0.60, iy=0.90),
        "narrow": dict(w=0.115, h=0.055, tilt=0, ix=0.50, iy=1.0),
        "angry": dict(w=0.100, h=0.070, tilt=-18, ix=0.58, iy=1.0),
        "wide": dict(w=0.108, h=0.120, tilt=0, ix=0.55, iy=0.82),
        "sleepy": dict(w=0.108, h=0.055, tilt=8, ix=0.66, iy=0.9),
    }
    for name, s in shapes.items():
        mw = Mesh()
        mi = Mesh()
        for sx, sgn in ((0.100, 1), (-0.100, -1)):
            mw.add("box", (s["w"] * 0.80, 0.016, s["h"] * 0.95), (sx, 0, 1.705), (0, s["tilt"] * sgn, 0), tone=1.0, on_head=0.005)
            # l'iris regarde un peu vers le centre
            mi.add("box", (s["w"] * 0.80 * s["ix"], 0.016, s["h"] * 0.95 * s["iy"]), (sx - 0.012 * sgn, 0, 1.705),
                   (0, s["tilt"] * sgn, 0), tone=0.9, on_head=0.011)
        add_part("eyes", name, "white", "neck", mw, hold=["head"])
        add_part("eyes", name, "iris", "neck", mi, hold=["head"])
    # sourcils : épais et nets, teinte des cheveux
    for name, (w, th, ang, z) in {"normal": (0.13, 0.055, 0, 1.790), "thick": (0.145, 0.085, 0, 1.795),
                                  "angry": (0.135, 0.065, -26, 1.785), "raised": (0.125, 0.055, 16, 1.815)}.items():
        m = Mesh()
        for sx, sgn in ((0.100, 1), (-0.100, -1)):
            m.add("box", (w, 0.02, th), (sx, 0, z), (0, ang * sgn, 0), tone=0.9, on_head=0.010)
        add_part("brows", name, "hair", "neck", m, hold=["head"])
    # nez : de vrais reliefs (les noms de chaque forme se voient de face ET de profil)
    for name, (w, h, d, dz) in {"small": (0.085, 0.09, 0.09, 0.0), "big": (0.135, 0.17, 0.15, 0.0),
                                "pointy": (0.075, 0.13, 0.19, 0.0), "round": (0.13, 0.13, 0.13, 0.0),
                                "flat": (0.15, 0.075, 0.07, 0.0)}.items():
        m = Mesh().add("sphere", (w, d, h), (0, -0.185 + d * 0.12, 1.655 + dz), smooth=True, seg=8)
        m.add("sphere", (w * 0.9, d * 0.95, h * 0.38), (0, -0.185 + d * 0.12 + 0.01, 1.655 + dz - h * 0.36), smooth=True, seg=8, tone=0.5)
        add_part("nose", name, "skin", "neck", m, hold=["head"])
    # bouche : rouge sombre, avec les dents en blanc pour le grand sourire
    mouths = {
        "smile": [("box", (0.11, 0.03, 0.03), (0, 0, 1.553), (0, 0, 0)),
                  ("box", (0.035, 0.03, 0.04), (0.065, 0, 1.575), (0, 0, 0)),
                  ("box", (0.035, 0.03, 0.04), (-0.065, 0, 1.575), (0, 0, 0))],
        "neutral": [("box", (0.10, 0.03, 0.03), (0, 0, 1.553), (0, 0, 0))],
        "grin": [("box", (0.17, 0.03, 0.075), (0, 0, 1.563), (0, 0, 0))],
        "frown": [("box", (0.10, 0.03, 0.03), (0, 0, 1.558), (0, 0, 0)),
                  ("box", (0.035, 0.03, 0.04), (0.065, 0, 1.533), (0, 0, 0)),
                  ("box", (0.035, 0.03, 0.04), (-0.065, 0, 1.533), (0, 0, 0))],
        "open": [("box", (0.105, 0.03, 0.105), (0, 0, 1.543), (0, 0, 0))],
        "pipe": [("box", (0.10, 0.03, 0.03), (0, 0, 1.553), (0, 0, 0))],
    }
    for name, prims in mouths.items():
        m = Mesh()
        for k, sz, loc, rot in prims:
            m.add(k, sz, loc, rot, on_head=0.004)
        add_part("mouth", name, "mouth", "neck", m, hold=["head"])
    # dents (grand sourire) : une bande blanche sur le haut de la bouche
    m = Mesh().add("box", (0.14, 0.034, 0.03), (0, 0, 1.583), (0, 0, 0), on_head=0.024)
    add_part("mouth", "grin", "teeth", "neck", m, hold=["head"])
    m = Mesh().add("box", (0.075, 0.034, 0.03), (0, 0, 1.573), (0, 0, 0), on_head=0.024)
    add_part("mouth", "open", "teeth", "neck", m, hold=["head"])
    # pipe : tuyau qui part de la bouche vers l'avant-côté, fourneau au bout
    m = Mesh()
    m.add("box", (0.045, 0.19, 0.045), (-0.085, -0.28, 1.563), (0, 0, 28))
    m.add("cyl", (0.095, 0.095, 0.13), (-0.135, -0.37, 1.608), (0, 0, 0), seg=8)
    add_part("mouth", "pipe", "pipe", "neck", m, hold=[])
    # signes particuliers : cache-œil (gauche/droit), cicatrice, monocle, boucle d'oreille
    for name, sx in (("patch_l", 0.100), ("patch_r", -0.100)):
        m = Mesh()
        m.add("box", (0.165, 0.045, 0.15), (sx, 0, 1.70), (0, 0, 8 if sx > 0 else -8), on_head=0.02)
        m.add("cyl", (0.425, 0.405, 0.04), (0, 0, 1.785), (0, 0, 0), seg=14)  # lanière autour du crâne
        add_part("mark", name, "patch", "neck", m, hold=["head"])
    m = Mesh()
    m.add("box", (0.035, 0.045, 0.27), (0.115, 0, 1.69), (0, 20, 0), on_head=0.016)
    add_part("mark", "scar", "scar", "neck", m, hold=["head"])
    m = Mesh()
    for i in range(10):   # monture du monocle : un anneau de petits blocs (un cylindre vu de face ne montrerait rien)
        a = math.tau * i / 10
        m.add("box", (0.05, 0.035, 0.05), (-0.100 + 0.095 * math.cos(a), 0, 1.705 + 0.095 * math.sin(a)), on_head=0.03)
    m.add("box", (0.022, 0.03, 0.17), (-0.20, -0.17, 1.58), (0, 0, 8))   # la chaîne
    add_part("mark", "monocle", "frame", "neck", m, hold=["head"])
    m = Mesh()
    m.add("sphere", (0.07, 0.07, 0.09), (0.222, 0.01, 1.60), smooth=True, seg=8)
    m.add("sphere", (0.07, 0.07, 0.09), (-0.222, 0.01, 1.60), smooth=True, seg=8)
    m.add("box", (0.03, 0.03, 0.09), (0.222, 0.01, 1.54))
    m.add("box", (0.03, 0.03, 0.09), (-0.222, 0.01, 1.54))
    add_part("mark", "earrings", "frame", "neck", m, hold=[])


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
    # Barbes : de GROSSES masses lisibles, car à 48x64 pixels une barbe fine ne change rien à l'image.
    def jaw(m, depth=0.07, width=0.40, drop=0.0, zc=1.55):
        # 1) une coque collée au crâne (joues et mâchoire, jusqu'aux oreilles), à `ext` mètres de la peau
        ext = 0.012 + depth * 0.22
        low = 1.50 - drop * 0.25
        m.add("sphere", (0.40 + 2 * ext, 0.38 + 2 * ext, 0.40 + 2 * ext), (0, 0.0, 1.68), smooth=True, seg=36,
              clip=lambda p: p.z > 1.60 or p.z < low or p.y > 0.035 or abs(p.x) > 0.175 or (p.y < 0.0 and 1.555 < p.z < 1.625 and abs(p.x) < 0.07))
        # 2) le menton : une masse qui prolonge la coque vers le bas, de la largeur de la mâchoire
        m.add("sphere", (0.25 + depth * 0.8, 0.19 + depth * 0.5, 0.15 + drop * 0.7), (0, -0.115, 1.515 - drop * 0.25), smooth=True,
              seg=14, clip=lambda p: p.z > 1.56 or (p.y < -0.10 and 1.555 < p.z < 1.625 and abs(p.x) < 0.07))
    m = Mesh()
    jaw(m, depth=0.03, width=0.415, drop=0.02)
    add_part("beard", "stubble", "hair", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.19, 0.16, 0.24), (0, -0.165, 1.50), smooth=True, seg=8)
    add_part("beard", "goatee", "hair", "neck", m, HOLDS)
    m = Mesh()
    jaw(m, depth=0.10, width=0.47, drop=0.14)
    add_part("beard", "full", "hair", "neck", m, HOLDS)
    m = Mesh()
    jaw(m, depth=0.11, width=0.48, drop=0.16)
    m.add("cyl", (0.30, 0.22, 0.66), (0, -0.15, 1.20), (-5, 0, 0), taper=0.45, seg=9)
    add_part("beard", "long", "hair", "neck", m, HOLDS)
    # barbe à une natte : joues + une grosse natte nouée (anneaux), bout effilé
    m = Mesh()
    jaw(m, depth=0.07, width=0.44, drop=0.04)
    for i in range(6):
        m.add("sphere", (0.15 - i * 0.012, 0.15 - i * 0.012, 0.13), (0, -0.17 - i * 0.012, 1.40 - i * 0.105), smooth=True, seg=7,
              tone=1.0 if i % 2 == 0 else 0.82)
    add_part("beard", "braid", "hair", "neck", m, HOLDS)
    # deux nattes
    m = Mesh()
    jaw(m, depth=0.05, width=0.42, drop=0.02)
    for sx in (0.11, -0.11):
        for i in range(5):
            m.add("sphere", (0.11, 0.11, 0.12), (sx, -0.16 - i * 0.01, 1.42 - i * 0.10), smooth=True, seg=6, tone=1.0 if i % 2 == 0 else 0.82)
    add_part("beard", "twin", "hair", "neck", m, HOLDS)
    # barbe fourchue de viking
    m = Mesh()
    jaw(m, depth=0.08, width=0.45, drop=0.08)
    m.add("cyl", (0.20, 0.17, 0.52), (0.10, -0.15, 1.25), (-4, 0, -18), taper=0.25, seg=7)
    m.add("cyl", (0.20, 0.17, 0.52), (-0.10, -0.15, 1.25), (-4, 0, 18), taper=0.25, seg=7)
    add_part("beard", "forked", "hair", "neck", m, HOLDS)
    # favoris : grosses pattes + mentonnière
    m = Mesh()
    m.add("box", (0.085, 0.15, 0.32), (0.205, -0.03, 1.60))
    m.add("box", (0.085, 0.15, 0.32), (-0.205, -0.03, 1.60))
    m.add("box", (0.34, 0.07, 0.075), (0, -0.17, 1.50))
    add_part("beard", "chinstrap", "hair", "neck", m, HOLDS)
    # grosses pattes seules (côtelettes)
    m = Mesh()
    m.add("sphere", (0.15, 0.17, 0.28), (0.19, -0.05, 1.60), smooth=True, seg=7)
    m.add("sphere", (0.15, 0.17, 0.28), (-0.19, -0.05, 1.60), smooth=True, seg=7)
    add_part("beard", "chops", "hair", "neck", m, HOLDS)
    # barbe broussailleuse : énorme, ronde
    m = Mesh()
    m.add("sphere", (0.56, 0.50, 0.50), (0, -0.05, 1.45), smooth=True, seg=12,
          clip=lambda p: p.z > 1.64 or p.y > 0.10 or (p.y < 0.0 and 1.55 < p.z < 1.625 and abs(p.x) < 0.075))
    add_part("beard", "bushy", "hair", "neck", m, HOLDS)
    # moustaches
    m = Mesh()
    m.add("box", (0.15, 0.04, 0.04), (0, -0.192, 1.616))
    add_part("mustache", "thin", "hair", "neck", m, ["head"])
    m = Mesh()
    m.add("box", (0.12, 0.05, 0.05), (0, -0.192, 1.615))
    m.add("cyl", (0.05, 0.05, 0.12), (0.115, -0.185, 1.635), (0, 0, 0), taper=0.5, seg=6)
    m.add("cyl", (0.05, 0.05, 0.12), (-0.115, -0.185, 1.635), (0, 0, 0), taper=0.5, seg=6)
    m.add("sphere", (0.06, 0.06, 0.06), (0.14, -0.18, 1.70), smooth=True, seg=6)
    m.add("sphere", (0.06, 0.06, 0.06), (-0.14, -0.18, 1.70), smooth=True, seg=6)
    add_part("mustache", "handlebar", "hair", "neck", m, ["head"])
    m = Mesh()
    m.add("box", (0.27, 0.085, 0.10), (0, -0.19, 1.612), tone=0.9)
    add_part("mustache", "walrus", "hair", "neck", m, ["head"])
    m = Mesh()
    m.add("box", (0.20, 0.07, 0.075), (0, -0.19, 1.62))
    m.add("box", (0.06, 0.07, 0.11), (0.095, -0.185, 1.585), (0, 0, -10))
    m.add("box", (0.06, 0.07, 0.11), (-0.095, -0.185, 1.585), (0, 0, 10))
    add_part("mustache", "chevron", "hair", "neck", m, ["head"])


def build_hair_extra():
    HOLDS = ["torso", "head"]
    cap = lambda m, k=1.0: m.add("sphere", (0.43 * k, 0.41 * k, 0.43 * k), (0, 0.005, 1.69), smooth=True, seg=14,
                                clip=head_clip(1.77, 1.55))
    # banane : une grosse vague devant
    m = Mesh()
    cap(m)
    m.add("sphere", (0.40, 0.30, 0.20), (0, -0.12, 1.93), (-18, 0, 0), smooth=True, seg=10)
    add_part("hair", "pompadour", "hair", "neck", m, HOLDS)
    # dreadlocks : sept mèches épaisses qui pendent
    m = Mesh()
    cap(m)
    for i, a in enumerate((-70, -45, -20, 0, 20, 45, 70)):
        x = 0.23 * math.sin(math.radians(a))
        y = 0.20 * math.cos(math.radians(a)) + 0.02
        m.add("cyl", (0.085, 0.085, 0.50 - 0.03 * (i % 2)), (x, y, 1.40), taper=0.7, seg=6, tone=1.0 if i % 2 else 0.88)
    add_part("hair", "dreads", "hair", "neck", m, HOLDS)
    # carré : tombe jusqu'au menton, frange nette
    m = Mesh()
    cap(m, 1.04)
    m.add("box", (0.47, 0.16, 0.46), (0, 0.11, 1.55), tone=0.9)
    m.add("box", (0.08, 0.22, 0.34), (0.222, -0.02, 1.56), tone=0.9)
    m.add("box", (0.08, 0.22, 0.34), (-0.222, -0.02, 1.56), tone=0.9)
    m.add("box", (0.40, 0.07, 0.07), (0, -0.172, 1.80))
    add_part("hair", "bob", "hair", "neck", m, HOLDS)
    # bouclés : beaucoup de boules
    m = Mesh()
    cap(m, 0.98)
    for i in range(11):
        a = math.tau * i / 11
        m.add("sphere", (0.17, 0.17, 0.17), (0.24 * math.cos(a), 0.18 * math.sin(a) + 0.02, 1.80 + 0.04 * math.sin(3 * a)), smooth=True, seg=6)
    for i in range(5):
        a = math.tau * i / 5
        m.add("sphere", (0.17, 0.17, 0.17), (0.12 * math.cos(a), 0.10 * math.sin(a), 1.92), smooth=True, seg=6)
    add_part("hair", "curly", "hair", "neck", m, HOLDS)


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
    add_part("hat", "tricorn", "trim", "neck", m, HOLDS + ["@hat-tricorn.hat"])
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
    add_part("hat", "bicorn", "trim", "neck", m, HOLDS + ["@hat-bicorn.hat"])
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
    add_part("hat", "straw", "trim", "neck", m, HOLDS + ["@hat-straw.hat"])
    # bonnet / calot
    m = Mesh()
    m.add("sphere", (0.47, 0.45, 0.40), (0, 0.0, 1.80), smooth=True, seg=48, clip=lambda p: p.z < 1.84)
    add_part("hat", "cap", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.484, 0.464, 0.412), (0, 0.0, 1.80), smooth=True, seg=48,
          clip=lambda p: not (1.80 <= p.z <= 1.875))
    add_part("hat", "cap", "trim", "neck", m, HOLDS + ["@hat-cap.hat"])


def build_hats_extra():
    HOLDS = ["head"]
    # haut-de-forme
    m = Mesh()
    m.add("cyl", (0.62, 0.62, 0.035), (0, 0, 1.88), seg=14)
    m.add("cyl", (0.36, 0.36, 0.28), (0, 0, 2.02), seg=12, taper=0.96)
    add_part("hat", "tophat", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("cyl", (0.375, 0.375, 0.08), (0, 0, 1.95), seg=12, caps=False)
    add_part("hat", "tophat", "trim", "neck", m, HOLDS + ["@hat-tophat.hat"])
    # turban : plusieurs grosses boules enroulées, et un joyau
    m = Mesh()
    m.add("sphere", (0.50, 0.48, 0.30), (0, 0, 1.86), smooth=True, seg=12)
    m.add("sphere", (0.46, 0.44, 0.24), (0, 0, 2.00), smooth=True, seg=12, tone=0.9)
    m.add("sphere", (0.30, 0.30, 0.22), (0, 0, 2.10), smooth=True, seg=10)
    add_part("hat", "turban", "hat", "neck", m, HOLDS)
    m = Mesh()
    m.add("sphere", (0.09, 0.07, 0.10), (0, -0.235, 1.90), smooth=True, seg=6)
    add_part("hat", "turban", "trim", "neck", m, HOLDS)
    # bandeau : un ruban autour du front, bouts qui flottent
    m = Mesh()
    m.add("sphere", (0.455, 0.435, 0.45), (0, 0.005, 1.69), smooth=True, seg=48,
          clip=lambda p: not (1.805 <= p.z <= 1.87))
    m.add("box", (0.07, 0.04, 0.24), (0.07, 0.26, 1.70), (0, 0, 16))
    m.add("box", (0.07, 0.04, 0.20), (-0.05, 0.26, 1.69), (0, 0, -20))
    add_part("hat", "headband", "hat", "neck", m, HOLDS)


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
    ms.add("box", (0.56, 0.12, 0.08), (0, -0.04, 1.435), (-6, 0, 0), tone=0.8)
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
build_hair_extra()
build_beards()
build_hats()
build_hats_extra()
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
    PIVOTS["hips"].location = Vector((0, 0, REST["hips"].z * LEG_K + bob))


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
                swapped = []
                for h in L["hold"]:
                    if h.startswith("@"):   # une autre couche qui cache celle-ci (ex. le chapeau cache son ruban)
                        for o in LAYERS[h[1:]]["objects"]:
                            o.hide_render = False
                            o.data.materials[0] = MAT_H
                            swapped.append(o)
                        continue
                    for o in HOLD[h]:
                        o.hide_render = False
                path = OUT / "raw" / anim / lid
                path.mkdir(parents=True, exist_ok=True)
                scene.render.filepath = str(path / f"f{f}_d{d}.png")
                bpy.ops.render.render(write_still=True)
                for o in swapped:
                    o.data.materials[0] = MAT_W
print("rendu termine", len(layer_ids), "couches")
