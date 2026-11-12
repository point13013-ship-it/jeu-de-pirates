"""Construit la ville portuaire (point d'arrivée de l'équipage) et l'exporte en glb + méta json.

Usage : blender.exe -b --python make_port.py -- <dossier de sortie ABSOLU>

Repère : x vers l'est, y vers le nord, z vers le haut, en mètres (échelle du jeu, sans agrandissement).
Le quai est en y = 0, la mer au sud (y < 0), la ville au nord. Le sommet du quai est à z = 0 (même
hauteur que le pont des bateaux) ; la mer est à z = -1.45.
La caméra du jeu regarde toujours vers le nord : les détails sont sur les façades sud et les toits.

Conventions de nommage reprises par le jeu :
- « ground_cobble », « ground_planks », « ground_sand », « ground_grass » : sols repeints par des shaders ;
- « bldg_<id>_* » : pièces d'un bâtiment (le jeu peut l'estomper quand il cache le joueur).
Le json décrit les zones où l'on marche, les obstacles, les PNJ et l'emplacement d'amarrage.
"""
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0] if ARGS else ".").resolve()
rnd = random.Random(21)

bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
parts: list = []
OBST: list = []        # (x0, y0, x1, y1) zones où l'on ne peut pas marcher
CIRCLES: list = []     # (x, y, rayon)
NPCS: dict = {}        # rôle -> (x, y) où se tient le PNJ (devant sa boutique)


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


MAT = {k: make_mat(k, *v) for k, v in {
    # enduits des façades
    "pl_cream": ((0.80, 0.68, 0.50),), "pl_ochre": ((0.80, 0.50, 0.22),), "pl_terra": ((0.62, 0.27, 0.18),),
    "pl_teal": ((0.22, 0.44, 0.44),), "pl_rose": ((0.80, 0.48, 0.44),), "pl_white": ((0.86, 0.80, 0.70),),
    # bois, pierre, toits
    "wood_d": ((0.16, 0.09, 0.06),), "wood": ((0.32, 0.19, 0.11),), "wood_l": ((0.52, 0.34, 0.18),),
    "stone": ((0.46, 0.42, 0.40),), "stone_d": ((0.28, 0.26, 0.27),), "algae": ((0.10, 0.16, 0.12),),
    "roof_terra": ((0.56, 0.20, 0.11),), "roof_terra_d": ((0.42, 0.14, 0.08),),
    "roof_slate": ((0.20, 0.22, 0.30),), "roof_slate_d": ((0.13, 0.14, 0.20),),
    "roof_green": ((0.18, 0.34, 0.28),), "roof_green_d": ((0.11, 0.23, 0.19),),
    "shut_teal": ((0.12, 0.40, 0.42),), "shut_red": ((0.50, 0.12, 0.10),), "shut_blue": ((0.16, 0.24, 0.48),),
    "glass": ((0.05, 0.06, 0.10), 0.3), "glow": ((1.0, 0.66, 0.26), 0.5, 6.0),
    # tissus, objets
    "cloth_red": ((0.62, 0.12, 0.12),), "cloth_cream": ((0.86, 0.80, 0.66),), "cloth_blue": ((0.16, 0.30, 0.58),),
    "cloth_green": ((0.18, 0.44, 0.28),), "cloth_yellow": ((0.86, 0.66, 0.16),),
    "gold": ((0.80, 0.52, 0.14), 0.45), "iron": ((0.08, 0.08, 0.10), 0.55), "rope": ((0.50, 0.40, 0.26),),
    "leaf": ((0.14, 0.38, 0.16),), "leaf_d": ((0.08, 0.24, 0.10),), "trunk": ((0.36, 0.25, 0.15),),
    "fruit_r": ((0.80, 0.18, 0.10),), "fruit_y": ((0.92, 0.72, 0.12),), "fish": ((0.55, 0.62, 0.68),),
    "paper": ((0.88, 0.82, 0.66),),
    # sols (repeints par le jeu)
    "ground_cobble": ((0.55, 0.50, 0.46),), "ground_planks": ((0.48, 0.32, 0.18),),
    "ground_sand": ((0.86, 0.74, 0.52),), "ground_grass": ((0.30, 0.50, 0.22),),
}.items()}


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


def box(name, x0, y0, z0, x1, y1, z1, mat, rot_z=0.0):
    """Boîte donnée par ses coins (plus lisible pour l'architecture)."""
    bpy.ops.mesh.primitive_cube_add(location=((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), rotation=(0, 0, rot_z))
    ob = bpy.context.active_object
    ob.scale = ((x1 - x0) / 2, (y1 - y0) / 2, (z1 - z0) / 2)
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


def cyl(name, x, y, z0, z1, r, mat, verts=12, r_top=None):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r if r_top is None else r_top,
                                    depth=z1 - z0, location=(x, y, (z0 + z1) / 2))
    ob = bpy.context.active_object
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


def sphere(name, x, y, z, r, mat, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=12, ring_count=7)
    ob = bpy.context.active_object
    ob.scale = (1, 1, sz)
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


def rope(name, a, b, r=0.03, mat="rope"):
    va, vb = Vector(a), Vector(b)
    d = vb - va
    bpy.ops.mesh.primitive_cylinder_add(radius=r, depth=d.length, location=(va + vb) / 2, vertices=5)
    ob = bpy.context.active_object
    ob.rotation_euler = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    ob.name = name
    ob.data.materials.append(MAT[mat])
    parts.append(ob)
    return ob


# ====================================================================== sol, quai, pontons
LAND = (-42.0, 0.0, 42.0, 52.0)
box("ground_cobble", LAND[0], LAND[1], -3.2, LAND[2], LAND[3], 0.0, "ground_cobble")
# mur du quai : pierre, ligne d'algues à la flottaison, couronnement clair
box("quay_wall", LAND[0], -0.45, -3.2, LAND[2], 0.02, -0.05, "stone")
box("quay_algae", LAND[0], -0.48, -1.75, LAND[2], -0.40, -1.25, "algae")
box("quay_cap", LAND[0], -0.55, -0.08, LAND[2], 0.35, 0.06, "stone_d")
for x in range(-40, 42, 3):  # joints du mur
    box("quay_joint", x, -0.47, -1.2, x + 0.08, -0.44, -0.1, "stone_d")
# (12/11) la plage de l'ouest a été retirée au lot 1 (c'est la mer jusqu'au quai) : les deux flancs du quai reçoivent le même
# mur que la façade (pierre, algues à la flottaison, couronnement clair, joints) ; avant, les pavés tombaient à pic dans l'eau.
for sx, x_out in ((-1, LAND[0]), (1, LAND[2])):
    xa, xb = (x_out - 0.45, x_out + 0.02) if sx < 0 else (x_out - 0.02, x_out + 0.45)
    box("quay_wall", min(xa, xb), -0.45, -3.2, max(xa, xb), LAND[3], -0.05, "stone")
    ax0, ax1 = (x_out - 0.48, x_out - 0.40) if sx < 0 else (x_out + 0.40, x_out + 0.48)
    box("quay_algae", ax0, -0.45, -1.75, ax1, LAND[3], -1.25, "algae")
    cx0, cx1 = (x_out - 0.55, x_out + 0.35) if sx < 0 else (x_out - 0.35, x_out + 0.55)
    box("quay_cap", cx0, -0.55, -0.08, cx1, LAND[3], 0.06, "stone_d")
    for y in range(2, int(LAND[3]), 3):
        jx0, jx1 = (x_out - 0.47, x_out - 0.44) if sx < 0 else (x_out + 0.44, x_out + 0.47)
        box("quay_joint", jx0, y, -1.2, jx1, y + 0.08, -0.1, "stone_d")
# herbe au fond de la ville
box("ground_grass", LAND[0], 47.0, -0.2, LAND[2], LAND[3], 0.02, "ground_grass")


def pier(prefix, x0, x1, y_end, posts_every=3.0):
    box(prefix + "ground_planks", x0, y_end, -0.25, x1, 0.2, 0.0, "ground_planks")
    for y in [y_end + 0.3 + k * posts_every for k in range(int((-y_end) / posts_every) + 1)]:
        for x in (x0 + 0.15, x1 - 0.15):
            cyl(prefix + "post", x, y, -3.2, 0.35, 0.18, "wood_d", 8)
    cyl(prefix + "bollard", x1 - 0.4, y_end + 1.0, 0.0, 0.5, 0.2, "iron", 10)
    cyl(prefix + "bollard", x1 - 0.4, y_end + 9.0, 0.0, 0.5, 0.2, "iron", 10)


MAIN_PIER = (14.0, 18.0, -30.0)
pier("pier_main_", *MAIN_PIER)
pier("pier_west_", -24.0, -21.0, -14.0)
cyl("pier_lamp", MAIN_PIER[0] + 0.3, MAIN_PIER[2] + 0.4, 0.0, 2.6, 0.06, "wood_d", 6)
box("pier_lamp_glow", MAIN_PIER[0] + 0.1, MAIN_PIER[2] + 0.2, 2.6, MAIN_PIER[0] + 0.5, MAIN_PIER[2] + 0.6, 3.0, "glow")


def rowboat(x, y, yaw, length=4.2, beam=1.4, mat="wood"):
    """Barque (décor) : petite coque lissée, posée dans l'eau."""
    n, ring = 10, 7
    verts = []
    ca, sa = math.cos(yaw), math.sin(yaw)
    for i in range(n):
        u = i / (n - 1)
        lx = (u - 0.5) * length
        half = beam / 2 * math.sin(math.pi * (0.15 + 0.85 * u)) ** 0.6 * (1.0 - 0.9 * max(0.0, u - 0.8) * 5)
        half = max(half, 0.05)
        for k in range(ring):
            phi = math.pi * k / (ring - 1)
            ly = -half * math.cos(phi)
            lz = -1.45 + 0.35 - 0.55 * math.sin(phi) ** 0.7
            verts.append((x + lx * ca - ly * sa, y + lx * sa + ly * ca, lz))
    faces = []
    for i in range(n - 1):
        for k in range(ring - 1):
            a, b = i * ring + k, (i + 1) * ring + k
            faces.append((a, a + 1, b + 1, b))
    add_mesh("boat_hull", verts, faces, mat)
    for t in (-0.2, 0.15):  # bancs
        box("boat_seat", x + t * length * ca - 0.5 * beam * sa * 0, y + t * length * sa, -1.2, x + t * length * ca + 0.25, y + t * length * sa + 0.25, -1.12, "wood_l")


rowboat(-19.4, -5.0, math.radians(92))
rowboat(-25.8, -8.0, math.radians(86), mat="wood_l")
rowboat(-19.6, -11.0, math.radians(95), 3.6, 1.2)

# ====================================================================== bâtiments


def gable_roof(prefix, x0, x1, y0, y1, eave, rise, mat, over=0.45):
    """Toit à deux pans, faîtage parallèle à la façade : le pan sud, bien visible, a des rangées de tuiles."""
    ym = (y0 + y1) / 2
    xa, xb = x0 - over, x1 + over
    rows = 7
    verts, faces, mats = [], [], []
    for r in range(rows + 1):
        t = r / rows
        verts.append((xa, (y0 - over) + (ym - (y0 - over)) * t, eave + rise * t))
        verts.append((xb, (y0 - over) + (ym - (y0 - over)) * t, eave + rise * t))
    for r in range(rows):
        a = 2 * r
        faces.append((a, a + 1, a + 3, a + 2))
        mats.append(r % 2)
    add_mesh(prefix + "roof_front", verts, faces, [mat, mat + "_d"], lambda p: mats[p])
    add_mesh(prefix + "roof_back", [(xa, ym, eave + rise), (xb, ym, eave + rise), (xb, y1 + over, eave), (xa, y1 + over, eave)],
             [(0, 1, 2, 3)], mat + "_d")
    add_mesh(prefix + "roof_gable", [(x0, y0, eave), (x0, ym, eave + rise), (x0, y1, eave),
                                     (x1, y0, eave), (x1, y1, eave), (x1, ym, eave + rise)],
             [(0, 1, 2), (3, 4, 5)], "wood")
    box(prefix + "roof_ridge", xa, ym - 0.12, eave + rise - 0.05, xb, ym + 0.12, eave + rise + 0.12, mat + "_d")


def window(prefix, x, y, z, w=0.9, h=1.2, lit=None, shutters="shut_teal"):
    lit = rnd.random() < 0.45 if lit is None else lit
    box(prefix + "win_frame", x - w / 2 - 0.1, y - 0.1, z - 0.1, x + w / 2 + 0.1, y + 0.02, z + h + 0.1, "wood_d")
    box(prefix + "win", x - w / 2, y - 0.14, z, x + w / 2, y - 0.08, z + h, "glow" if lit else "glass")
    box(prefix + "win_sill", x - w / 2 - 0.18, y - 0.25, z - 0.18, x + w / 2 + 0.18, y, z - 0.06, "stone")
    if shutters:
        box(prefix + "shutter", x - w / 2 - 0.5, y - 0.12, z, x - w / 2 - 0.08, y - 0.04, z + h, shutters)
        box(prefix + "shutter", x + w / 2 + 0.08, y - 0.12, z, x + w / 2 + 0.5, y - 0.04, z + h, shutters)
    if rnd.random() < 0.35:  # jardinière fleurie
        box(prefix + "planter", x - w / 2, y - 0.45, z - 0.35, x + w / 2, y - 0.15, z - 0.1, "wood")
        for k in range(3):
            sphere(prefix + "flower", x - w / 3 + k * w / 3, y - 0.3, z - 0.02, 0.16,
                   rnd.choice(["fruit_r", "fruit_y", "leaf", "cloth_cream"]))


def awning(prefix, x0, x1, y, z, depth=1.6, colors=("cloth_red", "cloth_cream")):
    """Auvent rayé qui descend vers la rue (vers le sud)."""
    n = max(2, int((x1 - x0) / 0.6))
    for k in range(n):
        xa = x0 + (x1 - x0) * k / n
        xb = x0 + (x1 - x0) * (k + 1) / n
        add_mesh(prefix + "awning", [(xa, y, z), (xb, y, z), (xb, y - depth, z - 0.7), (xa, y - depth, z - 0.7)],
                 [(0, 1, 2, 3)], colors[k % 2])
    for k in range(n):  # festons
        xa = x0 + (x1 - x0) * k / n
        add_mesh(prefix + "awning_flap", [(xa, y - depth, z - 0.7), (xa + (x1 - x0) / n, y - depth, z - 0.7),
                                         (xa + (x1 - x0) / (2 * n), y - depth - 0.02, z - 1.0)], [(0, 1, 2)], colors[k % 2])


def hanging_sign(prefix, x, y, z, icon, mat="wood_l"):
    box(prefix + "sign_arm", x - 0.05, y - 1.1, z, x + 0.05, y, z + 0.08, "iron")
    box(prefix + "sign", x - 0.05, y - 1.05, z - 0.95, x + 0.05, y - 0.35, z - 0.1, mat)
    cx, cz = y - 0.7, z - 0.52  # le panneau est vu de face (plan x = constant) : on le tourne
    # icône peinte sur le panneau : on la pose en relief sur la face sud d'un second panneau visible
    box(prefix + "sign_face", x - 0.42, y - 1.12, z - 1.0, x + 0.42, y - 1.06, z - 0.05, mat)
    ix, iy, iz = x, y - 1.14, z - 0.52
    if icon == "anchor":
        box(prefix + "icon", ix - 0.04, iy - 0.02, iz - 0.3, ix + 0.04, iy, iz + 0.3, "iron")
        box(prefix + "icon", ix - 0.22, iy - 0.02, iz + 0.18, ix + 0.22, iy, iz + 0.24, "iron")
        box(prefix + "icon", ix - 0.26, iy - 0.02, iz - 0.3, ix + 0.26, iy, iz - 0.22, "iron")
    elif icon == "scissors":
        box(prefix + "icon", ix - 0.25, iy - 0.02, iz - 0.04, ix + 0.25, iy, iz + 0.04, "iron", math.radians(35))
        box(prefix + "icon", ix - 0.25, iy - 0.02, iz - 0.04, ix + 0.25, iy, iz + 0.04, "iron", math.radians(-35))
        cyl(prefix + "icon_ring", ix - 0.2, iy - 0.01, iz - 0.22, iz - 0.12, 0.08, "iron", 8)
    elif icon == "sail":
        add_mesh(prefix + "icon", [(ix - 0.05, iy - 0.02, iz + 0.32), (ix + 0.28, iy - 0.02, iz - 0.25), (ix - 0.05, iy - 0.02, iz - 0.25)],
                 [(0, 1, 2)], "cloth_cream")
        box(prefix + "icon", ix - 0.1, iy - 0.02, iz - 0.32, ix - 0.04, iy, iz + 0.34, "wood_d")
    elif icon == "barrel":
        cyl(prefix + "icon", ix, iy - 0.06, iz - 0.28, iz + 0.28, 0.2, "wood", 10)
    elif icon == "mug":
        box(prefix + "icon", ix - 0.18, iy - 0.02, iz - 0.25, ix + 0.14, iy, iz + 0.22, "fruit_y")
        box(prefix + "icon", ix + 0.14, iy - 0.02, iz - 0.12, ix + 0.26, iy, iz + 0.1, "fruit_y")
        box(prefix + "icon", ix - 0.2, iy - 0.03, iz + 0.16, ix + 0.16, iy, iz + 0.3, "cloth_cream")


def lantern(prefix, x, y, z):
    box(prefix + "lantern_arm", x - 0.04, y - 0.5, z + 0.35, x + 0.04, y, z + 0.42, "iron")
    box(prefix + "lantern", x - 0.13, y - 0.6, z, x + 0.13, y - 0.34, z + 0.34, "glow")


def building(bid, x0, x1, y0, y1, floors, wall, roof, shutters="shut_teal", timber=False, balcony=False,
             shop=None, icon=None, awning_colors=None, roof_rise=2.4):
    """Maison ou boutique : façade sud détaillée (fenêtres, volets, porte, enseigne, auvent)."""
    start = len(parts)
    _building_body(bid, x0, x1, y0, y1, floors, wall, roof, shutters, timber, balcony, shop, icon, awning_colors, roof_rise)
    GROUPS[f"bldg_{bid}"] = parts[start:]


GROUPS: dict = {}  # nom du groupe -> objets à fusionner (un bâtiment = un seul objet dans le jeu)


def _building_body(bid, x0, x1, y0, y1, floors, wall, roof, shutters, timber, balcony, shop, icon, awning_colors,
                   roof_rise):
    p = f"bldg_{bid}_"
    gh, uh = 3.3, 2.9                     # hauteur du rez-de-chaussée, des étages
    top = gh + uh * (floors - 1)
    box(p + "walls", x0, y0, 0.0, x1, y1, top, wall)
    box(p + "base", x0 - 0.06, y0 - 0.08, 0.0, x1 + 0.06, y1 + 0.06, 0.55, "stone")
    for f in range(1, floors):           # bandeaux entre étages
        z = gh + uh * (f - 1)
        box(p + "band", x0 - 0.08, y0 - 0.12, z - 0.12, x1 + 0.08, y0 + 0.02, z + 0.06, "wood")
    box(p + "cornice", x0 - 0.12, y0 - 0.18, top - 0.2, x1 + 0.12, y0 + 0.02, top, "wood_d")
    for xc in (x0 + 0.08, x1 - 0.08):    # chaînes d'angle
        box(p + "corner", xc - 0.18, y0 - 0.1, 0.0, xc + 0.18, y0 + 0.02, top, "stone" if not timber else "wood_d")
    if timber:                           # colombages sur les étages
        z0 = gh
        x = x0 + 1.2
        while x < x1 - 0.8:
            box(p + "timber", x - 0.08, y0 - 0.1, z0, x + 0.08, y0 + 0.01, top - 0.2, "wood_d")
            x += 1.6
    w = x1 - x0
    n_win = max(1, int(w / 2.4))
    xs = [x0 + w * (k + 0.5) / n_win for k in range(n_win)]
    door_x = xs[len(xs) // 2] if not shop else (x0 + x1) / 2
    for f in range(floors):              # fenêtres
        z = 0.9 if f == 0 else gh + uh * (f - 1) + 0.75
        for x in xs:
            if f == 0 and (abs(x - door_x) < 1.2 or shop):
                continue
            window(p, x, y0, z, shutters=shutters)
    if shop:                             # devanture : large vitrine éclairée et porte
        box(p + "shopfront", x0 + 0.6, y0 - 0.14, 0.55, x1 - 0.6, y0 + 0.02, 2.7, "wood")
        box(p + "shop_win", x0 + 0.9, y0 - 0.2, 1.0, door_x - 0.9, y0 - 0.1, 2.4, "glow")
        box(p + "shop_win", door_x + 0.9, y0 - 0.2, 1.0, x1 - 0.9, y0 - 0.1, 2.4, "glow")
        box(p + "door", door_x - 0.6, y0 - 0.2, 0.0, door_x + 0.6, y0 - 0.1, 2.3, "wood_d")
        box(p + "door_glow", door_x - 0.45, y0 - 0.22, 0.2, door_x + 0.45, y0 - 0.18, 2.05, "glow")
        awning(p, x0 + 0.4, x1 - 0.4, y0, 3.0, 1.7, awning_colors or ("cloth_red", "cloth_cream"))
        if icon:
            hanging_sign(p, x1 - 0.9, y0, 4.1, icon)
        lantern(p, door_x - 1.0, y0, 2.4)
        lantern(p, door_x + 1.0, y0, 2.4)
        NPCS[shop] = (door_x, y0 - 1.6)
    else:
        box(p + "door", door_x - 0.55, y0 - 0.16, 0.0, door_x + 0.55, y0 - 0.06, 2.2, rnd.choice(["wood_d", "shut_teal", "shut_red"]))
        box(p + "door_step", door_x - 0.8, y0 - 0.6, 0.0, door_x + 0.8, y0, 0.15, "stone")
        if rnd.random() < 0.6:
            lantern(p, door_x + 0.9, y0, 2.3)
    if balcony and floors > 1:
        z = gh + 0.05
        box(p + "balcony", x0 + 0.8, y0 - 1.0, z - 0.15, x1 - 0.8, y0, z, "wood")
        x = x0 + 0.85
        while x < x1 - 0.8:
            box(p + "baluster", x, y0 - 0.98, z, x + 0.08, y0 - 0.9, z + 0.9, "wood_d")
            x += 0.35
        box(p + "rail", x0 + 0.8, y0 - 1.02, z + 0.88, x1 - 0.8, y0 - 0.88, z + 0.98, "wood_d")
    gable_roof(p, x0, x1, y0, y1, top, roof_rise, roof)
    cx = x0 + w * rnd.uniform(0.2, 0.8)  # cheminée
    box(p + "chimney", cx - 0.35, (y0 + y1) / 2 + 0.6, top, cx + 0.35, (y0 + y1) / 2 + 1.3, top + roof_rise + 0.9, "stone")
    OBST.append((x0 - 0.1, y0 - 0.3, x1 + 0.1, y1 + 0.1))


# --- rangée sud (sur le quai)
building("tailleur", -31, -21, 6, 15, 2, "pl_rose", "roof_slate", "shut_blue", timber=True, balcony=True,
         shop="tailor", icon="scissors", awning_colors=("cloth_blue", "cloth_cream"))
building("magasin", -18, -7, 6, 15, 2, "pl_ochre", "roof_terra", "shut_teal",
         shop="store", icon="barrel", awning_colors=("cloth_green", "cloth_cream"))
building("maison_e1", 29, 38, 6, 15, 3, "pl_teal", "roof_terra", "shut_red", balcony=True)
building("maison_w1", -41, -33, 6, 15, 3, "pl_cream", "roof_green", "shut_red")
# --- rangée nord (sur la place)
# (12/11 : les maisons ordinaires de cette rangée sont moins profondes, 31,5 au lieu de 33 : la rue de derrière s'élargit)
building("maison_n1", -31, -20, 24, 31.5, 3, "pl_cream", "roof_terra", "shut_teal", timber=True)
building("taverne", -18, -4, 24, 34, 3, "pl_terra", "roof_slate", "shut_red", balcony=True,
         shop="tavern", icon="mug", awning_colors=("cloth_red", "cloth_yellow"))
building("voilerie", -2, 9, 24, 33, 2, "pl_white", "roof_green", "shut_blue",
         shop="sails", icon="sail", awning_colors=("cloth_blue", "cloth_cream"))
building("maison_n2", 11, 20, 24, 31.5, 3, "pl_ochre", "roof_slate", "shut_teal", balcony=True)
building("maison_n3", 22, 31, 24, 31.0, 2, "pl_rose", "roof_terra", "shut_blue", timber=True)
building("maison_n4", 33, 41, 24, 31.5, 3, "pl_cream", "roof_green", "shut_red")
# --- rangée du fond (plus haute)
for k, (x0, x1, f, wall, roof) in enumerate([(-41, -32, 4, "pl_ochre", "roof_terra"), (-30, -19, 3, "pl_teal", "roof_slate"),
                                             (-17, -6, 4, "pl_rose", "roof_terra"), (-4, 6, 3, "pl_cream", "roof_slate"),
                                             (8, 19, 4, "pl_terra", "roof_green"), (21, 31, 3, "pl_white", "roof_terra"),
                                             (33, 41, 4, "pl_teal", "roof_slate")]):
    # (12/11 : deux étages au plus — à trois ou quatre, collées derrière la rangée nord, elles écrasaient la rue et cachaient tout)
    building(f"fond{k}", x0, x1, 37, 45, min(f, 2), wall, roof, rnd.choice(["shut_teal", "shut_red", "shut_blue"]),
             timber=k % 2 == 0, balcony=k % 3 == 1)

# --- chantier naval : grande halle ouverte sur le quai, avec une coque en construction
CH = (11.0, 27.0, 6.0, 17.0)
p = "bldg_chantier_"
_ch_start = len(parts)
box(p + "back", CH[0], CH[3] - 0.4, 0.0, CH[1], CH[3], 6.0, "wood")
box(p + "side", CH[0], CH[2], 0.0, CH[0] + 0.4, CH[3], 6.0, "wood")
box(p + "side", CH[1] - 0.4, CH[2], 0.0, CH[1], CH[3], 6.0, "wood")
for x in [CH[0] + 0.2 + k * 3.9 for k in range(5)]:
    box(p + "pillar", x - 0.25, CH[2] - 0.2, 0.0, x + 0.25, CH[2] + 0.3, 6.0, "wood_d")
box(p + "beam", CH[0], CH[2] - 0.25, 5.6, CH[1], CH[2] + 0.35, 6.2, "wood_d")
gable_roof(p, CH[0], CH[1], CH[2], CH[3], 6.0, 3.0, "roof_slate")
hanging_sign(p, CH[1] - 1.2, CH[2], 5.2, "anchor")
for k in range(7):                       # membrures d'une coque en chantier
    x = CH[0] + 3.0 + k * 1.6
    for side in (-1, 1):
        for s in range(5):
            a0, a1 = math.pi * s / 10, math.pi * (s + 1) / 10
            r = 2.6
            y0 = 11.5 + side * r * math.cos(a0)
            y1 = 11.5 + side * r * math.cos(a1)
            box(p + "rib", x - 0.1, min(y0, y1), 0.4 + r * math.sin(a0) * 0.9, x + 0.1, max(y0, y1) + 0.12,
                0.55 + r * math.sin(a1) * 0.9, "wood_l")
box(p + "keel", CH[0] + 2.4, 11.35, 0.0, CH[1] - 2.4, 11.65, 0.45, "wood_l")
for k in range(4):                       # piles de planches devant
    box(p + "lumber", CH[0] + 0.8 + k * 0.05, CH[2] - 2.2 + k * 0.0, 0.0 + k * 0.18, CH[0] + 4.0, CH[2] - 1.2, 0.16 + k * 0.18,
        "wood_l" if k % 2 else "wood")
GROUPS["bldg_chantier"] = parts[_ch_start:]
OBST.append((CH[0] - 0.1, CH[2] + 0.2, CH[1] + 0.1, CH[3] + 0.1))
OBST.append((CH[0] + 0.7, CH[2] - 2.3, CH[0] + 4.1, CH[2] - 1.1))
NPCS["shipwright"] = (CH[0] + 6.0, CH[2] - 1.5)

# ====================================================================== place du marché
SQ = (-5.0, 6.0, 9.0, 22.0)


def stall(sid, x, y, colors, goods):
    p = f"stall_{sid}_"
    for dx in (-1.2, 1.2):
        for dy in (-0.6, 0.6):
            cyl(p + "post", x + dx, y + dy, 0.0, 2.4, 0.07, "wood_d", 6)
    box(p + "counter", x - 1.3, y - 0.7, 0.8, x + 1.3, y + 0.7, 1.0, "wood")
    box(p + "front", x - 1.3, y - 0.72, 0.0, x + 1.3, y - 0.62, 0.8, "wood_l")
    for k in range(6):
        xa = x - 1.5 + k * 0.5
        add_mesh(p + "awning", [(xa, y + 0.8, 2.5), (xa + 0.5, y + 0.8, 2.5), (xa + 0.5, y - 1.1, 2.1), (xa, y - 1.1, 2.1)],
                 [(0, 1, 2, 3)], colors[k % 2])
    for k in range(7):                  # marchandises sur le comptoir
        sphere(p + "goods", x - 1.0 + k * 0.33, y + rnd.uniform(-0.3, 0.3), 1.12, 0.14, goods[k % len(goods)])
    OBST.append((x - 1.4, y - 0.8, x + 1.4, y + 0.8))


stall("fruits", -1.5, 12.0, ("cloth_red", "cloth_cream"), ["fruit_r", "fruit_y", "leaf"])
stall("poissons", 5.5, 12.0, ("cloth_blue", "cloth_cream"), ["fish", "fish", "cloth_cream"])
stall("epices", -1.5, 17.5, ("cloth_yellow", "cloth_red"), ["fruit_y", "fruit_r", "wood_l"])
# puits
cyl("well", 5.5, 17.5, 0.0, 0.9, 0.9, "stone", 16)
cyl("well_water", 5.5, 17.5, 0.6, 0.85, 0.7, "glass", 16)
for dx in (-0.8, 0.8):
    box("well_post", 5.5 + dx - 0.08, 17.42, 0.9, 5.5 + dx + 0.08, 17.58, 2.4, "wood_d")
gable_roof("well_", 4.6, 6.4, 17.0, 18.0, 2.4, 0.6, "roof_terra", 0.3)
CIRCLES.append((5.5, 17.5, 1.1))
# tableau des quêtes
QB = (2.0, 20.6)
for dx in (-0.9, 0.9):
    box("quest_post", QB[0] + dx - 0.08, QB[1] - 0.08, 0.0, QB[0] + dx + 0.08, QB[1] + 0.08, 2.4, "wood_d")
box("quest_board", QB[0] - 1.0, QB[1] - 0.06, 0.9, QB[0] + 1.0, QB[1] + 0.06, 2.2, "wood")
for k in range(6):
    px = QB[0] - 0.75 + (k % 3) * 0.55
    pz = 1.15 + (k // 3) * 0.55
    box("quest_paper", px - 0.2, QB[1] - 0.1, pz, px + 0.2, QB[1] - 0.06, pz + 0.42, "paper")
box("quest_roof", QB[0] - 1.2, QB[1] - 0.4, 2.35, QB[0] + 1.2, QB[1] + 0.25, 2.5, "roof_terra")
OBST.append((QB[0] - 1.1, QB[1] - 0.2, QB[0] + 1.1, QB[1] + 0.2))
NPCS["quests"] = (QB[0], QB[1] - 1.2)

# ====================================================================== vie du quai
for x in range(-38, 40, 8):              # réverbères le long du quai
    if 13 < x < 19:
        continue
    cyl("street_lamp", x, 1.4, 0.0, 3.2, 0.08, "iron", 8)
    box("street_lamp_glow", x - 0.2, 1.2, 3.2, x + 0.2, 1.6, 3.65, "glow")
    box("street_lamp_cap", x - 0.26, 1.14, 3.65, x + 0.26, 1.66, 3.75, "iron")
    CIRCLES.append((x, 1.4, 0.3))
for x in (-36, -28, -12, 3, 9, 24, 34):  # bittes d'amarrage
    cyl("bollard", x, 0.6, 0.0, 0.55, 0.22, "iron", 10)
    CIRCLES.append((x, 0.6, 0.35))


def crate_pile(x, y, n=4):
    for k in range(n):
        s = rnd.uniform(0.6, 0.9)
        dx, dy = rnd.uniform(-0.6, 0.6), rnd.uniform(-0.5, 0.5)
        z = 0.0 if k < n - 1 else 0.85
        box("crate", x + dx - s / 2, y + dy - s / 2, z, x + dx + s / 2, y + dy + s / 2, z + s, rnd.choice(["wood_l", "wood"]))
    OBST.append((x - 1.1, y - 0.9, x + 1.1, y + 0.9))


def barrels(x, y, n=3):
    for k in range(n):
        bx, by = x + (k % 2) * 0.75, y + (k // 2) * 0.7
        cyl("barrel", bx, by, 0.0, 1.0, 0.36, "wood", 12)
        cyl("barrel_hoop", bx, by, 0.28, 0.36, 0.37, "iron", 12)
        cyl("barrel_hoop", bx, by, 0.66, 0.74, 0.37, "iron", 12)
    OBST.append((x - 0.5, y - 0.5, x + 1.3, y + 1.3))


crate_pile(-33.5, 3.2)
barrels(-16.5, 3.0)
barrels(-8.5, 3.3, 2)
crate_pile(12.5, 3.0, 5)
barrels(26.0, 3.0)
crate_pile(37.0, 3.5)
# filets de pêche suspendus et poissons séchés près du ponton ouest
for k in range(4):
    x = -27 + k * 0.6
    rope("net", (x, 2.2, 2.2), (x + 0.3, 2.2, 0.5), 0.02)
rope("net_bar", (-27.2, 2.2, 2.2), (-24.8, 2.2, 2.2), 0.04, "wood_d")
for k in range(5):
    box("fish_dry", -26.8 + k * 0.45, 2.15, 1.3, -26.6 + k * 0.45, 2.25, 1.9, "fish")
# linge tendu entre les maisons du nord et du fond (ruelle)
for x in (-25.0, -11.0, 3.0, 16.0, 27.0):
    z = 6.2
    rope("laundry_line", (x, 33.2, z), (x + 0.4, 37.0, z), 0.02)
    for k in range(4):
        y = 33.6 + k * 0.85
        c = rnd.choice(["cloth_red", "cloth_cream", "cloth_blue", "cloth_yellow", "cloth_green"])
        box("laundry", x + 0.1, y, z - 0.9, x + 0.16, y + 0.55, z - 0.02, c)

# ====================================================================== nature


def palm(x, y, h=6.0, lean=0.0):
    segs = 6
    pts = []
    for s in range(segs + 1):
        t = s / segs
        pts.append((x + lean * t * t * h * 0.25, y, h * t))
    for s in range(segs):
        rope("palm_trunk", pts[s], pts[s + 1], 0.22 - 0.02 * s, "trunk")
    top = pts[-1]
    for k in range(8):
        a = k / 8 * math.tau + rnd.uniform(-0.2, 0.2)
        tip = (top[0] + math.cos(a) * 2.6, top[1] + math.sin(a) * 2.6, top[2] - 1.0)
        mid = (top[0] + math.cos(a) * 1.3, top[1] + math.sin(a) * 1.3, top[2] + 0.25)
        for (a3, b3) in ((top, mid), (mid, tip)):
            va, vb = Vector(a3), Vector(b3)
            side = Vector((-math.sin(a), math.cos(a), 0)) * 0.42
            add_mesh("palm_leaf", [tuple(va - side * 0.4), tuple(vb - side), tuple(vb + side), tuple(va + side * 0.4)],
                     [(0, 1, 2, 3)], "leaf" if k % 2 else "leaf_d")
    sphere("palm_nuts", top[0], top[1], top[2] - 0.2, 0.3, "trunk")
    CIRCLES.append((x, y, 0.45))


for (x, y, h, lean) in [(-48, 6, 6.5, 1.0), (-52, 16, 7.0, -0.8), (-46, 28, 6.0, 0.6), (-55, 34, 7.5, 1.2),
                        (-44, -4, 5.5, 1.4), (39, 46, 6.0, -0.6), (-37, 48, 6.5, 0.4), (12, 48, 5.8, 0.3)]:
    palm(x, y, h, lean)
for (x, y) in [(-39, 20), (-2, 35.5), (31.5, 20), (-34, 35)]:  # buissons
    for k in range(3):
        sphere("bush", x + rnd.uniform(-0.6, 0.6), y + rnd.uniform(-0.4, 0.4), 0.5, rnd.uniform(0.6, 0.9),
               "leaf" if k % 2 else "leaf_d", 0.8)
    CIRCLES.append((x, y, 1.1))

# ====================================================================== haute ville (12/11/2026, refonte du monde)
# Demande de Jimmy : une ville plus grande, deux ou trois rangées de plus, pas alignées, des chemins sur les côtés, de la
# verdure, rien de rectiligne. La ville basse ne bouge pas (ses boutiques, ses intérieurs, ses escaliers) : la haute ville est
# un plateau au niveau du chemin de ronde (2,4 m), derrière les remparts, où l'on passe par une porte. Maisons décalées et un
# peu tournées, ruelles qui serpentent, jardins, vergers, une placette avec sa fontaine, un clocher pour repère, et une
# colline verte derrière. Le sol est un niveau du jeu (meta « levels ») : ses obstacles ne valent que là-haut.
UP_Z = 2.4
UP = (-41.2, 51.2, 41.2, 92.0)        # le plateau praticable
U_OBST: list = []                      # obstacles du plateau (repère du port)
U_CIRC: list = []
U_DECOR: list = []                     # décor posé par le jeu (TownBuilder) : bancs, réverbères, massifs
PAVED: list = [{"pts": [[2.0, 72.0]], "w": 11.0}]   # ruelles pavées et placette (sons de pas)
_up_start = len(parts)

# le plateau : un massif de terre et de pierre, de la mer (ou du sol de la ville) jusqu'à 2,4 m ; dessus, de l'herbe
box("ground_grass_haute", -42.0, 51.0, -3.2, 42.0, 92.4, UP_Z, "ground_grass")
for sx in (-1, 1):                    # murs de soutènement sur les flancs, comme le quai (pierre, algues, couronnement)
    xo = 42.0 * sx
    xa, xb = (xo - 0.45, xo + 0.02) if sx < 0 else (xo - 0.02, xo + 0.45)
    box("up_wall", min(xa, xb), 51.0, -3.2, max(xa, xb), 92.4, UP_Z - 0.05, "stone")
    box("up_algae", min(xa, xb) - 0.03, 51.0, -1.75, max(xa, xb) + 0.03, 92.4, -1.25, "algae")
    box("up_cap", min(xa, xb) - 0.08, 51.0, UP_Z - 0.1, max(xa, xb) + 0.08, 92.4, UP_Z + 0.05, "stone_d")
# parapets bas sur les bords du plateau (on ne tombe pas sans le vouloir : le bord est aussi la fin du sol praticable)
for (xa, ya, xb, yb) in ((-41.4, 51.4, -41.0, 92.0), (41.0, 51.4, 41.4, 92.0), (-41.4, 91.8, 41.4, 92.3)):
    box("up_parapet", xa, ya, UP_Z, xb, yb, UP_Z + 0.75, "stone")
    box("up_parapet_cap", xa - 0.06, ya - 0.06, UP_Z + 0.75, xb + 0.06, yb + 0.06, UP_Z + 0.85, "stone_d")

# la porte du rempart (le mur du chemin de ronde est dessiné par le jeu ; la porte, ici)
for sx in (-1, 1):
    xa, xb = sorted((sx * 1.8, sx * 2.5))
    box("up_gate_pillar", xa, 50.85, UP_Z, xb, 51.6, UP_Z + 3.6, "stone")
    box("up_gate_cap", xa - 0.1, 50.75, UP_Z + 3.6, xb + 0.1, 51.7, UP_Z + 3.85, "stone_d")
    lantern("up_gate_", sx * 2.15, 50.85, UP_Z + 2.4)
for k in range(9):                    # l'arc : des claveaux sur un demi-cercle
    a0, a1 = math.pi * k / 9, math.pi * (k + 1) / 9
    xa, xb = -1.8 * math.cos(a0), -1.8 * math.cos(a1)
    za, zb = UP_Z + 2.7 + 1.0 * math.sin(a0), UP_Z + 2.7 + 1.0 * math.sin(a1)
    box("up_gate_arch", min(xa, xb) - 0.02, 50.9, min(za, zb) - 0.05, max(xa, xb) + 0.02, 51.55, max(za, zb) + 0.3, "stone_d")
box("up_gate_top", -2.5, 50.8, UP_Z + 3.85, 2.5, 51.65, UP_Z + 4.15, "stone")


def smooth_path(pts, steps=6):
    """Catmull-Rom : une ligne brisée devient une courbe douce."""
    out = []
    P = [pts[0]] + list(pts) + [pts[-1]]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (Vector((*P[j], 0)) for j in (i - 1, i, i + 1, i + 2))
        for s in range(steps):
            t = s / steps
            q = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t ** 3)
            out.append((q.x, q.y))
    out.append(pts[-1])
    return out


def lane(name, pts, width, mat, z=UP_Z + 0.015, border=True):
    """Une ruelle qui serpente : une bande de sol (pavés ou terre battue) le long d'une courbe, bordée de pierres."""
    c = smooth_path(pts)
    if mat == "ground_cobble":        # (le jeu y fait sonner les pas sur la pierre ; ailleurs sur le plateau, sur l'herbe)
        PAVED.append({"pts": [[round(p[0], 2), round(p[1], 2)] for p in c], "w": width})
    left, right = [], []
    for i, p in enumerate(c):
        a = Vector((*c[max(i - 1, 0)], 0))
        b = Vector((*c[min(i + 1, len(c) - 1)], 0))
        d = (b - a).normalized()
        n = Vector((-d.y, d.x, 0))
        w = width * (1.0 + 0.1 * math.sin(i * 0.22))   # largeur qui respire un peu (lentement : sinon les bords font des dents)
        left.append(Vector((*p, z)) + n * w / 2)
        right.append(Vector((*p, z)) - n * w / 2)
    verts, faces = [], []
    for i in range(len(c)):
        verts += [tuple(left[i]), tuple(right[i])]
    for i in range(len(c) - 1):
        faces.append((2 * i, 2 * i + 1, 2 * i + 3, 2 * i + 2))
    add_mesh(name, verts, faces, mat)
    if border:
        for side in (left, right):
            for i in range(0, len(side) - 1, 2):
                pa, pb = side[i], side[min(i + 2, len(side) - 1)]
                if (pb - pa).length < 0.05:
                    continue
                m = (pa + pb) / 2
                bpy.ops.mesh.primitive_cube_add(location=(m.x, m.y, z + 0.04))
                ob = bpy.context.active_object
                ob.scale = ((pb - pa).length / 2 + 0.05, 0.11, 0.06)
                ob.rotation_euler = (0, 0, math.atan2(pb.y - pa.y, pb.x - pa.x))
                ob.name = "up_curb"
                ob.data.materials.append(MAT["stone"])
                parts.append(ob)


# les ruelles : la grand-rue part de la porte, serpente jusqu'à la placette, puis monte vers le fond ; deux ruelles partent
# vers l'ouest et vers l'est ; des sentiers de terre battue mènent aux jardins
lane("ground_cobble_up_main", [(0, 51.0), (1.5, 56), (-1.5, 61), (0.5, 66.5), (2.0, 70)], 3.6, "ground_cobble")
lane("ground_cobble_up_main_n", [(2.0, 74), (-0.5, 79), (1.5, 84), (0.5, 91.6)], 3.2, "ground_cobble")
lane("ground_cobble_up_west", [(-3.0, 69.5), (-9, 67.5), (-17, 69.0), (-24, 66.5), (-31, 68.5), (-39, 66.0)], 2.8, "ground_cobble")
lane("ground_cobble_up_east", [(7.5, 73.5), (14, 75.5), (21, 73.5), (28, 76.0), (35, 74.5), (40.5, 76.0)], 2.8, "ground_cobble")
lane("ground_sand_up_p1", [(-24, 66), (-23, 62), (-26, 58.5), (-24, 54)], 1.4, "ground_sand", UP_Z + 0.02, False)
lane("ground_sand_up_p2", [(-27.5, 69), (-27.5, 74), (-25.5, 78.5), (-28.5, 83), (-27, 90)], 1.4, "ground_sand", UP_Z + 0.02, False)
lane("ground_sand_up_p3", [(16, 75), (15.5, 70), (18.5, 66), (16.5, 61), (17, 53)], 1.4, "ground_sand", UP_Z + 0.02, False)
lane("ground_sand_up_p4", [(28, 76), (27.5, 80), (29.5, 84), (27.5, 90)], 1.3, "ground_sand", UP_Z + 0.02, False)
# la placette : un disque de pavés autour d'une fontaine
_sq = (2.0, 72.0)
n_ = 28
verts = [(_sq[0], _sq[1], UP_Z + 0.02)] + [(_sq[0] + 6.2 * math.cos(2 * math.pi * k / n_) * (1 + 0.05 * math.sin(k * 1.3)),
                                            _sq[1] + 5.4 * math.sin(2 * math.pi * k / n_) * (1 + 0.05 * math.cos(k * 1.7)),
                                            UP_Z + 0.02) for k in range(n_)]
add_mesh("ground_cobble_up_square", verts, [(0, 1 + k, 1 + (k + 1) % n_) for k in range(n_)], "ground_cobble")
cyl("up_fountain", _sq[0], _sq[1], UP_Z, UP_Z + 0.65, 1.7, "stone", 20)
cyl("up_fountain_water", _sq[0], _sq[1], UP_Z + 0.5, UP_Z + 0.62, 1.5, "glass", 20)
cyl("up_fountain_pillar", _sq[0], _sq[1], UP_Z + 0.5, UP_Z + 1.9, 0.28, "stone", 10)
cyl("up_fountain_bowl", _sq[0], _sq[1], UP_Z + 1.8, UP_Z + 2.1, 0.75, "stone_d", 14, 0.95)
sphere("up_fountain_top", _sq[0], _sq[1], UP_Z + 2.35, 0.25, "gold")
U_CIRC.append((_sq[0], _sq[1], 1.9))
U_DECOR += [["bench", _sq[0] - 4.2, _sq[1] - 2.6], ["bench", _sq[0] + 4.4, _sq[1] - 2.4]]


def up_building(bid, x0, x1, y0, y1, floors, wall, roof, rot_deg=0.0, **kw):
    """Une maison de la haute ville : la maison ordinaire, posée sur le plateau et tournée de quelques degrés."""
    start = len(parts)
    n_obst = len(OBST)
    _building_body(bid, x0, x1, y0, y1, floors, wall, roof, kw.get("shutters", rnd.choice(["shut_teal", "shut_red", "shut_blue"])),
                   kw.get("timber", False), kw.get("balcony", False), None, None, None, kw.get("roof_rise", 2.6))
    del OBST[n_obst:]                 # (ses obstacles vont dans le niveau du plateau, pas au sol de la ville basse)
    a = math.radians(rot_deg)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    ca, sa = math.cos(a), math.sin(a)
    for ob in parts[start:]:
        lx, ly = ob.location.x - cx, ob.location.y - cy
        ob.location.x = cx + lx * ca - ly * sa
        ob.location.y = cy + lx * sa + ly * ca
        ob.location.z += UP_Z
        ob.rotation_euler.z += a
    GROUPS[f"bldg_{bid}"] = parts[start:]
    # obstacle : la boîte englobante du rectangle tourné (avec le perron devant la porte)
    corners = [(x0 - 0.1, y0 - 0.35), (x1 + 0.1, y0 - 0.35), (x1 + 0.1, y1 + 0.1), (x0 - 0.1, y1 + 0.1)]
    rc = [(cx + (px - cx) * ca - (py - cy) * sa, cy + (px - cx) * sa + (py - cy) * ca) for px, py in corners]
    U_OBST.append((min(p[0] for p in rc), min(p[1] for p in rc), max(p[0] for p in rc), max(p[1] for p in rc)))


# les maisons (façade et porte au sud, vers la caméra) : tailles, hauteurs, couleurs et angles variés
up_building("haut_so1", -24.5, -15.0, 53.6, 60.5, 2, "pl_white", "roof_terra", 4, timber=True)
up_building("haut_se1", 5.6, 13.6, 56.2, 62.6, 2, "pl_rose", "roof_slate", -5, balcony=True)
up_building("haut_se2", 19.6, 29.6, 54.4, 62.4, 3, "pl_ochre", "roof_terra", 3, balcony=True)
up_building("haut_se3", 31.5, 39.5, 57.5, 65.0, 2, "pl_teal", "roof_green", -3, timber=True)
up_building("haut_no1", -38.5, -30.0, 71.6, 79.0, 2, "pl_cream", "roof_slate", 5)
up_building("haut_no2", -25.0, -15.5, 71.2, 78.6, 3, "pl_terra", "roof_green", -4, balcony=True)
up_building("haut_no3", -13.0, -5.8, 72.6, 79.6, 2, "pl_ochre", "roof_terra", 2, timber=True)
up_building("haut_no4", -38.0, -30.5, 83.6, 90.4, 2, "pl_rose", "roof_terra", -3)
up_building("haut_no5", -24.0, -12.0, 84.2, 90.6, 3, "pl_cream", "roof_slate", 6, timber=True)
up_building("haut_no6", -9.5, -3.6, 83.0, 89.4, 2, "pl_teal", "roof_terra", -6)
up_building("haut_ne1", 6.5, 15.0, 80.4, 87.6, 2, "pl_white", "roof_green", -3, balcony=True)
up_building("haut_ne2", 18.0, 26.0, 81.0, 89.0, 3, "pl_rose", "roof_slate", 4)
up_building("haut_ne3", 30.5, 39.0, 80.0, 87.0, 2, "pl_ochre", "roof_terra", -2, timber=True)

# le clocher : une tour haute et étroite sur la placette, le repère de la haute ville vu du port
_bt = (9.6, 64.2, 13.4, 68.0)
_t0 = len(parts)
box("bldg_clocher_tower", _bt[0], _bt[1], UP_Z, _bt[2], _bt[3], UP_Z + 11.0, "pl_white")
box("bldg_clocher_base", _bt[0] - 0.1, _bt[1] - 0.1, UP_Z, _bt[2] + 0.1, _bt[3] + 0.1, UP_Z + 0.7, "stone")
for zb in (4.0, 8.0):
    box("bldg_clocher_band", _bt[0] - 0.12, _bt[1] - 0.12, UP_Z + zb - 0.1, _bt[2] + 0.12, _bt[3] + 0.12, UP_Z + zb + 0.15, "stone")
box("bldg_clocher_door", 11.5 - 0.6, _bt[1] - 0.12, UP_Z, 11.5 + 0.6, _bt[1] - 0.05, UP_Z + 2.4, "wood_d")
box("bldg_clocher_belfry", _bt[0] + 0.7, _bt[1] - 0.06, UP_Z + 8.8, _bt[2] - 0.7, _bt[1] + 0.02, UP_Z + 10.4, "glass")
cyl("bldg_clocher_bell", 11.5, (_bt[1] + _bt[3]) / 2, UP_Z + 9.1, UP_Z + 10.0, 0.55, "gold", 12, 0.25)
box("bldg_clocher_clock", 11.5 - 0.6, _bt[1] - 0.1, UP_Z + 6.3, 11.5 + 0.6, _bt[1] - 0.04, UP_Z + 7.5, "paper")
bpy.ops.mesh.primitive_cone_add(vertices=4, radius1=2.95, radius2=0.0, depth=3.6, location=(11.5, 66.1, UP_Z + 12.8),
                                rotation=(0, 0, math.pi / 4))
_ob = bpy.context.active_object
_ob.name = "bldg_clocher_spire"
_ob.data.materials.append(MAT["roof_slate"])
parts.append(_ob)
box("bldg_clocher_eave", _bt[0] - 0.3, _bt[1] - 0.3, UP_Z + 10.9, _bt[2] + 0.3, _bt[3] + 0.3, UP_Z + 11.1, "wood_d")
cyl("bldg_clocher_vane", 11.5, 66.1, UP_Z + 14.4, UP_Z + 15.6, 0.04, "iron", 6)
box("bldg_clocher_vane_flag", 11.5, 66.06, UP_Z + 15.1, 12.3, 66.14, UP_Z + 15.5, "gold")
GROUPS["bldg_clocher"] = parts[_t0:]
U_OBST.append((_bt[0] - 0.15, _bt[1] - 0.3, _bt[2] + 0.15, _bt[3] + 0.15))


def tree(x, y, h=4.2, r=1.7, z=UP_Z, kind="leaf"):
    """Un arbre feuillu (manguier, figuier) : tronc et houppier en trois boules."""
    cyl("up_tree_trunk", x, y, z, z + h * 0.62, 0.2, "trunk", 8, 0.14)
    for k in range(3):
        a = k / 3 * math.tau + rnd.uniform(0, 1)
        sphere("up_tree_crown", x + math.cos(a) * r * 0.45, y + math.sin(a) * r * 0.45, z + h * 0.75 + rnd.uniform(-0.2, 0.3),
               r * rnd.uniform(0.72, 0.9), kind if k != 1 else "leaf_d", 0.82)
    sphere("up_tree_crown", x, y, z + h * 0.95, r * 0.7, kind, 0.8)
    U_CIRC.append((x, y, 0.45))


def hedge(x0, y0, x1, y1):
    box("up_hedge", x0, y0, UP_Z, x1, y1, UP_Z + 0.75, "leaf_d")
    U_OBST.append((x0, y0, x1, y1))


def fence(x0, y0, x1, y1, gap=None):
    """Palissade de bois le long d'un côté (droit selon x ou y), avec une ouverture facultative (début, fin)."""
    horiz = abs(y1 - y0) < 1e-3
    L_ = (x1 - x0) if horiz else (y1 - y0)
    n = max(1, int(L_ / 0.45))
    for k in range(n + 1):
        t = k / n
        px, py = x0 + (x1 - x0) * t, y0 + (y1 - y0) * t
        along = px if horiz else py
        if gap and gap[0] < along < gap[1]:
            continue
        box("up_fence_post", px - 0.05, py - 0.05, UP_Z, px + 0.05, py + 0.05, UP_Z + 0.9 + 0.08 * (k % 2), "wood_l")
    segs = [(x0 if horiz else y0, gap[0]), (gap[1], x1 if horiz else y1)] if gap else [(x0 if horiz else y0, x1 if horiz else y1)]
    for a_, b_ in segs:
        for zr in (0.35, 0.72):
            if horiz:
                box("up_fence_rail", a_, y0 - 0.03, UP_Z + zr, b_, y0 + 0.03, UP_Z + zr + 0.06, "wood")
            else:
                box("up_fence_rail", x0 - 0.03, a_, UP_Z + zr, x0 + 0.03, b_, UP_Z + zr + 0.06, "wood")
        U_OBST.append((a_, y0 - 0.12, b_, y0 + 0.12) if horiz else (x0 - 0.12, a_, x0 + 0.12, b_))


def veg_bed(x0, y0, x1, y1, crop):
    """Un carré de potager : terre sombre, rangées de plants."""
    box("up_bed_soil", x0, y0, UP_Z, x1, y1, UP_Z + 0.12, "trunk")
    y = y0 + 0.35
    while y < y1 - 0.2:
        x = x0 + 0.3
        while x < x1 - 0.2:
            sphere("up_bed_plant", x, y, UP_Z + 0.24, 0.2, crop if rnd.random() < 0.8 else "leaf_d", 0.7)
            x += 0.55
        y += 0.6


def flowers(x, y, n=6, spread=1.2):
    for k in range(n):
        sphere("up_flower", x + rnd.uniform(-spread, spread), y + rnd.uniform(-spread * 0.6, spread * 0.6), UP_Z + 0.25,
               rnd.uniform(0.18, 0.3), rnd.choice(["fruit_r", "fruit_y", "cloth_cream", "cloth_red", "leaf"]), 0.75)


# potager clos au sud-ouest (palissade, portillon sur le sentier), et sa cabane à outils
fence(-37.5, 53.0, -28.0, 53.0)
fence(-37.5, 53.0, -37.5, 61.0)
fence(-37.5, 61.0, -28.0, 61.0)
fence(-28.0, 53.0, -28.0, 61.0, gap=(56.0, 57.6))
for (bx, by, crop) in ((-36.6, 54.0, "leaf"), (-32.6, 54.0, "fruit_r"), (-36.6, 57.4, "fruit_y"), (-32.6, 57.4, "leaf")):
    veg_bed(bx, by, bx + 3.2, by + 2.6, crop)
U_OBST.append((-37.0, 53.4, -28.6, 60.6))
box("up_shed", -31.0, 59.0, UP_Z, -28.6, 60.6, UP_Z + 2.0, "wood")
gable_roof("up_shed_", -31.0, -28.6, 59.0, 60.6, UP_Z + 2.0, 0.7, "roof_terra", 0.2)
# verger au sud de la grand-rue (à l'ouest) et jardins fleuris devant les maisons
for (x, y) in ((-11.5, 54.5), (-7.5, 57.5), (-12.0, 60.0), (-5.5, 53.5)):
    tree(x, y, rnd.uniform(3.8, 4.8), rnd.uniform(1.5, 1.9), kind="leaf")
for (x, y) in ((-21.0, 52.4), (-17.0, 52.6), (9.5, 54.4), (24.5, 52.6), (35.5, 55.8), (-34.0, 69.8), (-20.5, 69.8),
               (11.0, 78.8), (22.0, 79.4), (34.5, 78.8), (-30.0, 81.8), (-17.0, 82.4)):
    flowers(x, y, 7, 1.3)
hedge(26.5, 52.3, 33.0, 52.9)
hedge(-14.5, 81.6, -10.5, 82.2)
# arbres le long des ruelles et sur la placette, palmiers dans les coins
for (x, y) in ((-4.5, 75.5), (8.0, 68.0), (-6.5, 63.5), (16.0, 65.0), (24.0, 69.0), (37.5, 69.5), (-36.0, 64.0), (-15.5, 64.0),
               (4.5, 79.0), (-1.5, 87.0), (38.5, 90.0), (13.0, 90.4)):
    tree(x, y, rnd.uniform(3.6, 5.0), rnd.uniform(1.3, 1.8), kind=rnd.choice(["leaf", "leaf_d"]))
for (x, y, h, lean) in ((-39.5, 88.5, 6.5, 0.8), (40.0, 54.0, 6.0, -0.9), (6.0, 52.8, 5.5, 0.6), (-40.0, 54.0, 6.2, 0.5)):
    _p0 = len(parts)
    palm(x, y, h, lean)
    for ob in parts[_p0:]:
        ob.location.z += UP_Z
    CIRCLES.pop()                     # (palm() l'a ajouté au sol de la ville basse)
    U_CIRC.append((x, y, 0.45))
# réverbères le long de la grand-rue et des ruelles, quelques tonneaux et bancs
U_DECOR += [["lamp", 3.6, 58.5], ["lamp", -2.2, 64.5], ["lamp", -10.0, 70.4], ["lamp", -26.0, 64.6], ["lamp", 14.0, 77.2],
            ["lamp", 29.0, 74.2], ["lamp", 3.4, 82.0], ["bench", -8.0, 61.5], ["bench", 20.5, 70.5],
            ["barrel", -5.0, 80.9], ["barrel", 16.6, 79.9], ["bed", 30.0, 66.6], ["bed", -10.5, 81.0]]
for d in U_DECOR:
    if d[0] in ("barrel", "bench", "bed"):
        U_CIRC.append((d[1], d[2], 0.5 if d[0] == "barrel" else 0.9))

# la colline derrière le plateau : une pente d'herbe qui monte vers le nord et retombe dans la mer sur les côtés, avec des
# arbres et un moulin au sommet (décor : on n'y marche pas)
nx_, ny_ = 30, 16
hv, hf = [], []
for j in range(ny_ + 1):
    y = 92.0 + j * 2.6
    for i in range(nx_ + 1):
        x = -66.0 + i * (132.0 / nx_)
        side = max(0.0, min(1.0, (66.0 - abs(x)) / 22.0))
        hgt = UP_Z + (y - 92.0) * 0.36 + 1.6 * math.sin(x * 0.11 + j * 0.7) * min(1.0, (y - 92.0) / 8.0)
        z = -3.0 + (hgt + 3.0) * (side ** 0.7 if abs(x) > 44 else 1.0)
        if j == 0:
            z = UP_Z if abs(x) <= 42.4 else -3.0 + (UP_Z + 3.0) * side
        hv.append((x, y, z))
for j in range(ny_):
    for i in range(nx_):
        a = j * (nx_ + 1) + i
        hf.append((a, a + 1, a + nx_ + 2, a + nx_ + 1))
add_mesh("ground_grass_colline", hv, hf, "ground_grass")


def hill_z(x, y):
    i = min(nx_ - 1, max(0, int((x + 66.0) / (132.0 / nx_))))
    j = min(ny_ - 1, max(0, int((y - 92.0) / 2.6)))
    return hv[j * (nx_ + 1) + i][2]


for k in range(46):
    x, y = rnd.uniform(-58, 58), rnd.uniform(95, 132)
    z = hill_z(x, y)
    if z < 0.5:
        continue
    n0 = len(U_CIRC)
    tree(x, y, rnd.uniform(3.5, 5.5), rnd.uniform(1.4, 2.2), z=z - 0.2, kind=rnd.choice(["leaf", "leaf_d"]))
    del U_CIRC[n0:]
# le moulin, au sommet de la colline
_mx, _my = -14.0, 126.0
_mz = hill_z(_mx, _my) - 0.3
cyl("mill_tower", _mx, _my, _mz, _mz + 7.5, 2.2, "pl_white", 14, 1.6)
bpy.ops.mesh.primitive_cone_add(vertices=14, radius1=1.9, radius2=0.2, depth=2.2, location=(_mx, _my, _mz + 8.6))
_ob = bpy.context.active_object
_ob.name = "mill_cap"
_ob.data.materials.append(MAT["roof_terra"])
parts.append(_ob)
for k in range(4):
    a = math.radians(20 + k * 90)
    hub = Vector((_mx, _my - 1.8, _mz + 7.6))
    tip = hub + Vector((math.cos(a) * 5.0, 0, math.sin(a) * 5.0))
    rope("mill_arm", tuple(hub), tuple(tip), 0.09, "wood_d")
    side = Vector((-math.sin(a), 0, math.cos(a))) * 0.7
    mid = hub + (tip - hub) * 0.25
    add_mesh("mill_sail", [tuple(mid), tuple(tip), tuple(tip + side), tuple(mid + side)], [(0, 1, 2, 3)], "cloth_cream")

# ====================================================================== export
for ob in parts:
    if ob.type == "MESH":
        smooth = ob.name.startswith(("palm", "bush", "well", "barrel", "boat_hull", "goods", "flower", "palm_nuts", "up_tree",
                                     "up_flower", "up_bed_plant", "up_fountain", "mill_tower", "mill_cap"))
        for poly in ob.data.polygons:
            poly.use_smooth = smooth

def join_group(name, obs):
    obs = [o for o in obs if o.type == "MESH"]
    if not obs:
        return
    bpy.ops.object.select_all(action="DESELECT")
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    obs[0].name = name


# fusion : un objet par bâtiment, un pour tout le décor ; les sols restent à part (repeints par le jeu)
# positions, rotations et échelles appliquées : les sommets sont en coordonnées du port, ce que les
# shaders du jeu utilisent pour peindre pavés, tuiles et enduits à la bonne échelle
bpy.ops.object.select_all(action="SELECT")
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
all_names = [o.name for o in parts]          # noms relevés AVANT les fusions (les objets fusionnés disparaissent)
grouped = set()
for obs in GROUPS.values():
    grouped.update(o.name for o in obs)
prop_names = [n for n in all_names if n not in grouped and "ground_" not in n]
for name, obs in GROUPS.items():
    join_group(name, obs)
join_group("props", [bpy.data.objects[n] for n in prop_names if n in bpy.data.objects])

OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=str(OUT / "port.glb"), export_format="GLB", use_selection=True)
meta = {
    "walk_rects": [[LAND[0] + 0.5, 0.3, LAND[2] - 0.5, LAND[3] - 0.5],
                   [MAIN_PIER[0] + 0.3, MAIN_PIER[2] + 0.4, MAIN_PIER[1] - 0.3, 0.5],
                   [-23.7, -13.6, -21.3, 0.5],
                   list(UP)],
    "obstacles": OBST, "circles": CIRCLES, "npcs": NPCS,
    # la haute ville : un niveau du jeu (data/town.json en a le même format), ajouté à ceux de la ville au chargement. Le mur du
    # chemin de ronde la sépare des remparts, sauf à la porte (x de -1,8 à 1,8).
    "levels": [{"id": "haute_ville", "rect": list(UP), "h": UP_Z, "solid": True, "style": "none",
                "obstacles": [[round(v, 2) for v in o] for o in U_OBST] + [[UP[0], UP[1] - 0.1, -1.8, UP[1] + 0.3],
                                                                         [1.8, UP[1] - 0.1, UP[2], UP[1] + 0.3]],
                "circles": [[round(v, 2) for v in c] for c in U_CIRC], "decor": U_DECOR}],
    "grass_rect": list(UP), "paved_paths": PAVED,
    "spawn": [2.0, 9.0],
    "dock": {"pier_x1": MAIN_PIER[1], "y": -14.0, "heading": "sud"},
    "sea_z": -1.45,
}
(OUT / "port_meta.json").write_text(json.dumps(meta, indent=1), encoding="utf-8")
print("port exporte :", len(parts), "objets")
