"""Convertit des modèles OBJ du lot nature de Quaternius (CC0) en GLB, recolorés dans la palette du jeu.
Usage : blender -b --python obj_to_glb.py -- <dossier OBJ> <dossier de sortie> <nom> [<nom>…]"""
import sys

import bpy

args = sys.argv[sys.argv.index("--") + 1:]
src, dst, names = args[0], args[1], args[2:]
# palette v1 (design/bible-v2.md) : végétation, bois, pierre
PALETTE = {
    "DarkGreen": (0x2D, 0x64, 0x44), "Green": (0x5A, 0x94, 0x40), "LightGreen": (0xA3, 0xC6, 0x50),
    "Coconuts": (0x6A, 0x45, 0x32), "Wood": (0x9C, 0x6A, 0x43), "DarkWood": (0x6A, 0x45, 0x32), "Brown": (0x6A, 0x45, 0x32),
    "Rock": (0x7D, 0x74, 0x88), "DarkRock": (0x4A, 0x42, 0x58), "Stone": (0x7D, 0x74, 0x88),
}


def lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


for name in names:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.wm.obj_import(filepath="%s/%s.obj" % (src, name))
    lo = [1e9, 1e9, 1e9]
    hi = [-1e9, -1e9, -1e9]
    for ob in bpy.context.scene.objects:
        if ob.type != "MESH":
            continue
        for v in ob.bound_box:
            w = ob.matrix_world @ __import__("mathutils").Vector(v)
            for k in range(3):
                lo[k] = min(lo[k], w[k])
                hi[k] = max(hi[k], w[k])
    used = []
    for mat in bpy.data.materials:
        used.append(mat.name)
        mat.use_nodes = True
        bsdf = mat.node_tree.nodes.get("Principled BSDF")
        if bsdf is None:
            continue
        base = mat.name.split(".")[0]
        if base in PALETTE:
            r, g, b = PALETTE[base]
            bsdf.inputs["Base Color"].default_value = (lin(r), lin(g), lin(b), 1.0)
        bsdf.inputs["Roughness"].default_value = 0.95
        if "Specular IOR Level" in bsdf.inputs:
            bsdf.inputs["Specular IOR Level"].default_value = 0.0
    bpy.ops.export_scene.gltf(filepath="%s/%s.glb" % (dst, name), export_format="GLB", export_apply=True)
    print("FAIT %s : taille %.2f x %.2f x %.2f (hauteur z), matières %s" % (name, hi[0] - lo[0], hi[1] - lo[1], hi[2] - lo[2], used))
