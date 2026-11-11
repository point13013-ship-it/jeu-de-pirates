"""Construit les figures de proue débloquées par la réputation (dragon, lion, aigle, crâne d'or) et les exporte en .glb.

Usage : blender.exe -b --python make_figureheads.py -- <dossier de sortie ABSOLU> [<dossier d'aperçus ABSOLU>]
Chaque figure regarde vers +x (l'étrave), centrée sur l'origine, environ 0,7 unité de long (unités du modèle de bateau, voir
make_ship.py : le jeu la pose à la place du crâne d'origine). Les matières portent leurs propres couleurs : elles ne suivent
pas la teinte de la coque.
"""
import math
import sys
from pathlib import Path

import bpy

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = Path(ARGS[0] if ARGS else ".").resolve()
PREVIEW = Path(ARGS[1]).resolve() if len(ARGS) > 1 else None


bpy.ops.wm.read_factory_settings(use_empty=True)


def make_mat(name, color, rough=0.7, emit=0.0, metal=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*color, 1.0)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = (*color, 1.0)
        b.inputs["Emission Strength"].default_value = emit
    return m


MATS = {
    "gold": make_mat("fh_gold", (0.78, 0.55, 0.12), 0.45, metal=0.5),
    "gold_d": make_mat("fh_gold_d", (0.50, 0.32, 0.07), 0.55, metal=0.4),
    "jade": make_mat("fh_jade", (0.13, 0.50, 0.36), 0.5),
    "jade_d": make_mat("fh_jade_d", (0.07, 0.30, 0.24), 0.55),
    "bone": make_mat("fh_bone", (0.92, 0.88, 0.78), 0.6),
    "dark": make_mat("fh_dark", (0.03, 0.025, 0.04), 0.6),
    "ruby": make_mat("fh_ruby", (0.95, 0.10, 0.12), 0.3, emit=3.0),
    "feather": make_mat("fh_feather", (0.30, 0.18, 0.10), 0.8),
    "feather_l": make_mat("fh_feather_l", (0.55, 0.38, 0.22), 0.8),
    "beak": make_mat("fh_beak", (0.95, 0.72, 0.15), 0.5),
    "eye": make_mat("fh_eye", (1.0, 0.85, 0.2), 0.3, emit=2.0),
}

parts = []


def _add(ob, mat):
    ob.data.materials.append(MATS[mat])
    for p in ob.data.polygons:
        p.use_smooth = True
    parts.append(ob)
    return ob


def sphere(x, y, z, r, mat, sx=1.0, sy=1.0, sz=1.0):
    bpy.ops.mesh.primitive_uv_sphere_add(radius=r, location=(x, y, z), segments=14, ring_count=8)
    ob = bpy.context.active_object
    ob.scale = (sx, sy, sz)
    return _add(ob, mat)


def cone(x, y, z, r1, r2, depth, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cone_add(radius1=r1, radius2=r2, depth=depth, location=(x, y, z), rotation=rot, vertices=12)
    return _add(bpy.context.active_object, mat)


def box(x, y, z, sx, sy, sz, mat, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(location=(x, y, z), rotation=rot)
    ob = bpy.context.active_object
    ob.scale = (sx / 2, sy / 2, sz / 2)
    return _add(ob, mat)


def clear():
    parts.clear()
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)


def horn(x, y, z, side, mat):
    """Une corne qui part vers l'arrière et le haut."""
    cone(x, y, z, 0.07, 0.01, 0.34, mat, rot=(math.radians(-side * 25), math.radians(-115), 0))


# ------------------------------------------------------------------ les quatre figures

def build_dragon():
    sphere(0.0, 0.0, 0.0, 0.24, "jade", 1.15, 1.0, 0.95)            # crâne
    cone(0.42, 0.0, -0.02, 0.17, 0.08, 0.5, "jade", rot=(0, math.radians(90), 0))   # museau
    box(0.36, 0.0, -0.16, 0.5, 0.2, 0.08, "jade_d")                  # mâchoire
    for k in range(4):                                               # dents
        for s in (-1, 1):
            cone(0.28 + k * 0.1, s * 0.07, -0.11, 0.02, 0.0, 0.07, "bone", rot=(math.radians(180), 0, 0))
    for s in (-1, 1):
        sphere(0.12, s * 0.2, 0.1, 0.05, "eye")                      # yeux
        sphere(0.12, s * 0.235, 0.1, 0.022, "dark")
        sphere(0.66, s * 0.04, 0.0, 0.025, "dark")                   # narines
        horn(-0.08, s * 0.1, 0.2, s, "gold")
        # nageoires-joues
        cone(-0.02, s * 0.27, -0.02, 0.1, 0.0, 0.28, "gold_d", rot=(math.radians(-s * 70), math.radians(-100), 0))
    for k in range(5):                                               # crête dorée
        cone(-0.1 + k * 0.12, 0.0, 0.2 - k * 0.012, 0.045, 0.0, 0.14, "gold")
    # cou qui plonge vers l'étrave
    for k in range(4):
        sphere(-0.22 - k * 0.14, 0.0, -0.12 - k * 0.14, 0.17 - k * 0.012, "jade" if k % 2 == 0 else "jade_d")
        cone(-0.22 - k * 0.14, 0.0, -0.02 - k * 0.14, 0.04, 0.0, 0.12, "gold")


def build_lion():
    for k in range(12):                                              # crinière : couronne de touffes
        a = math.tau * k / 12.0
        sphere(0.0, math.cos(a) * 0.3, math.sin(a) * 0.3, 0.13, "gold_d" if k % 2 == 0 else "gold")
    for k in range(10):
        a = math.tau * (k + 0.5) / 10.0
        sphere(-0.07, math.cos(a) * 0.2, math.sin(a) * 0.2, 0.12, "gold" if k % 2 == 0 else "gold_d")
    sphere(0.1, 0.0, 0.0, 0.24, "gold")                              # tête
    sphere(0.3, 0.0, -0.06, 0.15, "gold", 1.2, 1.0, 0.85)           # museau
    sphere(0.43, 0.0, -0.01, 0.045, "dark")                          # truffe
    box(0.34, 0.0, -0.17, 0.26, 0.17, 0.06, "gold_d")                # mâchoire
    for s in (-1, 1):
        sphere(0.28, s * 0.1, 0.1, 0.04, "dark")                     # yeux
        sphere(0.3, s * 0.1, 0.12, 0.012, "eye")
        sphere(0.05, s * 0.24, 0.24, 0.07, "gold_d")                 # oreilles
        cone(0.4, s * 0.05, -0.12, 0.016, 0.0, 0.07, "bone", rot=(math.radians(180), 0, 0))   # crocs
    sphere(-0.28, 0.0, -0.32, 0.22, "gold_d", 1.4, 1.0, 1.0)         # poitrail qui rejoint l'étrave


def build_eagle():
    sphere(0.0, 0.0, 0.0, 0.19, "bone")                              # tête blanche
    cone(0.24, 0.0, -0.04, 0.09, 0.0, 0.3, "beak", rot=(0, math.radians(100), 0))   # bec
    cone(0.19, 0.0, -0.1, 0.045, 0.0, 0.15, "beak", rot=(0, math.radians(125), 0))
    for s in (-1, 1):
        sphere(0.1, s * 0.13, 0.07, 0.045, "eye")
        sphere(0.11, s * 0.15, 0.075, 0.02, "dark")
        # ailes déployées vers l'arrière et les côtés
        for k in range(4):
            cone(-0.1 - k * 0.04, s * (0.22 + k * 0.17), 0.04 - k * 0.04, 0.08 - k * 0.012, 0.0, 0.5 - k * 0.05,
                 "feather" if k % 2 == 0 else "feather_l", rot=(math.radians(-s * 85), math.radians(-100 - k * 8), 0))
    sphere(-0.18, 0.0, -0.18, 0.2, "bone", 1.1, 0.9, 1.2)            # poitrail
    sphere(-0.3, 0.0, -0.36, 0.17, "feather")


def build_goldskull():
    sphere(0.0, 0.0, 0.0, 0.3, "gold", 1.05, 1.0, 1.0)
    box(0.12, 0.0, -0.27, 0.3, 0.3, 0.14, "gold")                    # mâchoire
    for k in range(5):
        box(0.24, -0.1 + k * 0.05, -0.2, 0.02, 0.035, 0.07, "bone")  # dents
    for s in (-1, 1):
        sphere(0.24, s * 0.12, 0.07, 0.085, "dark")                  # orbites
        sphere(0.29, s * 0.12, 0.07, 0.04, "ruby")                   # rubis
    cone(0.31, 0.0, -0.06, 0.04, 0.0, 0.1, "dark", rot=(math.radians(180), 0, 0))   # nez
    for k in range(5):                                               # couronne
        cone(-0.1 + k * 0.0, (k - 2) * 0.11, 0.33, 0.05, 0.0, 0.2, "gold_d")
    box(-0.1, 0.0, 0.29, 0.1, 0.6, 0.06, "gold_d")
    cone(-0.28, 0.0, -0.18, 0.1, 0.0, 0.3, "gold_d", rot=(0, math.radians(135), 0))


BUILDERS = {"dragon": build_dragon, "lion": build_lion, "eagle": build_eagle, "goldskull": build_goldskull}


def setup_preview():
    scene = bpy.context.scene
    try:
        scene.render.engine = "BLENDER_EEVEE"
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE_NEXT"
    scene.render.film_transparent = False
    scene.render.resolution_x = 480
    scene.render.resolution_y = 480
    scene.view_settings.view_transform = "Standard"
    world = bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs["Color"].default_value = (0.30, 0.34, 0.45, 1.0)
    sun = bpy.data.lights.new("sun", "SUN")
    sun.energy = 4.0
    so = bpy.data.objects.new("sun", sun)
    so.rotation_euler = (math.radians(50), math.radians(10), math.radians(-40))
    scene.collection.objects.link(so)
    cam = bpy.data.cameras.new("cam")
    cam.type = "ORTHO"
    cam.ortho_scale = 1.9
    co = bpy.data.objects.new("cam", cam)
    scene.collection.objects.link(co)
    scene.camera = co
    return co


OUT.mkdir(parents=True, exist_ok=True)
if PREVIEW:
    PREVIEW.mkdir(parents=True, exist_ok=True)
for name, build in BUILDERS.items():
    clear()
    build()
    bpy.ops.object.select_all(action="DESELECT")
    for ob in parts:
        ob.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.export_scene.gltf(filepath=str(OUT / f"figurehead_{name}.glb"), export_format="GLB", use_selection=True)
    if PREVIEW:
        co = setup_preview()
        for tag, loc, rot in (("side", (0, -6, 0.0), (math.radians(90), 0, 0)),
                              ("three", (4.2, -4.2, 3.0), (math.radians(65), 0, math.radians(45)))):
            co.location = loc
            co.rotation_euler = rot
            bpy.context.scene.render.filepath = str(PREVIEW / f"{name}_{tag}.png")
            bpy.ops.render.render(write_still=True)
    print("export termine", name)
