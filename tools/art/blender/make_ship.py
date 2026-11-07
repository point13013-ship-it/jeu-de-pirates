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
ORTHO = {"sloop": 16.0, "brigantin": 19.2, "galion": 25.6}[SHIP]
rnd = random.Random(5)

# ------------------------------------------------------------------ les trois bateaux
# masts : (x, hauteur, [voiles (z0, z1, largeur, bombement, emblème)])
CFG = {
    "sloop": dict(L=9.6, WID=3.4, DEP=2.6, castle=1, cannons=2, ports=3, bow_castle=False,
                  masts=[(0.5, 7.6, [(2.4, 5.2, 4.4, 1.0, True), (5.5, 7.0, 3.2, 0.6, False)])],
                  jib=True, gaff=None, flag_mast=0, anchor=(1.9, 0.0)),
    "brigantin": dict(L=12.6, WID=4.3, DEP=3.0, castle=2, cannons=3, ports=4, bow_castle=False,
                      masts=[(3.0, 8.6, [(2.9, 5.9, 5.0, 1.0, False), (6.2, 8.0, 3.8, 0.6, False)]),
                             (-1.2, 9.6, [(3.0, 6.6, 6.0, 1.1, True), (6.9, 9.0, 4.6, 0.7, False)])],
                      jib=True, gaff=(-1.2, 8.0, -6.0), flag_mast=1, anchor=(4.0, 0.0)),
    "galion": dict(L=16.0, WID=5.6, DEP=3.8, castle=3, cannons=5, ports=6, bow_castle=True,
                   masts=[(5.0, 9.6, [(3.2, 6.3, 5.8, 1.1, False), (6.6, 8.6, 4.2, 0.6, False)]),
                          (0.4, 12.0, [(3.4, 7.0, 7.4, 1.3, True), (7.3, 9.9, 5.8, 0.9, False),
                                       (10.2, 11.6, 4.0, 0.5, False)]),
                          (-1.6, 9.0, [(3.0, 6.0, 4.6, 0.9, False)])],
                   jib=True, gaff=(-1.6, 8.4, -7.6), flag_mast=1, anchor=(3.6, 0.0)),
}[SHIP]
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
    "red": make_mat("red", (0.42, 0.09, 0.11)),
    "flag": make_mat("flag", (0.022, 0.018, 0.045)),
    "bone": make_mat("bone", (0.90, 0.86, 0.76)),
    "glow": make_mat("glow", (1.0, 0.62, 0.20), 0.5, emit=7.0),
    "dark": make_mat("dark", (0.025, 0.02, 0.035)),
    "iron": make_mat("iron", (0.07, 0.065, 0.09), 0.55),
    "rope": make_mat("rope", (0.06, 0.04, 0.045)),
}


def add_mesh(name, verts, faces, mats, mat_index=None):
    me = bpy.data.meshes.new(name)
    me.from_pydata(verts, [], faces)
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


def box(name, cx, cy, cz, sx, sy, sz, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=(cx, cy, cz), rotation=rot)
    ob = bpy.context.active_object
    ob.scale = (sx / 2, sy / 2, sz / 2)
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


def cyl(name, x, y, z, r, depth, mat, rot=(0, 0, 0), verts=16):
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=depth, location=(x, y, z), rotation=rot, vertices=verts)
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
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
    deck_z = (0.62 * u ** 2.2 + 0.34 * (1 - u) ** 2.5) * (L / 13.0)
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
        hull_verts.append((x, -hw * math.cos(phi), dz - dp * hull_depth_frac(phi)))
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

LANES = 9
for m in range(LANES):
    f0, f1 = m / LANES, (m + 1) / LANES
    a, b = [], []
    for i in range(N):
        x, hw, dz, dp = station(i / (N - 1))
        a.append((x, (-1 + 2 * f0) * hw * 0.98, dz))
        b.append((x, (-1 + 2 * f1) * hw * 0.98, dz))
    strip("deck", a, b, "deck" if m % 2 == 0 else "deck_l")

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
    for k in range(CFG["cannons"]):
        u = 0.22 + k * (0.50 / max(1, CFG["cannons"] - 1))
        x, hw, dz, dp = station(u)
        CANNONS.append((x, side * (hw - 0.5), side, dz + 0.34))
        cyl("cannon", x, side * (hw - 0.5), dz + 0.34, 0.18, 1.0, "iron", rot=(math.radians(90), 0, 0))
        cyl("cannon_end", x, side * (hw - 0.05), dz + 0.34, 0.22, 0.2, "iron", rot=(math.radians(90), 0, 0))

# château arrière : la cabine du rez-de-chaussée est creuse (on y entre par une porte), les
# niveaux au-dessus sont pleins. Les objets nommés « cut_* » sont masqués par le jeu quand le
# joueur est à l'intérieur (toit, murs tournés vers la caméra) ; « int_* » est le mobilier.
x_s, hw_s, dz_s, _ = station(0.10)
cw = hw_s * 2
c = CFG["castle"]
cx0 = -L / 2 + 2.0 + 0.5 * c
ln0 = 2.2 + c * 0.5
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
# fenêtres éclairées sur les murs extérieurs
for k in range(2):
    box("cut_win_w", wx - 0.02, (k - 0.5) * (wid0 * 0.5), fz + 1.0, 0.07, 0.5, 0.42, "glow")
for sgn, tag in ((-1, "s"), (1, "n")):
    box("cut_win_" + tag, cabin_cx - 0.3, sgn * (ny + 0.02), fz + 1.0, 0.5, 0.07, 0.42, "glow")
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
box("int_lamp", cabin_cx + 0.35, 0, fz + H0 - 0.45, 0.22, 0.22, 0.28, "glow")
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
        box("cut_up_win", face, yy, top + h / 2, 0.07, 0.5, 0.42, "glow")
    for sgn in (-1, 1):
        box("cut_up_win", cabin_cx, sgn * (wd / 2 + 0.02), top + h / 2, 0.5, 0.07, 0.42, "glow")
    top += h + 0.12
roof_len = (2.4 + 0.5) if c > 1 else ln0 + 0.5
roof_wid = cw * 0.78 if c > 1 else wid0 + 0.3
box("cut_roof", cabin_cx, 0, top + 0.1, roof_len, roof_wid, 0.22, "red")
cyl("cut_lamp_post", wx - 0.3, 0, top + 0.5, 0.07, 1.0, "dark")
box("cut_lamp", wx - 0.3, 0, top + 1.15, 0.3, 0.3, 0.4, "glow")
# barre à roue, devant la cabine, sur le côté
HELM = (ex + 0.9, -1.1)
cyl("helm", HELM[0], HELM[1], fz + 1.35, 0.5, 0.1, "mast", rot=(math.radians(90), 0, 0), verts=14)
cyl("helm_post", HELM[0], HELM[1], fz + 1.0, 0.08, 0.6, "mast")
OBST_CIRCLES.append((HELM[0], HELM[1], 0.45))

if CFG["bow_castle"]:
    xb, hwb, dzb, _ = station(0.88)
    OBST_BOXES.append((xb - 1.1, -hwb * 0.92, xb + 1.1, hwb * 0.92))
    box("fore_castle", xb, 0, dzb + 0.55, 2.2, hwb * 2 * 0.92, 1.1, "hull_l")
    box("fore_castle_trim", xb, 0, dzb + 1.12, 2.3, hwb * 2 * 0.94, 0.10, "gold")
    box("fore_castle_top", xb, 0, dzb + 1.2, 2.0, hwb * 2 * 0.78, 0.14, "deck")

# détails de pont : écoutille (sauf sloop), tonneau de boulets, caisses, cabestan d'ancre
_hx = 1.6 if L > 11 else 1.2
_bx = 2.9 if L > 14 else 2.2
if SHIP != "sloop":
    OBST_BOXES.append((_hx - 0.62, -0.62, _hx + 0.62, 0.62))
    box("hatch", _hx, 0, 0.14, 1.2, 1.2, 0.28, "hull_l")
    box("hatch_grate", _hx, 0, 0.30, 1.0, 1.0, 0.05, "dark")
OBST_CIRCLES.append((_bx, 1.0, 0.5))
OBST_BOXES.append((-0.35, -1.65, 0.55, -0.78))
cyl("barrel", _bx, 1.0, 0.42, 0.42, 0.7, "hull_l")
cyl("barrel_b", _bx, 1.0, 0.45, 0.45, 0.1, "iron")
for k in range(3):  # boulets empilés sur le tonneau
    sphere("ball", _bx + (k - 1) * 0.2, 1.0 + (0.1 if k == 1 else -0.08), 0.84 + (0.14 if k == 1 else 0.0), 0.11, "iron")
ANCHOR = CFG["anchor"]
cyl("anchor_capstan", ANCHOR[0], ANCHOR[1], 0.45, 0.26, 0.7, "iron")
cyl("anchor_capstan_top", ANCHOR[0], ANCHOR[1], 0.84, 0.34, 0.08, "gold")
cyl("anchor_spoke", ANCHOR[0], ANCHOR[1], 0.8, 0.05, 0.9, "mast", rot=(math.radians(90), 0, 0), verts=5)
box("crate", 0.1, -1.2, 0.32, 0.85, 0.85, 0.64, "deck_l")
box("crate2", 0.3, -1.3, 0.86, 0.5, 0.5, 0.46, "deck")

# figure de proue : tête de mort ; beaupré
x_b, hw_b, dz_b, _ = station(1.0)
sphere("skull", x_b + 0.45, 0, dz_b + 0.55, 0.30, "bone")
box("jaw", x_b + 0.58, 0, dz_b + 0.30, 0.2, 0.28, 0.14, "bone")
for sgn in (-1, 1):
    box("eye", x_b + 0.7, sgn * 0.11, dz_b + 0.62, 0.06, 0.1, 0.1, "dark")
cyl("bowsprit", x_b + 1.7, 0, dz_b + 0.9, 0.14, 4.2 * (L / 13.0) ** 0.5, "mast", rot=(0, math.radians(75), 0))

# ------------------------------------------------------------------ mâtures


def square_sail(x, z0, z1, width, bulge, emblem):
    nu, nv = 16, 10
    verts, faces, mats = [], [], []
    for j in range(nv + 1):
        v = j / nv
        wv = width * (1.0 - 0.18 * v)
        for i in range(nu + 1):
            u = i / nu
            bx = bulge * math.sin(math.pi * u) * math.sin(math.pi * (0.12 + 0.76 * v))
            verts.append((x + bx, (u - 0.5) * wv, z0 + v * (z1 - z0)))
    for j in range(nv):
        for i in range(nu):
            if j < 2 and rnd.random() < 0.16:
                continue  # déchirure : le bas de la voile est en lambeaux
            a = j * (nu + 1) + i
            faces.append((a, a + 1, a + nu + 2, a + nu + 1))
            r = rnd.random()
            mats.append(2 if r < 0.12 else (1 if (i + j) % 2 else 0))
    add_mesh("sail_z%d" % round(z1 * 100), verts, faces, ["sail", "sail_d", "sail_p"], lambda p: mats[p])
    cyl("yard", x, 0, z1, 0.11, width * 0.82 + 0.6, "mast", rot=(math.radians(90), 0, 0))
    cyl("yard_low", x, 0, z0, 0.07, width + 0.2, "mast", rot=(math.radians(90), 0, 0), verts=6)
    if emblem:
        zc = (z0 + z1) / 2 + 0.2
        xe = x + bulge * 0.95
        r = min(width, z1 - z0) * 0.2
        cyl("sail_z%d_skull" % round(z1 * 100), xe, 0, zc, r, 0.14, "bone", rot=(0, math.radians(90), 0), verts=12)
        for sgn in (-1, 1):
            cyl("sail_z%d_eye" % round(z1 * 100), xe, sgn * r * 0.38, zc + r * 0.12, r * 0.26, 0.2, "dark", rot=(0, math.radians(90), 0), verts=8)
            box("sail_z%d_bone" % round(z1 * 100), xe, 0, zc - r * 1.2, 0.1, r * 3.4, 0.2, "bone", rot=(sgn * math.radians(32), 0, 0))


max_top = 0.0
for mx, mh, sails in CFG["masts"]:
    OBST_CIRCLES.append((mx, 0.0, 0.38))
    cyl("mast", mx, 0, mh / 2, 0.19 + (0.04 if L > 14 else 0), mh, "mast")
    cyl("mast_band", mx, 0, 1.2, 0.25, 0.35, "gold")
    cyl("crow", mx, 0, mh - 1.9, 0.6, 0.36, "mast")
    max_top = max(max_top, mh)
    for (z0, z1, w, b, e) in sails:
        square_sail(mx, z0, z1, w, b, e)
    for side in (-1, 1):
        for k in range(3):
            rope((mx, 0, mh * 0.78), (mx - 0.7 + k * 0.7, side * (hw_s * 0.95), 0.62))

if CFG["jib"]:
    fx, fh = CFG["masts"][0][0], CFG["masts"][0][1]
    add_mesh("sail_z%d_jib" % round((fh - 0.9) * 100), [(fx + 0.3, 0, fh - 0.9), (x_b + 3.0, 0, dz_b + 1.5), (fx + 0.5, 0, 1.7)], [(0, 1, 2)], "sail_d")
    rope((fx, 0, fh - 0.2), (x_b + 3.0, 0, dz_b + 1.5))
if CFG["gaff"]:
    gx, gh, gend = CFG["gaff"]
    sz = max(2.6, top + 0.4)
    add_mesh("sail_z%d_spanker" % round(gh * 100), [(gx - 0.3, 0, gh), (gend, 0, sz), (gx - 0.3, 0, sz)], [(0, 1, 2)], "sail")
    rope((gx, 0, gh), (gend, 0, sz))

# pavillon noir avec tête de mort, sur le mât choisi
fmx, fmh, _s = CFG["masts"][CFG["flag_mast"]]
add_mesh("flag", [(fmx, 0, fmh + 0.15), (fmx - 2.4, 0.0, fmh - 0.1), (fmx - 2.4, 0.0, fmh - 1.3), (fmx, 0, fmh - 1.05)],
         [(0, 1, 2, 3)], "flag")
cyl("flag_skull", fmx - 1.1, 0.03, fmh - 0.6, 0.26, 0.05, "bone", rot=(math.radians(90), 0, 0))
if len(CFG["masts"]) > 1:
    rope((CFG["masts"][0][0], 0, CFG["masts"][0][1] - 0.2), (CFG["masts"][-1][0], 0, CFG["masts"][-1][1] - 0.2))

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

# ------------------------------------------------------------------ export 3D (si nb de caps = 0)
if HEADINGS == 0:
    import json
    OUT.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"{SHIP}.glb"), export_format="GLB", use_selection=True)
    (OUT / f"{SHIP}_meta.json").write_text(json.dumps(
        {"shift": shift, "length": L, "beam": WID, "max_height": max(zs),
         "boxes": OBST_BOXES, "circles": OBST_CIRCLES, "cabin": CABIN, "cannons": CANNONS,
         "helm": list(HELM), "ammo": [_bx, 1.0], "anchor": list(ANCHOR),
         "masts": [[m[0], m[1]] for m in CFG["masts"]]}))
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
