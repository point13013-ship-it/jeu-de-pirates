"""Construit un bateau pirate en 3D (style Sea of Thieves) et le rend sous N caps avec la caméra 3/4.

Usage : blender.exe -b --python make_ship.py -- <dossier de sortie ABSOLU> <taille> <nb de caps> <bateau>
Bateaux : sloop (2 places), brigantin (3 places), galion (4 places).
Caméra orthographique inclinée de ELEVATION degrés, fixe ; seul le bateau tourne.
Échelle commune : 10 pixels finaux par unité (taille finale = ortho_scale * 10).
"""
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0] if ARGS else ".").resolve()
SIZE = int(ARGS[1]) if len(ARGS) > 1 else 0
HEADINGS = int(ARGS[2]) if len(ARGS) > 2 else 16
SHIP = ARGS[3] if len(ARGS) > 3 else "galion"
ELEVATION = 52.0
# Refonte (12/11/2026) : coques agrandies (longueur x KL, largeur x KW), objets du pont à leur taille d'origine : le pont
# devient praticable (couloirs d'au moins 0,8 unité = 1,2 m). Les abscisses « d'origine » ci-dessous sont multipliées par KL.
KL, KW, KH = 1.35, 1.4, 1.12   # longueur, largeur, hauteur des mâts
ORTHO = {"sloop": 16.0, "brigantin": 19.2, "galion": 25.6}[SHIP] * KL
rnd = random.Random(5)

# ------------------------------------------------------------------ les trois bateaux
# masts : (x, hauteur, [voiles (z0, z1, largeur, bombement, emblème)])
CFG = {
    "sloop": dict(L=9.6, WID=3.4, DEP=2.6, castle=1, cannons=2, ports=3, bow_castle=False,
                  masts=[(0.5, 7.6, [(2.4, 5.2, 4.4, 1.0, True), (5.5, 7.0, 3.2, 0.6, False)])],
                  jib=True, gaff=None, flag_mast=0, anchor=(2.55, 0.0)),   # (12/11 : avancée, trop de postes au milieu)
    "brigantin": dict(L=12.6, WID=4.3, DEP=3.0, castle=2, cannons=3, ports=4, bow_castle=False,
                      masts=[(3.0, 8.6, [(2.9, 5.9, 5.0, 1.0, False), (6.2, 8.0, 3.8, 0.6, False)]),
                             (-1.2, 9.6, [(3.0, 6.6, 6.0, 1.1, True), (6.9, 9.0, 4.6, 0.7, False)])],
                      jib=True, gaff=(-1.2, 8.0, -6.0), flag_mast=1, anchor=(4.0, 0.0)),
    "galion": dict(L=16.0, WID=5.6, DEP=3.8, castle=3, cannons=5, ports=6, bow_castle=True,
                   masts=[(5.0, 9.6, [(3.2, 6.3, 5.8, 1.1, False), (6.6, 8.6, 4.2, 0.6, False)]),
                          (0.4, 12.0, [(3.4, 7.0, 7.4, 1.3, True), (7.3, 9.9, 5.8, 0.9, False),
                                       (10.2, 11.6, 4.0, 0.5, False)]),
                          (-1.6, 9.0, [(3.0, 6.0, 4.6, 0.9, False)])],
                   jib=True, gaff=(-1.6, 8.4, -7.6), flag_mast=1, anchor=(4.1, 0.0)),
}[SHIP]
# canons (abscisses d'origine, un par bord à chaque abscisse) et échelle de coque : repris des réglages faits à la main
CFG["cannon_x"] = {"sloop": [1.3], "brigantin": [-1.0, 1.72], "galion": [-2.0, -0.5, 1.0]}[SHIP]
# distance du canon (son axe) au bord de la coque : plus près du plat-bord, la bouche sort par-dessus, l'affût mange moins le pont
CANNON_INSET = 0.36
CFG["ladder_x"] ={"sloop": -0.288, "brigantin": 1.197, "galion": 2.52}[SHIP]
CFG["L"] *= KL
CFG["WID"] *= KW
CFG["DEP"] *= 1.15
CFG["masts"] = [(mx * KL, mh * KH, [(z0 * KH, z1 * KH, w * 1.25, b, e) for (z0, z1, w, b, e) in sails])
                for (mx, mh, sails) in CFG["masts"]]
if CFG["gaff"]:
    CFG["gaff"] = (CFG["gaff"][0] * KL, CFG["gaff"][1] * KH, CFG["gaff"][2] * KL)
CFG["anchor"] = (CFG["anchor"][0] * KL, 0.0)
L, WID, DEP = CFG["L"], CFG["WID"], CFG["DEP"]

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
parts: list = []
OBST_BOXES: list = []    # (x0, y0, x1, y1) en mètres du modèle, repère d'origine
OBST_CIRCLES: list = []  # (x, y, rayon)
CABIN: dict = {}
CANNONS: list = []       # (x, y, côté, z) ; côté +1 = bâbord (y positif), -1 = tribord


def make_mat(name, color, rough=0.9, emit=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    if emit > 0:
        bsdf.inputs["Emission Color"].default_value = (*color, 1.0)
        bsdf.inputs["Emission Strength"].default_value = emit
    return m


def hx(h, rough=0.9, emit=0.0, name=None):
    """Une couleur de la palette v1 (design/bible-v2.md), donnée en hexadécimal sRGB, convertie en linéaire pour Blender."""
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    rgb = tuple(lin(int(h[i:i + 2], 16)) for i in (0, 2, 4))
    return make_mat(name or h, rgb, rough, emit)


# Refonte v2 (12/11/2026, design/bible-v2.md, section 3) : le brigantin passe le premier. Les autres bateaux gardent leur
# construction d'origine, mais tous prennent la palette v1.
V2 = SHIP == "brigantin"
SHEER = 2.1 if V2 else 1.0   # tonture exagérée : le pont remonte nettement vers l'étrave et la poupe (lu dans le jeu via la méta)
rnd2 = random.Random(77)

MAT = {
    "hull": make_mat("hull", (0.085, 0.045, 0.045)),
    "hull_l": make_mat("hull_l", (0.20, 0.10, 0.07)),
    "hull_d": make_mat("hull_d", (0.04, 0.028, 0.038)),
    "deck": make_mat("deck", (0.58, 0.37, 0.20)),
    "deck_l": make_mat("deck_l", (0.72, 0.48, 0.28)),
    "gold": make_mat("gold", (0.58, 0.34, 0.07), 0.5),
    "mast": make_mat("mast", (0.17, 0.095, 0.07)),
    "sail": make_mat("sail", (0.78, 0.64, 0.48)),
    "sail_d": make_mat("sail_d", (0.60, 0.48, 0.38)),
    "sail_p": make_mat("sail_p", (0.86, 0.72, 0.52)),
    "sail_e": make_mat("sail_e", (0.78, 0.64, 0.48)),   # la grand-voile, avec l'emblème peint (même teinte que « sail »)
    "red": make_mat("red", (0.42, 0.09, 0.11)),
    "flag": make_mat("flag", (0.022, 0.018, 0.045)),
    "bone": make_mat("bone", (0.90, 0.86, 0.76)),
    "glow": make_mat("glow", (1.0, 0.55, 0.16), 0.5, emit=2.2),   # (12/11 : 7 brûlait en blanc avec le halo de l'écran)
    "dark": make_mat("dark", (0.025, 0.02, 0.035)),
    "iron": make_mat("iron", (0.07, 0.065, 0.09), 0.55),
    "rope": make_mat("rope", (0.06, 0.04, 0.045)),
}


def recolor(mat, h):
    def lin(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    rgb = tuple(lin(int(h[i:i + 2], 16)) for i in (0, 2, 4))
    bsdf = mat.node_tree.nodes["Principled BSDF"]
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    if bsdf.inputs["Emission Strength"].default_value > 0:
        bsdf.inputs["Emission Color"].default_value = (*rgb, 1.0)


# palette v1 (12/11/2026) : mêmes noms de matières (les skins du jeu s'y accrochent), nouvelles couleurs
for _k, _h in {"hull": "3A2630", "hull_l": "6A4532", "hull_d": "2E2A44", "deck": "9C6A43", "deck_l": "CF9C62",
               "gold": "DCAE5C", "mast": "6A4532", "sail": "EFE4CC", "sail_d": "B9AD9C", "sail_p": "F4E1AD",
               "sail_e": "EFE4CC", "red": "B25A3E", "flag": "1C1726", "bone": "EFE4CC", "glow": "FFB35C",
               "dark": "1C1726", "iron": "2E2A44", "rope": "6B4A3F"}.items():
    recolor(MAT[_k], _h)
MAT["deck_n"] = hx("D9B077", name="deck_n")      # planches neuves, plus claires (réparations)
MAT["serpent"] = hx("2D6444", name="serpent")    # figure de proue : serpent de mer
MAT["serpent_l"] = hx("5A9440", name="serpent_l")
for _k in ("sail", "sail_d", "sail_p", "sail_e", "flag", "red"):
    MAT[_k].use_backface_culling = False          # toiles et flammes vues des deux côtés


def add_mesh(name, verts, faces, mats, mat_index=None, uvs=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
    if uvs is not None:   # coordonnées de texture par sommet (voiles : la toile suit la voile, au lieu d'être projetée)
        layer = me.uv_layers.new(name="UVMap")
        for loop in me.loops:
            layer.data[loop.index].uv = uvs[loop.vertex_index]
    me.update()
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    for m in (mats if isinstance(mats, (list, tuple)) else [mats]):
        ob.data.materials.append(MAT[m])
    if mat_index is not None:
        for p, poly in enumerate(me.polygons):
            poly.material_index = mat_index(p)
    parts.append(ob)
    return ob


def strip(name, ring_a, ring_b, mat):
    verts, faces = [], []
    n = len(ring_a)
    for i in range(n):
        verts.append(ring_a[i])
        verts.append(ring_b[i])
    for i in range(n - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    return add_mesh(name, verts, faces, mat)


BEVEL: list = []   # v2 : objets qui reçoivent un biseau fin (boîtes et cylindres)


def box(name, cx, cy, cz, sx, sy, sz, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=(cx, cy, cz), rotation=rot)
    ob = bpy.context.active_object
    ob.scale = (sx / 2, sy / 2, sz / 2)
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    if V2:   # échelle appliquée, pour que le biseau ait la même largeur sur toutes les arêtes
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        BEVEL.append(ob)
    return ob


def cyl(name, x, y, z, r, depth, mat, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=(x, y, z), rotation=rot, vertices=verts)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    BEVEL.append(ob)
    return ob


def sphere(name, x, y, z, r, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=10, ring_count=6)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


def rope(a, b, r=0.08, mat="rope"):
    va, vb = Vector(a), Vector(b)
    mid = (va + vb) / 2
    dvec = vb - va
    ob = cyl("rope", mid.x, mid.y, mid.z, r, dvec.length, mat, verts=5)
    ob.rotation_euler = Vector((0, 0, 1)).rotation_difference(dvec).to_euler()
    return ob


# ------------------------------------------------------------------ coque
N = 64      # sections le long de la coque
RING = 17   # points par section, d'un bord du pont à l'autre en passant par la quille


def station(u):
    x = -L / 2 + u * L
    half = WID / 2 * (0.90 + 0.10 * min(1.0, u * 3.0)) * (1.0 - 0.96 * u ** 2.4)
    deck_z = (0.62 * u ** 2.2 + 0.34 * (1 - u) ** 2.5) * (L / 13.0) * SHEER
    depth = DEP * (1.0 - 0.45 * u ** 2)
    return x, max(half, 0.04), deck_z, depth


def hull_depth_frac(phi):
    """Profondeur relative (0 au bord du pont, 1 à la quille) : flancs presque droits en haut,
    bouchain arrondi, fond en U."""
    return math.sin(phi) ** 0.65


hull_verts = []
for i in range(N):
    x, hw, dz, dp = station(i / (N - 1))
    for k in range(RING):
        phi = math.pi * k / (RING - 1)
        f = hull_depth_frac(phi)
        # v2 : « rentrée de la muraille » : la coque est plus large un peu sous le pont qu'au pont (ventre arrondi)
        tumble = 1.0 + (0.08 * math.sin(math.pi * min(f * 2.4, 1.0)) if V2 else 0.0)
        hull_verts.append((x, -hw * math.cos(phi) * tumble, dz - dp * f))
hull_faces = []
for i in range(N - 1):
    for j in range(RING - 1):
        a = i * RING + j
        b = (i + 1) * RING + j
        hull_faces.append((a, a + 1, b + 1, b))
hull_faces.append(tuple(range(RING)))


def hull_mat(p):
    if p >= (N - 1) * (RING - 1):
        return 1
    i, j = divmod(p, RING - 1)
    f = hull_depth_frac(math.pi * (j + 0.5) / (RING - 1))
    m = 0 if f < 0.28 else (1 if f < 0.75 else 2)   # haut clair, milieu sombre, fond très sombre
    # joints de planches : une section sur cinq plus sombre sur le haut de la coque
    if m == 0 and i % 5 == 0:
        return 1
    return m


add_mesh("hull", hull_verts, hull_faces, ["hull_l", "hull", "hull_d"], hull_mat)

if not V2:
    LANES = 9
    for m in range(LANES):
        f0, f1 = m / LANES, (m + 1) / LANES
        a, b = [], []
        for i in range(N):
            x, hw, dz, dp = station(i / (N - 1))
            a.append((x, (-1 + 2 * f0) * hw * 0.98, dz))
            b.append((x, (-1 + 2 * f1) * hw * 0.98, dz))
        strip("deck", a, b, "deck" if m % 2 == 0 else "deck_l")
else:
    # v2 : un vrai bordé de pont. Des planches dans la longueur (elles donnent la direction du bateau même immobile), de
    # longueurs inégales, en trois teintes (vieilles, claires, quelques neuves), avec un joint sombre entre elles : sous les
    # planches, un fond sombre fait les joints.
    LANES = 22
    a, b = [], []
    for i in range(N):
        x, hw, dz, dp = station(i / (N - 1))
        a.append((x, -hw * 0.985, dz - 0.012))
        b.append((x, hw * 0.985, dz - 0.012))
    strip("deck_gaps", a, b, "hull_d")
    pv, pf, pm = [], [], []   # toutes les planches dans un seul maillage (un seul appel de rendu)
    for m in range(LANES):
        f0, f1 = m / LANES + 0.0035, (m + 1) / LANES - 0.0035
        u = rnd2.uniform(0.0, 0.12)
        while u < 1.0:
            u1 = min(1.0, u + rnd2.uniform(0.11, 0.2))
            k = max(2, int((u1 - u) * N) + 1)
            base = len(pv)
            for q in range(k):
                uu = u + (u1 - u) * q / (k - 1)
                x, hw, dz, dp = station(uu)
                x = x + (0.012 if q == 0 else (-0.012 if q == k - 1 else 0.0))   # joint en bout de planche
                pv.append((x, (-1 + 2 * f0) * hw * 0.985, dz))
                pv.append((x, (-1 + 2 * f1) * hw * 0.985, dz))
            r = rnd2.random()
            mi = 2 if r < 0.08 else (1 if r < 0.42 else 0)
            for q in range(k - 1):
                pf.append((base + 2 * q, base + 2 * q + 1, base + 2 * q + 3, base + 2 * q + 2))
                pm.append(mi)
            u = u1
    add_mesh("deck", pv, pf, ["deck", "deck_l", "deck_n"], lambda p: pm[p])

for side in (-1, 1):
    ob_, ot_, it_, ib_ = [], [], [], []
    for i in range(N):
        x, hw, dz, dp = station(i / (N - 1))
        y = side * hw
        yi = side * max(hw - 0.14, 0.02)
        ob_.append((x, y, dz))
        ot_.append((x, y, dz + 0.5))
        it_.append((x, yi, dz + 0.5))
        ib_.append((x, yi, dz))
    strip("rail_out", ob_, ot_, "hull_l")
    strip("rail_cap", ot_, it_, "hull")
    strip("rail_in", it_, ib_, "hull")
    for off0, off1, mat in ((0.08, 0.28, "gold"), (0.34, 0.60, "red")):
        a, b = [], []
        for i in range(N):
            x, hw, dz, dp = station(i / (N - 1))
            a.append((x, side * hw * 1.005, dz - off0))
            b.append((x, side * hw * 1.005, dz - off1))
        strip("band", a, b, mat)

# sabords et canons
for side in (-1, 1):
    for k in range(CFG["ports"]):
        u = 0.18 + k * (0.55 / max(1, CFG["ports"] - 1))
        x, hw, dz, dp = station(u)
        s = 0.30
        y = side * hw * 1.012
        add_mesh("port", [(x - s, y, dz - 0.52), (x + s, y, dz - 0.52), (x + s, y, dz - 0.86), (x - s, y, dz - 0.86)],
                 [(0, 1, 2, 3)], "dark")
    for cx_o in CFG["cannon_x"]:
        u = (cx_o * KL + L / 2) / L
        x, hw, dz, dp = station(u)
        CANNONS.append((x, side * (hw - CANNON_INSET), side, dz + 0.34))
        cyl("cannon", x, side * (hw - 0.5), dz + 0.34, 0.18, 1.0, "iron", rot=(math.radians(90), 0, 0))
        cyl("cannon_end", x, side * (hw - 0.05), dz + 0.34, 0.22, 0.2, "iron", rot=(math.radians(90), 0, 0))

# échelles de coque (une par bord, entre les deux derniers canons) : on monte à bord depuis le quai
LADDERS: list = []   # (x, y de la position du pirate sur le pont, côté, y de la coque)
_ul = (CFG["ladder_x"] * KL + L / 2) / L
for side in (-1, 1):
    xl, hwl, dzl, _dp = station(_ul)
    LADDERS.append((xl, side * (hwl - 0.65), side, side * hwl))
    z_top, z_bot = dzl + 0.62, dzl - 3.3   # (12/11 : elle descend jusque dans l'eau : on s'y accroche en nageant)
    for dxr in (-0.27, 0.27):
        # les montants suivent la coque (légèrement vers l'intérieur en bas) et dépassent le plat-bord
        rope((xl + dxr, side * (hwl + 0.06), z_top), (xl + dxr, side * (hwl * 0.88 + 0.04), z_bot), r=0.035, mat="mast")
    k = 0
    zr = z_top - 0.25
    while zr > z_bot + 0.1:
        f = (z_top - zr) / (z_top - z_bot)
        yr = side * (hwl + 0.06 - f * (hwl * 0.12 + 0.02))
        box("ladder_rung", xl, yr, zr, 0.6, 0.06, 0.06, "mast")
        zr -= 0.32
    for dxr in (-0.27, 0.27):   # poignées au-dessus du plat-bord
        cyl("ladder_post", xl + dxr, side * (hwl - 0.08), dzl + 0.72, 0.04, 0.5, "mast")
    box("ladder_grab", xl, side * (hwl - 0.08), dzl + 0.95, 0.6, 0.05, 0.05, "mast")

# château arrière : la cabine du rez-de-chaussée est creuse (on y entre par une porte), les
# niveaux au-dessus sont pleins. Les objets nommés « cut_* » sont masqués par le jeu quand le
# joueur est à l'intérieur (toit, murs tournés vers la caméra) ; « int_* » est le mobilier.
x_s, hw_s, dz_s, _ = station(0.10)
cw = hw_s * 2
c = CFG["castle"]
# la cabine est collée à l'arrière du bateau (sa face arrière à ~0,4 de la poupe) : tout le pont devant elle est libre
ln0 = 2.2 + c * 0.5
# 12/11 : la cabine est collée à la poupe (sa face arrière contre le plat-bord) ; il restait un bout de pont vide derrière elle
cx0 = -L / 2 + 0.2 + ln0 / 2 + 0.15
wid0 = cw * 0.86
H0 = 1.75
T = 0.16
cabin_cx = cx0 - 0.15
ex = cabin_cx + ln0 / 2   # face avant, avec la porte
wx = cabin_cx - ln0 / 2   # face arrière
ny = wid0 / 2
DOOR = (0.25, 1.20)       # ouverture de la porte, en y
fz = dz_s                 # hauteur du plancher de la cabine


def wall(name, x0, y0, x1, y1, mat="hull_l", z0=None, z1=None, solid=True):
    z0 = fz if z0 is None else z0
    z1 = fz + H0 if z1 is None else z1
    box(name, (x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2, x1 - x0, y1 - y0, z1 - z0, mat)
    if solid:
        OBST_BOXES.append((x0, y0, x1, y1))


wall("cut_wall_w", wx, -ny, wx + T, ny)
wall("cut_wall_n", wx, ny - T, ex, ny)
wall("cut_wall_s", wx, -ny, ex, -ny + T)
wall("cut_wall_e1", ex - T, -ny, ex, DOOR[0])
wall("cut_wall_e2", ex - T, DOOR[1], ex, ny)
wall("cut_wall_e_top", ex - T, DOOR[0], ex, DOOR[1], z0=fz + 1.45, solid=False)
box("cut_ceiling", cabin_cx, 0, fz + H0 + 0.07, ln0 + 0.2, wid0 + 0.2, 0.14, "hull")
box("cut_trim", cabin_cx, 0, fz + H0 + 0.16, ln0 + 0.3, wid0 + 0.3, 0.06, "gold")
def window(name, x, y, z, across_x, w=0.5, h=0.44):
    """Fenêtre de cabine (12/11 : avant, un simple pavé lumineux qui « brûlait » à l'écran) : vitre ambrée en retrait, cadre
    de bois sombre, croisillon en quatre carreaux, appui. `across_x` : la fenêtre est sur un mur perpendiculaire à x."""
    def b(n, cx, cy, cz, sw, sh, depth, mat):
        if across_x:
            box(n, cx, cy, cz, depth, sw, sh, mat)
        else:
            box(n, cx, cy, cz, sw, depth, sh, mat)
    out = -0.012 if across_x else 0.0
    b(name, x, y, z, w - 0.06, h - 0.06, 0.05, "glow")                                     # la vitre éclairée
    f = 0.055
    for s in (-1, 1):
        if across_x:
            b(name + "_frame", x + out, y + s * (w / 2 - f / 2), z, f, h, 0.09, "mast")       # montants
        else:
            b(name + "_frame", x + s * (w / 2 - f / 2), y, z, f, h, 0.09, "mast")
        b(name + "_frame", x + out, y, z + s * (h / 2 - f / 2), w, f, 0.09, "mast")          # traverses haut et bas
    b(name + "_frame", x + out, y, z, w, 0.03, 0.08, "mast")                                 # croisillon horizontal
    if across_x:
        b(name + "_frame", x + out, y, z, 0.03, h, 0.08, "mast")
    else:
        box(name + "_frame", x, y, z, 0.03, 0.08, h, "mast")                                 # croisillon vertical
    b(name + "_sill", x + out, y, z - h / 2 - 0.03, w + 0.12, 0.05, 0.12, "hull_l")         # appui


# fenêtres éclairées sur les murs extérieurs
_nw = 3 if V2 else 2   # v2 : trois fenêtres à l'arrière de la cabine (la poupe, vue de derrière, est la façade du bateau)
for k in range(_nw):
    window("cut_win_w", wx - 0.02, (k - (_nw - 1) / 2) * (wid0 * (0.3 if V2 else 0.5)), fz + 1.0, True, w=0.44 if V2 else 0.5)
for sgn, tag in ((-1, "s"), (1, "n")):
    window("cut_win_" + tag, cabin_cx - 0.3, sgn * (ny + 0.02), fz + 1.0, False)
# mobilier : couchette, coffre, table, tapis, lanterne suspendue
box("int_rug", cabin_cx + 0.3, 0, fz + 0.02, ln0 * 0.55, wid0 * 0.45, 0.03, "red")
box("int_bunk", wx + T + 0.85, ny - T - 0.45, fz + 0.22, 1.5, 0.78, 0.44, "deck_l")
box("int_blanket", wx + T + 1.05, ny - T - 0.45, fz + 0.5, 1.1, 0.78, 0.12, "red")
box("int_pillow", wx + T + 0.28, ny - T - 0.45, fz + 0.52, 0.34, 0.5, 0.14, "bone")
OBST_BOXES.append((wx + T, ny - T - 0.84, wx + T + 1.6, ny - T))
box("int_chest", wx + T + 0.4, -ny + T + 0.32, fz + 0.22, 0.7, 0.46, 0.44, "hull")
box("int_chest_band", wx + T + 0.4, -ny + T + 0.32, fz + 0.30, 0.74, 0.1, 0.1, "gold")
OBST_BOXES.append((wx + T, -ny + T, wx + T + 0.78, -ny + T + 0.58))
box("int_table", cabin_cx + 0.35, 0, fz + 0.62, 0.95, 0.7, 0.07, "deck_l")
cyl("int_table_leg", cabin_cx + 0.35, 0, fz + 0.3, 0.08, 0.6, "mast")
OBST_BOXES.append((cabin_cx + 0.35 - 0.5, -0.38, cabin_cx + 0.35 + 0.5, 0.38))
if not V2:
    box("int_lamp", cabin_cx + 0.35, 0, fz + H0 - 0.45, 0.22, 0.22, 0.28, "glow")
else:
    # passe 2 : la cabine du capitaine meublée (12/11 : avant, une lampe-cube qui éblouissait, un tapis uni, des boîtes)
    lx_ = cabin_cx + 0.35
    lz_ = fz + H0 - 0.5
    cyl("int_lamp_chain", lx_, 0, lz_ + 0.3, 0.015, 0.4, "iron", verts=4)
    cyl("int_lamp_cap", lx_, 0, lz_ + 0.15, 0.13, 0.06, "iron", verts=8)
    cyl("int_lamp_base", lx_, 0, lz_ - 0.15, 0.11, 0.05, "iron", verts=8)
    for q in range(4):
        a = q * math.pi / 2 + math.pi / 4
        cyl("int_lamp_bar", lx_ + 0.09 * math.cos(a), 0.09 * math.sin(a), lz_, 0.012, 0.28, "iron", verts=4)
    cyl("int_lamp", lx_, 0, lz_, 0.055, 0.14, "glow", verts=8)
    # bordure dorée et motif du tapis
    rx0, rx1 = cabin_cx + 0.3 - ln0 * 0.275, cabin_cx + 0.3 + ln0 * 0.275
    ry = wid0 * 0.225
    for sy in (-1, 1):
        box("int_rug_edge", cabin_cx + 0.3, sy * (ry - 0.05), fz + 0.035, ln0 * 0.55, 0.08, 0.02, "gold")
    for sx in (rx0 + 0.05, rx1 - 0.05):
        box("int_rug_edge", sx, 0, fz + 0.035, 0.08, wid0 * 0.45, 0.02, "gold")
    # sur la table : une carte déroulée, un compas, une bougie, une chope
    tz = fz + 0.66
    box("int_map", lx_ - 0.05, 0.02, tz, 0.62, 0.46, 0.012, "bone", rot=(0, 0, math.radians(8)))
    box("int_map_ink", lx_ - 0.1, 0.06, tz + 0.008, 0.18, 0.12, 0.006, "red", rot=(0, 0, math.radians(8)))
    cyl("int_candle", lx_ + 0.34, -0.22, tz + 0.08, 0.035, 0.14, "bone", verts=6)
    cyl("int_candle_flame", lx_ + 0.34, -0.22, tz + 0.18, 0.02, 0.05, "glow", verts=4)
    cyl("int_mug", lx_ + 0.3, 0.24, tz + 0.06, 0.05, 0.11, "deck_l", verts=8)
    # deux chaises de part et d'autre de la table
    for sy in (-1, 1):
        cy_ = sy * 0.62
        box("int_chair_seat", lx_, cy_, fz + 0.42, 0.4, 0.38, 0.06, "deck")
        box("int_chair_back", lx_, cy_ + sy * 0.18, fz + 0.72, 0.4, 0.05, 0.55, "deck")
        for dx in (-0.16, 0.16):
            for dy in (-0.15, 0.15):
                box("int_chair_leg", lx_ + dx, cy_ + dy, fz + 0.2, 0.05, 0.05, 0.4, "mast")
        OBST_BOXES.append((lx_ - 0.22, cy_ - 0.21, lx_ + 0.22, cy_ + 0.21))
    # cadre et montants du lit, étagère à livres contre le mur nord, coffre aux cartes roulées
    bx_, by_ = wx + T + 0.85, ny - T - 0.45
    for dx in (-0.74, 0.74):
        box("int_bunk_post", bx_ + dx, by_ - 0.36, fz + 0.4, 0.07, 0.07, 0.8, "mast")
    box("int_bunk_board", bx_, by_ - 0.38, fz + 0.5, 1.5, 0.04, 0.12, "mast")
    sx0 = cabin_cx + 0.55
    box("int_shelf", sx0, ny - T - 0.14, fz + 1.05, 0.9, 0.24, 1.3, "hull_l")
    for k2 in range(3):
        zz = fz + 0.55 + k2 * 0.42
        box("int_shelf_board", sx0, ny - T - 0.14, zz, 0.86, 0.22, 0.03, "mast")
        xb = sx0 - 0.38
        while xb < sx0 + 0.36:
            wbk = rnd2.uniform(0.05, 0.09)
            box("int_book", xb + wbk / 2, ny - T - 0.16, zz + 0.15, wbk, 0.16, rnd2.uniform(0.2, 0.3),
                rnd2.choice(["red", "serpent", "hull_d", "deck_l", "gold"]))
            xb += wbk + 0.01
    OBST_BOXES.append((sx0 - 0.47, ny - T - 0.28, sx0 + 0.47, ny - T))
    box("int_scroll_box", wx + T + 0.4, -ny + T + 0.85, fz + 0.18, 0.5, 0.36, 0.36, "deck")
    for k2 in range(4):
        cyl("int_scroll", wx + T + 0.4 + (k2 - 1.5) * 0.1, -ny + T + 0.85, fz + 0.42, 0.04, 0.32, "bone",
            rot=(math.radians(90), 0, math.radians(10 * k2)), verts=6)
    OBST_BOXES.append((wx + T + 0.13, -ny + T + 0.65, wx + T + 0.67, -ny + T + 1.05))
CABIN.update(dict(x0=wx + T, x1=ex - T, y0=-ny + T, y1=ny - T, door_y0=DOOR[0], door_y1=DOOR[1],
                  door_x=ex, floor_z=fz, light=[cabin_cx + 0.35, fz + H0 - 0.45, 0.0]))

top = fz + H0 + 0.2
for lvl in range(1, c):
    ln = 2.2 + (c - lvl) * 0.5
    wd = cw * (0.86 - lvl * 0.07)
    h = 1.05
    box(f"cut_up{lvl}", cabin_cx, 0, top + h / 2, ln, wd, h, "hull_l" if lvl % 2 == 0 else "hull")
    box(f"cut_up_trim{lvl}", cabin_cx, 0, top + h, ln + 0.2, wd + 0.2, 0.12, "gold")
    face = cabin_cx - ln / 2 - 0.02
    for k in range(2 + (c >= 3)):
        yy = (k - (1 + (c >= 3)) / 2) * (cw * 0.7 / (2 + (c >= 3)))
        window("cut_up_win", face, yy, top + h / 2, True)
    for sgn in (-1, 1):
        window("cut_up_win", cabin_cx, sgn * (wd / 2 + 0.02), top + h / 2, False)
    top += h + 0.12
roof_len = (2.4 + 0.5) if c > 1 else ln0 + 0.5
roof_wid = cw * 0.78 if c > 1 else wid0 + 0.3
box("cut_roof", cabin_cx, 0, top + 0.1, roof_len, roof_wid, 0.22, "red")
cyl("cut_lamp_post", wx + 0.3, 0, top + 0.5, 0.07, 1.0, "dark")
# la lanterne de poupe (12/11 : avant, un cube lumineux) : socle et chapeau de fer, quatre montants, flamme ambrée au milieu
_lz = top + 1.15
cyl("cut_lamp_base", wx + 0.3, 0, _lz - 0.2, 0.17, 0.06, "iron", verts=8)
cyl("cut_lamp_cap", wx + 0.3, 0, _lz + 0.2, 0.19, 0.07, "iron", verts=8)
cyl("cut_lamp_top", wx + 0.3, 0, _lz + 0.29, 0.07, 0.12, "iron", verts=8)
for q in range(4):
    a = q * math.pi / 2 + math.pi / 4
    cyl("cut_lamp_bar", wx + 0.3 + 0.13 * math.cos(a), 0.13 * math.sin(a), _lz, 0.018, 0.38, "iron", verts=5)
cyl("cut_lamp", wx + 0.3, 0, _lz, 0.1, 0.24, "glow", verts=10)
# barre à roue : dans l'axe, devant la cabine (le barreur se tient derrière, face à l'étrave) ; la roue regarde vers l'avant.
# L'obstacle est la colonne (le bas de la roue passe au-dessus des hanches), pas tout le disque.
HELM = (ex + 1.5, 0.0)
_hz = station((HELM[0] + L / 2) / L)[2]
# (12/11) centre de la roue à hauteur de poitrine du pirate (~1,25 m), plus 2 m : elle le dominait
HELM_Z = 0.84
cyl("helm", HELM[0], HELM[1], _hz + HELM_Z, 0.5, 0.1, "mast", rot=(0, math.radians(90), 0), verts=14)
cyl("helm_post", HELM[0] - 0.06, HELM[1], _hz + HELM_Z / 2, 0.1, HELM_Z, "mast")
OBST_CIRCLES.append((HELM[0], HELM[1], 0.24))

if CFG["bow_castle"]:
    xb, hwb, dzb, _ = station(0.88)
    OBST_BOXES.append((xb - 1.1, -hwb * 0.92, xb + 1.1, hwb * 0.92))
    box("fore_castle", xb, 0, dzb + 0.55, 2.2, hwb * 2 * 0.92, 1.1, "hull_l")
    box("fore_castle_trim", xb, 0, dzb + 1.12, 2.3, hwb * 2 * 0.94, 0.10, "gold")
    box("fore_castle_top", xb, 0, dzb + 1.2, 2.0, hwb * 2 * 0.78, 0.14, "deck")

# détails de pont : écoutille (sauf sloop), tonneau de boulets, caisses, cabestan d'ancre
_hx = (1.6 if SHIP != "sloop" else 1.2) * KL
if SHIP != "sloop":
    # l'écoutille est basse (28 cm) : on marche dessus, elle n'est pas un obstacle
    _hdz = station((_hx + L / 2) / L)[2]
    box("hatch", _hx, 0, _hdz + 0.14, 1.2, 1.2, 0.28, "hull_l")
    box("hatch_grate", _hx, 0, _hdz + 0.30, 1.0, 1.0, 0.05, "dark")
    if V2:   # le caillebotis : une grille de lattes croisées sur le trou sombre (le motif qui fait « navire »)
        for q in range(5):
            o = -0.4 + q * 0.2
            box("hatch_slat", _hx + o, 0, _hdz + 0.33, 0.07, 1.0, 0.04, "deck_l")
            box("hatch_slat", _hx, o, _hdz + 0.35, 1.0, 0.07, 0.04, "deck")
# tonneau de boulets et pile de caisses : rangés contre le plat-bord, de part et d'autre de la barre, hors des couloirs
_bx = HELM[0] + 0.2
_bxs = station((_bx + L / 2) / L)
_by = _bxs[1] - 0.14 - 0.36
_bdz = _bxs[2]
# 12/11 : un vrai coffre à boulets (avant : un gros tonneau avec trois boulets posés dessus), plus petit : caisse de bois
# cerclée de fer, couvercle, poignées, et une pyramide de boulets sur le couvercle
OBST_BOXES.append((_bx - 0.36, _by - 0.27, _bx + 0.36, _by + 0.27))
box("ammo_chest", _bx, _by, _bdz + 0.2, 0.66, 0.48, 0.4, "hull_l")
box("ammo_lid", _bx, _by, _bdz + 0.44, 0.7, 0.52, 0.1, "hull")
for dx in (-0.22, 0.22):
    box("ammo_band", _bx + dx, _by, _bdz + 0.25, 0.06, 0.5, 0.42, "iron")
for sy in (-1, 1):
    box("ammo_handle", _bx, _by + sy * 0.26, _bdz + 0.3, 0.2, 0.04, 0.05, "iron")
for k, (dx, dy, dz) in enumerate([(-0.13, -0.09, 0), (0.13, -0.09, 0), (-0.13, 0.11, 0), (0.13, 0.11, 0), (0.0, 0.01, 0.15)]):
    sphere("ball", _bx + dx, _by + dy, _bdz + 0.6 + dz, 0.105, "iron")
_cx = HELM[0] + 0.2
_cy = -(_bxs[1] - 0.14 - 0.42)
OBST_BOXES.append((_cx - 0.36, _cy - 0.34, _cx + 0.36, _cy + 0.34))
ANCHOR = CFG["anchor"]
_adz = station((ANCHOR[0] + L / 2) / L)[2]
cyl("anchor_capstan", ANCHOR[0], ANCHOR[1], _adz + 0.45, 0.26, 0.7, "iron")
cyl("anchor_capstan_top", ANCHOR[0], ANCHOR[1], _adz + 0.84, 0.34, 0.08, "gold")
cyl("anchor_spoke", ANCHOR[0], ANCHOR[1], _adz + 0.8, 0.05, 0.9, "mast", rot=(math.radians(90), 0, 0), verts=5)
OBST_CIRCLES.append((ANCHOR[0], ANCHOR[1], 0.3))
# la caisse à planches (12/11 : elle ne donne que des planches) : une caisse ouverte, des planches qui dépassent par-dessus
box("crate", _cx, _cy, _bdz + 0.32, 0.7, 0.65, 0.64, "deck_l")
for k in range(3):
    box("crate_plank", _cx + 0.12, _cy - 0.2 + k * 0.2, _bdz + 0.7 + k * 0.05, 1.05, 0.16, 0.05, "deck" if k % 2 else "hull_l",
        rot=(0, math.radians(-8 + 6 * k), math.radians(4 * (k - 1))))

if V2:
    # vie à bord : cordages lovés au pied des mâts (bas, on marche dessus), seau, et coulures sombres sous les dalots
    for (mx_, mh_, _sl) in CFG["masts"]:
        _cz = station((mx_ + L / 2) / L)[2]
        for sgn in (-1, 1):
            bpy.ops.mesh.primitive_torus_add(location=(mx_ - 0.45, sgn * 0.5, _cz + 0.04), major_radius=0.2, minor_radius=0.05,
                                             major_segments=12, minor_segments=5)
            ob = bpy.context.active_object
            ob.name = "coil"
            ob.data.materials.append(MAT["rope"])
            parts.append(ob)
    for side in (-1, 1):
        for k in range(CFG["ports"]):
            u = 0.18 + k * (0.55 / max(1, CFG["ports"] - 1)) + 0.04
            x, hw, dz, dp = station(u)
            box("drip", x, side * hw * 1.02, dz - 0.5, 0.06, 0.02, 0.5, "hull_d")



# tableau arrière (12/11) : la face plate de la poupe, sous la cabine, était un grand aplat sombre qui ressemblait à un vide
# derrière la cabine. Elle est maintenant habillée comme sur les vrais navires : bordage clair, frise dorée et rouge, deux
# fenêtres de galerie, et le gouvernail.
x_t, hw_t, dz_t, dp_t = station(0.0)
xt = x_t - 0.035
box("stern_panel", xt, 0, dz_t - 0.42, 0.06, hw_t * 2 * 0.94, 0.84, "hull_l")
box("stern_band_g", xt - 0.01, 0, dz_t - 0.1, 0.06, hw_t * 2 * 0.96, 0.12, "gold")
box("stern_band_r", xt - 0.01, 0, dz_t - 0.92, 0.06, hw_t * 2 * 0.86, 0.14, "red")
if not V2:
    for sy in (-1, 1):
        window("stern_win", xt - 0.03, sy * hw_t * 0.42, dz_t - 0.5, True, w=0.42, h=0.34)
if V2:
    # passe 2 : la poupe, vue de derrière, devient la façade du bateau. Une rangée de quatre fenêtres sur le tableau, une galerie
    # en balcon (plancher, balustres dorés, main courante) sous les fenêtres de la cabine, des galeries de flanc aux deux angles,
    # et un couronnement doré qui dépasse du toit, avec les deux lanternes de poupe.
    for k in range(4):
        window("stern_win", xt - 0.03, (k - 1.5) * hw_t * 0.42, dz_t - 0.52, True, w=0.36, h=0.32)
    gx = xt - 0.32                         # le balcon dépasse de 30 cm derrière le tableau
    gz = fz + 0.12                         # son plancher : un peu au-dessus de celui de la cabine
    gw = hw_t * 2 * 0.86
    box("gallery_floor", gx + 0.02, 0, gz, 0.62, gw, 0.08, "hull_l")
    box("gallery_sole", gx - 0.02, 0, gz - 0.1, 0.54, gw * 0.96, 0.12, "red")
    for q in range(9):                     # consoles sous le balcon
        box("gallery_bracket", gx + 0.05, (q - 4) * gw / 8.4, gz - 0.24, 0.42, 0.06, 0.2, "hull", rot=(0, math.radians(-28), 0))
    nb = 13
    for q in range(nb):                    # balustres
        cyl("gallery_baluster", gx - 0.22, (q - (nb - 1) / 2) * gw / (nb - 0.5), gz + 0.25, 0.028, 0.42, "gold", verts=6)
    box("gallery_rail", gx - 0.22, 0, gz + 0.48, 0.08, gw + 0.06, 0.06, "gold")
    for sy in (-1, 1):
        box("gallery_end", gx - 0.02, sy * (gw / 2 + 0.02), gz + 0.26, 0.5, 0.06, 0.5, "hull_l")
        # galerie de flanc (« bouteille ») : une petite loge vitrée en encorbellement sur l'angle de la poupe
        qx = x_t + 0.55
        qy = sy * (station(0.05)[1] + 0.12)
        box("quarter_gallery", qx, qy, fz + 0.75, 0.9, 0.26, 0.95, "hull_l")
        box("quarter_gallery_cap", qx, qy, fz + 1.27, 1.0, 0.34, 0.1, "gold")
        box("quarter_gallery_base", qx, qy * 0.99, fz + 0.24, 0.8, 0.22, 0.14, "red")
        window("quarter_win", qx, qy + sy * 0.14, fz + 0.78, False, w=0.4, h=0.4)
    # couronnement : un fronton doré en arc derrière le toit de la cabine, qui fait monter la poupe
    # (posé sur l'arrière du toit ; nommé « cut_ » : masqué quand on est dans la cabine, comme le toit)
    crown_z = top + 0.15
    crx = cabin_cx - roof_len / 2 + 0.07
    cw_ = roof_wid * 0.96
    nseg = 9
    for q in range(nseg):
        t = (q + 0.5) / nseg
        yy = (t - 0.5) * cw_
        hh = 0.3 + 0.5 * math.sin(math.pi * t)
        box("cut_crown", crx, yy, crown_z + hh / 2, 0.1, cw_ / nseg + 0.01, hh, "hull_l")
        box("cut_crown_trim", crx - 0.02, yy, crown_z + hh + 0.03, 0.12, cw_ / nseg + 0.03, 0.07, "gold")
    sphere("cut_crown_boss", crx - 0.08, 0, crown_z + 0.5, 0.16, "gold")
    for sy in (-1, 1):   # deux lanternes d'angle sur le couronnement (la poupe éclairée se voit de loin la nuit)
        lx, ly, lz = crx - 0.03, sy * cw_ * 0.5, crown_z + 0.62
        cyl("stern_lantern_post", lx, ly, lz - 0.35, 0.04, 0.5, "iron", verts=6)
        box("stern_lantern_frame", lx, ly, lz, 0.22, 0.22, 0.32, "iron")
        box("stern_lantern", lx, ly, lz, 0.24, 0.15, 0.22, "glow")
        box("stern_lantern_cap", lx, ly, lz + 0.2, 0.28, 0.28, 0.06, "iron")
box("rudder", x_t - 0.12, 0, dz_t - 0.95 - dp_t * 0.35, 0.14, 0.12, dp_t * 0.7 + 0.5, "mast")
box("rudder_blade", x_t - 0.32, 0, dz_t - 1.2 - dp_t * 0.4, 0.4, 0.1, dp_t * 0.6, "mast")

# figure de proue : tête de mort ; beaupré
x_b, hw_b, dz_b, _ = station(1.0)


def tube(name, pts, radii, mat, sides=8):
    """Un tube qui suit une suite de points, d'épaisseur variable (cordage courbe, corps de serpent)."""
    verts, faces = [], []
    n = len(pts)
    for i, (p, r) in enumerate(zip(pts, radii)):
        pv = Vector(p)
        t = (Vector(pts[min(i + 1, n - 1)]) - Vector(pts[max(i - 1, 0)])).normalized()
        a = t.cross(Vector((0, 1, 0)))
        if a.length < 1e-4:
            a = t.cross(Vector((1, 0, 0)))
        a.normalize()
        b = t.cross(a).normalized()
        for s in range(sides):
            ang = 2 * math.pi * s / sides
            verts.append(tuple(pv + (a * math.cos(ang) + b * math.sin(ang)) * r))
    for i in range(n - 1):
        for s in range(sides):
            s2 = (s + 1) % sides
            faces.append((i * sides + s, i * sides + s2, (i + 1) * sides + s2, (i + 1) * sides + s))
    return add_mesh(name, verts, faces, mat)


if not V2:
    sphere("skull", x_b + 0.45, 0, dz_b + 0.55, 0.30, "bone")
    box("jaw", x_b + 0.58, 0, dz_b + 0.30, 0.2, 0.28, 0.14, "bone")
    for sgn in (-1, 1):
        box("eye", x_b + 0.7, sgn * 0.11, dz_b + 0.62, 0.06, 0.1, 0.1, "dark")
else:
    # v2 : la figure de proue est un serpent de mer (choix de Jimmy) : un corps en S qui sort de l'étrave, s'élance au-dessus
    # de l'eau et dresse la tête vers l'avant ; crête dorée, ventre clair. Nommé « skull » (et « jaw », « eye ») pour que les
    # proues du chantier naval le remplacent comme avant.
    sp = []
    rad = []
    # (taille : il doit dépasser nettement de la silhouette, c'est l'identité du bateau ; sous le beaupré)
    for i in range(18):
        t = i / 17
        sp.append((x_b - 0.5 + 2.5 * t, 0.16 * math.sin(t * math.pi * 2), dz_b - 1.15 + 1.5 * t + 0.45 * math.sin(t * math.pi * 1.7)))
        rad.append(0.32 - 0.16 * t)
    tube("skull", sp, rad, "serpent", 10)
    hx_, hy_, hz_ = sp[-1]
    sphere("jaw", hx_ + 0.3, hy_, hz_ + 0.03, 0.27, "serpent")          # la tête
    box("eye_snout", hx_ + 0.62, hy_, hz_ - 0.04, 0.46, 0.3, 0.2, "serpent_l")   # le museau
    for sgn in (-1, 1):
        box("eye", hx_ + 0.42, hy_ + sgn * 0.19, hz_ + 0.14, 0.1, 0.07, 0.1, "glow")
        box("eye_fin", hx_ + 0.08, hy_ + sgn * 0.24, hz_ + 0.22, 0.34, 0.04, 0.2, "gold", rot=(math.radians(sgn * 25), 0, 0))
    for i in range(3, 16, 2):   # crête dorée le long du dos
        px, py, pz = sp[i]
        box("eye_crest", px, py, pz + rad[i] + 0.09, 0.16, 0.04, 0.24, "gold", rot=(0, math.radians(-20), 0))
cyl("bowsprit", x_b + 1.7, 0, dz_b + 0.9, 0.14, 4.2 * (L / 13.0) ** 0.5, "mast", rot=(0, math.radians(75), 0))

if V2:
    def deck_z(x):
        return station((x + L / 2) / L)[2]

    # passe 2, la vie à bord. Le tonneau de grog, contre le plat-bord bâbord entre le canon et l'échelle : un fût renflé (tube),
    # trois cercles de fer, un robinet, une chope posée dessus
    gx_, gy_ = 0.25, station((0.25 + L / 2) / L)[1] - 0.52
    gz_ = deck_z(gx_)
    prof = [(0.0, 0.27), (0.12, 0.31), (0.38, 0.34), (0.64, 0.31), (0.76, 0.27)]
    tube("barrel_grog", [(gx_, gy_, gz_ + z) for z, _r in prof], [r for _z, r in prof], "hull_l", 12)
    cyl("barrel_grog_top", gx_, gy_, gz_ + 0.76, 0.27, 0.03, "deck", verts=12)
    for z, r in ((0.1, 0.305), (0.38, 0.345), (0.66, 0.305)):
        cyl("barrel_grog_hoop", gx_, gy_, gz_ + z, r + 0.012, 0.05, "iron", verts=12)
    cyl("barrel_grog_tap", gx_ - 0.33, gy_, gz_ + 0.22, 0.03, 0.14, "gold", rot=(0, math.radians(90), 0), verts=6)
    cyl("barrel_grog_mug", gx_ + 0.08, gy_ - 0.06, gz_ + 0.84, 0.07, 0.14, "deck_l", verts=8)
    cyl("barrel_grog_stool", gx_ - 0.62, gy_ + 0.05, gz_ + 0.2, 0.17, 0.4, "hull", verts=8)
    OBST_CIRCLES.append((gx_, gy_, 0.36))
    # les caisses sous filet, côté tribord, au même niveau : deux caisses, une troisième par-dessus, un filet de cordage
    cx_, cy_ = 0.35, -(station((0.35 + L / 2) / L)[1] - 0.5)
    cz_ = deck_z(cx_)
    box("cargo_crate", cx_ - 0.22, cy_, cz_ + 0.27, 0.55, 0.55, 0.54, "deck_l", rot=(0, 0, math.radians(4)))
    box("cargo_crate", cx_ + 0.36, cy_ + 0.02, cz_ + 0.23, 0.5, 0.5, 0.46, "deck", rot=(0, 0, math.radians(-7)))
    box("cargo_crate", cx_ + 0.05, cy_ - 0.02, cz_ + 0.75, 0.5, 0.46, 0.42, "deck_n", rot=(0, 0, math.radians(10)))
    for q in range(4):   # le filet : des cordages croisés par-dessus, attachés au pont
        f = -0.45 + q * 0.3
        rope((cx_ + f, cy_ - 0.32, cz_ + 0.02), (cx_ + f + 0.2, cy_ + 0.32, cz_ + 0.02), r=0.018)
        rope((cx_ + f, cy_ - 0.3, cz_ + 0.5), (cx_ + f + 0.1, cy_ + 0.3, cz_ + 0.98), r=0.018)
        rope((cx_ + f + 0.1, cy_ + 0.3, cz_ + 0.98), (cx_ + f + 0.2, cy_ + 0.3, cz_ + 0.02), r=0.018)
    rope((cx_ - 0.55, cy_ - 0.3, cz_ + 0.62), (cx_ + 0.65, cy_ - 0.3, cz_ + 0.62), r=0.02)
    OBST_BOXES.append((cx_ - 0.55, cy_ - 0.34, cx_ + 0.66, cy_ + 0.34))
    # une mouette posée sur le couronnement de la poupe (corps en ovale, ailes grises repliées, bec jaune)
    if True:
        mx_, my_, mz_ = crx + 0.02, roof_wid * 0.22, top + 0.15 + 0.3 + 0.5 * math.sin(math.pi * 0.72) + 0.12
        bpy.ops.mesh.primitive_uv_sphere_add(radius=0.12, location=(mx_, my_, mz_ + 0.06), segments=10, ring_count=6)
        ob = bpy.context.active_object
        ob.name = "gull"
        ob.scale = (1.0, 0.75, 0.75)
        ob.data.materials.append(MAT["bone"])
        parts.append(ob)
        sphere("gull_head", mx_ + 0.12, my_, mz_ + 0.14, 0.065, "bone")
        box("gull_beak", mx_ + 0.2, my_, mz_ + 0.13, 0.08, 0.025, 0.025, "gold")
        for sy in (-1, 1):
            box("gull_wing", mx_ - 0.04, my_ + sy * 0.08, mz_ + 0.09, 0.24, 0.03, 0.08, "sail_d", rot=(math.radians(sy * 12), 0, 0))
        box("gull_tail", mx_ - 0.17, my_, mz_ + 0.08, 0.1, 0.06, 0.03, "dark")



# ------------------------------------------------------------------ mâtures


def square_sail(x, z0, z1, width, bulge, emblem, patch=None):
    # 12/11 : voile pleine (avant : des faces retirées au hasard en bas, « en lambeaux », qui faisaient croire à de la
    # transparence ; et un damier de deux teintes), une seule matière, et des coordonnées de texture : la toile du jeu (lés,
    # coutures, ralingue) suit la voile. L'emblème n'est plus un objet 3D blanc collé dessus : il est peint dans la toile
    # (matière « sail_e », voir ShipModel.emblem_texture).
    nu, nv = 16, 10
    verts, faces, uvs = [], [], []
    # v2 (passe 2) : voiles plus gonflées (creux x1,3, ventre placé un peu bas), et la bordure (le bas) remonte en arc au milieu,
    # comme une vraie voile carrée tenue aux deux coins : la silhouette n'est plus un trapèze
    bulge_k = 1.15 if V2 else 1.0   # (13/11 : 1,3 ; le creux de la misaine traversait les focs)
    roach = 0.32 * (z1 - z0) / 3.0 if V2 else 0.0

    def surf(u, v, off=0.0):
        wv = width * (1.0 - 0.18 * v)
        if V2:
            prof = math.sin(math.pi * u) ** 0.8 * math.sin(math.pi * (0.10 + 0.90 * v ** 0.85))
        else:
            prof = math.sin(math.pi * u) * math.sin(math.pi * (0.12 + 0.88 * v))
        bx = bulge * bulge_k * prof
        lift = roach * math.sin(math.pi * u) * (1.0 - v) ** 2
        return (x + bx + off, (u - 0.5) * wv, z0 + lift + v * (z1 - z0 - lift))

    for j in range(nv + 1):
        v = j / nv
        for i in range(nu + 1):
            u = i / nu
            verts.append(surf(u, v))
            uvs.append((u, v))
    for j in range(nv):
        for i in range(nu):
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
    tag = "sail_z%d" % round(z1 * 100)
    add_mesh(tag, verts, faces, "sail_e" if emblem else "sail", uvs=uvs)
    if V2 and patch is not None:
        # une rustine : un carré de toile plus sombre cousu sur la voile, des deux côtés (le bateau a vécu). Elle porte le même
        # nom de voile (« sail_zNNN_patch ») : le jeu la gonfle, la cargue et l'oriente avec sa voile.
        pu0, pv0, pu1, pv1 = patch
        for side, off in (("a", 0.025), ("b", -0.025)):
            pvv, pff, puv = [], [], []
            n = 4
            for j in range(n + 1):
                for i in range(n + 1):
                    u = pu0 + (pu1 - pu0) * i / n + 0.012 * math.sin(j * 2.1)   # bords un peu irréguliers
                    v = pv0 + (pv1 - pv0) * j / n + 0.01 * math.sin(i * 1.7)
                    pvv.append(surf(u, v, off))
                    puv.append((i / n * 0.3, j / n * 0.3))
            for j in range(n):
                for i in range(n):
                    a = j * (n + 1) + i
                    pff.append((a, a + 1, a + n + 2, a + n + 1))
            add_mesh(tag + "_patch" + side, pvv, pff, "sail_d", uvs=puv)
    # 13/11 : les vergues portent le nom de leur voile (« yard_zNNN », « yardlow_zNNN ») : le jeu les fait tourner avec elle, et la
    # vergue du bas remonte quand on cargue. Avant, seule la toile pivotait : les voiles semblaient flotter, détachées du bateau.
    cyl("yard_z%d" % round(z1 * 100), x, 0, z1, 0.11, width * 0.82 + 0.6, "mast", rot=(math.radians(90), 0, 0))
    cyl("yardlow_z%d" % round(z1 * 100), x, 0, z0, 0.07, width + 0.2, "mast", rot=(math.radians(90), 0, 0), verts=6)


max_top = 0.0
NESTS: list = []   # (x, y, z du plancher, hauteur du mât)
for mx, mh, sails in CFG["masts"]:
    OBST_CIRCLES.append((mx, 0.0, 0.27 + (0.04 if L > 14 else 0)))   # le mât lui-même (+ sa bague), pas un halo autour
    cyl("mast", mx, 0, mh / 2, 0.19 + (0.04 if L > 14 else 0), mh, "mast")
    cyl("mast_band", mx, 0, 1.2, 0.25, 0.35, "gold")
    zn = mh - 2.05                      # plancher du nid de pie
    cyl("nest_floor", mx, 0, zn, 0.72, 0.1, "deck")
    cyl("nest_rim", mx, 0, zn - 0.08, 0.76, 0.12, "mast")
    for q in range(12):                 # lattes du tonneau
        ang = q * math.pi / 6
        box("nest_slat", mx + 0.66 * math.cos(ang), 0.66 * math.sin(ang), zn + 0.32, 0.16, 0.1, 0.6, "mast",
            rot=(0, 0, ang + math.pi / 2))
    for q in range(12):                 # lisse du haut
        ang = q * math.pi / 6 + math.pi / 12
        box("nest_rail", mx + 0.68 * math.cos(ang), 0.68 * math.sin(ang), zn + 0.66, 0.34, 0.09, 0.08, "gold",
            rot=(0, 0, ang + math.pi / 2))
    NESTS.append((mx, 0.0, zn + 0.05, mh))
    max_top = max(max_top, mh)
    for si, (z0, z1, w, b, e) in enumerate(sails):
        # deux rustines sur le brigantin : basse voile de misaine (à droite) et hunier du grand mât (à gauche)
        pt = None
        if V2 and si == 0 and mx > 0:
            pt = (0.64, 0.22, 0.80, 0.42)
        elif V2 and si == 1 and mx < 0:
            pt = (0.18, 0.40, 0.32, 0.66)
        square_sail(mx, z0, z1, w, b, e, pt)
    for side in (-1, 1):
        for k in range(3):
            rope((mx, 0, mh * 0.78), (mx - 0.7 + k * 0.7, side * (hw_s * 0.95), 0.62))
    if V2:
        # mâts cerclés de fer (Sea of Thieves) ; enfléchures : des échelons de corde entre les haubans avant et arrière
        for zb in (2.4, mh * 0.45, mh * 0.62):
            cyl("mast_iron", mx, 0, zb, 0.235 + (0.04 if L > 14 else 0), 0.12, "iron")
        for side in (-1, 1):
            mtop = Vector((mx, 0, mh * 0.78))
            fa = Vector((mx - 0.7, side * (hw_s * 0.95), 0.62))
            fb = Vector((mx + 0.7, side * (hw_s * 0.95), 0.62))
            t = 0.1
            while t < 0.8:
                pa = fa.lerp(mtop, t)
                pb = fb.lerp(mtop, t)
                rope(tuple(pa), tuple(pb), r=0.035, mat="rope")
                t += 0.075
        # une lanterne accrochée au mât, côté avant, à hauteur d'homme
        lz = 2.15
        box("lantern_frame", mx + 0.3, 0, lz, 0.2, 0.2, 0.3, "iron")
        box("lantern", mx + 0.3, 0, lz, 0.13, 0.22, 0.2, "glow")
        box("lantern_cap", mx + 0.3, 0, lz + 0.19, 0.26, 0.26, 0.06, "iron")

# échelle de mât : sur la face arrière du mât le plus haut, du pont jusqu'au nid de pie
_tall = max(NESTS, key=lambda n: n[3])
MAST_LADDER = (_tall[0] - 0.62, 0.0, 0.55, _tall[2] - 0.05)   # x, y, z bas, z haut
_mlx = _tall[0] - 0.33
for dy in (-0.17, 0.17):
    cyl("mladder_rail", _mlx, dy, (MAST_LADDER[2] + MAST_LADDER[3]) / 2, 0.03, MAST_LADDER[3] - MAST_LADDER[2], "mast", verts=6)
_zr = MAST_LADDER[2] + 0.25
while _zr < MAST_LADDER[3] - 0.1:
    box("mladder_rung", _mlx, 0.0, _zr, 0.06, 0.4, 0.06, "mast")
    _zr += 0.3
for _dz in (0.9, 1.7):   # accroches du mât, pour que l'échelle ne flotte pas
    pass

if CFG["jib"]:
    # 13/11 : les focs ne partent plus du mât (leur bord arrière longeait le mât : la misaine gonflée les traversait). Chaque foc
    # est envergué sur son étai, entre le mât et le beaupré, et son point d'écoute reste devant le creux de la misaine.
    fx, fh = CFG["masts"][0][0], CFG["masts"][0][1]
    _low = CFG["masts"][0][2][0]                          # la basse voile de misaine : (z0, z1, largeur, creux, emblème)
    _reach = fx + 0.12 + _low[3] * (1.15 if V2 else 1.0) * 1.75   # jusqu'où avance son creux, voiles gonflées

    def _on(a, b, t):
        return (a[0] + (b[0] - a[0]) * t, 0, a[1] + (b[1] - a[1]) * t)

    A2, B2 = (fx + 0.15, fh - 0.2), (x_b + (3.9 if V2 else 3.0), dz_b + (1.9 if V2 else 1.5))   # étai du grand foc
    if V2:
        A1, B1 = (fx + 0.15, fh * 0.72), (x_b + 1.2, dz_b + 1.0)                                 # étai de trinquette
        h1 = _on(A1, B1, 0.33)
        add_mesh("sail_z%d_jib" % round(h1[2] * 100), [h1, _on(A1, B1, 0.96), (_reach + 1.1, 0, _low[0] + 0.05)], [(0, 1, 2)],
                 "sail", uvs=[(0.05, 1.0), (0.95, 0.35), (0.05, 0.0)])
        rope((A1[0], 0, A1[1]), (B1[0], 0, B1[1]), r=0.04)
        # le grand foc, entre les deux étais : son point d'écoute reste devant l'étai de trinquette
        _zc = _low[0] + 0.75
        _xc = A1[0] + (A1[1] - _zc) / (A1[1] - B1[1]) * (B1[0] - A1[0]) + 0.45
        h2 = _on(A2, B2, 0.2)
        add_mesh("sail_z%d_jibavant" % round(h2[2] * 100), [h2, _on(A2, B2, 0.97), (_xc, 0, _zc)], [(0, 1, 2)], "sail",
                 uvs=[(0.05, 1.0), (0.95, 0.35), (0.05, 0.0)])
    else:
        h2 = _on(A2, B2, 0.2)
        add_mesh("sail_z%d_jib" % round(h2[2] * 100), [h2, _on(A2, B2, 0.97), (_reach + 0.9, 0, _low[0] + 0.6)], [(0, 1, 2)], "sail",
                 uvs=[(0.05, 1.0), (0.95, 0.35), (0.05, 0.0)])
    rope((A2[0], 0, A2[1]), (B2[0], 0, B2[1]), r=0.04)
if CFG["gaff"]:
    gx, gh, gend = CFG["gaff"]
    sz = max(2.6, top + 0.4)
    # 13/11 : quand la brigantine est sur le mât qui porte l'échelle de mât, son bord d'attaque passait entre les montants de
    # l'échelle (la voile traversait les barreaux). Il est reculé derrière l'échelle, tenu au mât par une corne et une bôme.
    _gl = 1.25 if abs(gx - _tall[0]) < 0.1 else 0.3
    add_mesh("sail_z%d_spanker" % round(gh * 100), [(gx - _gl, 0, gh), (gend, 0, sz), (gx - _gl, 0, sz)], [(0, 1, 2)], "sail",
             uvs=[(0.05, 1.0), (0.95, 0.0), (0.05, 0.0)])
    rope((gx, 0, gh + 0.25), (gend, 0, sz))
    if _gl > 0.5:
        rope((gx, 0, gh + 0.25), (gx - _gl, 0, gh), r=0.05, mat="mast")
        rope((gx, 0, sz - 0.1), (gend, 0, sz - 0.1), r=0.06, mat="mast")

# pavillon noir avec tête de mort, sur le mât choisi
fmx, fmh, _s = CFG["masts"][CFG["flag_mast"]]
add_mesh("flag", [(fmx, 0, fmh + 0.15), (fmx - 2.4, 0.0, fmh - 0.1), (fmx - 2.4, 0.0, fmh - 1.3), (fmx, 0, fmh - 1.05)],
         [(0, 1, 2, 3)], "flag")
cyl("flag_skull", fmx - 1.1, 0.03, fmh - 0.6, 0.26, 0.05, "bone", rot=(math.radians(90), 0, 0))
if len(CFG["masts"]) > 1:
    rope((CFG["masts"][0][0], 0, CFG["masts"][0][1] - 0.2), (CFG["masts"][-1][0], 0, CFG["masts"][-1][1] - 0.2))
if V2:
    # la flamme : une longue banderole rouge en tête du plus haut mât, qui ondule (le signe « pirate » le plus visible de loin ;
    # le jeu l'oriente selon le vent, voir ShipModel)
    tmx, tmh = max(((m[0], m[1]) for m in CFG["masts"]), key=lambda m: m[1])
    pv_, pf_ = [], []
    n_ = 12
    for i in range(n_ + 1):
        t = i / n_
        w = 0.42 * (1.0 - t) + 0.04
        px = tmx - 4.2 * t
        py = 0.22 * math.sin(t * math.pi * 2.5)
        pz = tmh + 0.35 - 0.5 * t * t
        pv_.append((px, py, pz + w / 2))
        pv_.append((px, py, pz - w / 2))
    for i in range(n_):
        pf_.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    add_mesh("pennant", pv_, pf_, "red")
    cyl("pennant_pole", tmx, 0, tmh + 0.2, 0.05, 0.5, "mast", verts=6)

# ------------------------------------------------------------------ recentrage et pivot
bpy.context.view_layer.update()
xs, zs = [], []
for ob in parts:
    for corner in ob.bound_box:
        w = ob.matrix_world @ Vector(corner)
        xs.append(w.x)
        zs.append(w.z)
shift = -(min(xs) + max(xs)) / 2
zc = 0.36 * max(zs)
bpy.ops.object.empty_add(location=(0, 0, 0))
pivot = bpy.context.active_object
pivot.name = "ship"
for ob in parts:
    ob.location.x += shift
    ob.parent = pivot
    if ob.type == "MESH":
        # ombrage lisse pour les formes courbes (coque, voiles, mâts, canons, tonneaux) ;
        # les caisses, la cabine et les planches gardent des arêtes nettes
        smooth = ob.name.startswith(("hull", "sail_z", "mast", "yard", "bowsprit", "crow", "cannon",
                                     "barrel", "anchor", "helm", "skull", "rope", "lamp_post"))
        for poly in ob.data.polygons:
            poly.use_smooth = smooth

# v2 : un biseau fin sur les arêtes de toutes les pièces (boîtes, cylindres). Rien n'est plus à angle vif : la lumière accroche
# les arêtes, et le jeu y pose son reflet d'un pixel (design/bible-v2.md, § 4.1). Appliqué à l'export.
if V2:
    for ob in BEVEL:
        dims = sorted(ob.dimensions)
        if dims[0] < 0.07:   # pièce trop fine (latte, cordage) : pas de biseau
            continue
        mod = ob.modifiers.new("biseau", "BEVEL")
        mod.width = min(0.035, dims[0] * 0.18)
        mod.segments = 1
        mod.limit_method = "ANGLE"
        mod.harden_normals = False

# ------------------------------------------------------------------ export 3D (si nb de caps = 0)
if HEADINGS == 0:
    import json
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{SHIP}.glb"), export_format="GLB", use_selection=True, export_apply=True)
    (OUT / f"{SHIP}_meta.json").write_text(json.dumps(
        {"shift": shift, "length": L, "beam": WID, "max_height": max(zs),
         "boxes": OBST_BOXES, "circles": OBST_CIRCLES, "cabin": CABIN, "cannons": CANNONS,
         "helm": list(HELM), "ammo": [_bx, _by], "anchor": list(ANCHOR),
         "masts": [[m[0], m[1]] for m in CFG["masts"]],
         "ladders": [list(l) for l in LADDERS], "nests": [list(n) for n in NESTS],
         "mast_ladder": list(MAST_LADDER), "bow_x": L / 2 - 0.4, "sheer": SHEER}))
    print("export termine", SHIP)
    sys.exit(0)

# ------------------------------------------------------------------ rendu
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.film_transparent = True
scene.render.resolution_x = SIZE
scene.render.resolution_y = SIZE
scene.render.image_settings.file_format = "PNG"
scene.render.image_settings.color_mode = "RGBA"
scene.view_settings.view_transform = "Standard"
try:
    scene.eevee.taa_render_samples = 24
except AttributeError:
    pass

world = bpy.data.worlds.new("W")
scene.world = world
world.use_nodes = True
bg = world.node_tree.nodes["Background"]
bg.inputs["Color"].default_value = (0.34, 0.32, 0.58, 1.0)
bg.inputs["Strength"].default_value = 0.55

sun = bpy.data.lights.new("sun", "SUN")
sun.energy = 5.0
sun.color = (1.0, 0.70, 0.48)
sun_ob = bpy.data.objects.new("sun", sun)
sun_ob.rotation_euler = (math.radians(50), math.radians(10), math.radians(-40))
scene.collection.objects.link(sun_ob)
fill = bpy.data.lights.new("fill", "SUN")
fill.energy = 0.8
fill.color = (0.45, 0.50, 1.0)
fill_ob = bpy.data.objects.new("fill", fill)
fill_ob.rotation_euler = (math.radians(70), 0, math.radians(140))
scene.collection.objects.link(fill_ob)

cam = bpy.data.cameras.new("cam")
cam.type = "ORTHO"
cam.ortho_scale = ORTHO
cam_ob = bpy.data.objects.new("cam", cam)
scene.collection.objects.link(cam_ob)
scene.camera = cam_ob
dist = 40.0
el = math.radians(ELEVATION)
cam_ob.location = (0, -dist * math.cos(el), dist * math.sin(el) + zc)
cam_ob.rotation_euler = (math.radians(90 - ELEVATION), 0, 0)

OUT.mkdir(parents=True, exist_ok=True)
for k in range(HEADINGS):
    pivot.rotation_euler = (0, 0, -math.radians(k * 360.0 / HEADINGS))
    scene.render.filepath = str(OUT / f"raw_{k:02d}.png")
    bpy.ops.render.render(write_still=True)
print("rendu termine", SHIP, HEADINGS)
