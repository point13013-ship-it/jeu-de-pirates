"""Extrait la palette d'une image en pixel art et l'écrit comme tableau de shader Godot.

Usage : python make_palette_shader.py <image.png> <sortie.gdshaderinc> [couleurs_en_plus.json]
Le JSON optionnel ajoute des couleurs (ex. les tons de la mer) et, si « shadow_factor » est donné,
leur version assombrie (le facteur s'applique en lumière linéaire, comme dans le shader).
"""
import json
import sys
from pathlib import Path

from PIL import Image


def to_lin(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def to_srgb(c):
    c = 12.92 * c if c <= 0.0031308 else 1.055 * (c ** (1 / 2.4)) - 0.055
    return int(round(max(0.0, min(1.0, c)) * 255))


img = Image.open(sys.argv[1]).convert("RGB")
colors = set(img.get_flattened_data() if hasattr(img, "get_flattened_data") else img.getdata())
sea = []
if len(sys.argv) > 3:
    extra = json.loads(Path(sys.argv[3]).read_text(encoding="utf-8"))
    factor = extra.get("shadow_factor")
    for r, g, b in extra["colors"]:
        sea.append((r, g, b))
        if factor:
            sea.append(tuple(to_srgb(to_lin(v) * factor) for v in (r, g, b)))
    colors.update(sea)
colors = sorted(colors, key=lambda c: 0.299 * c[0] + 0.587 * c[1] + 0.114 * c[2])
items = ", ".join(f"vec3({r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f})" for r, g, b in colors)
text = (f"// Palette générée par tools/art/make_palette_shader.py depuis {Path(sys.argv[1]).name}"
        f"{' + ' + Path(sys.argv[3]).name if len(sys.argv) > 3 else ''}\n"
        f"const int PALETTE_SIZE = {len(colors)};\n"
        f"const vec3 PALETTE[{len(colors)}] = vec3[]({items});\n")
if sea:
    sea_items = ", ".join(f"vec3({r / 255:.4f}, {g / 255:.4f}, {b / 255:.4f})" for r, g, b in sea)
    text += ("// Tons de la mer : le filtre ne trace pas de contour entre deux d'entre eux\n"
             f"const int SEA_SIZE = {len(sea)};\nconst vec3 SEA[{len(sea)}] = vec3[]({sea_items});\n")
else:
    text += "const int SEA_SIZE = 1;\nconst vec3 SEA[1] = vec3[](vec3(-1.0));\n"
Path(sys.argv[2]).parent.mkdir(parents=True, exist_ok=True)
Path(sys.argv[2]).write_text(text, encoding="utf-8")
print("ok", len(colors), "couleurs")
