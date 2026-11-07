"""Dessine deux pirates de test en pixel art (24x34, pieds en bas au centre).

Usage : python make_pirate_sprites.py <dossier de sortie>
Échelle : 34 pixels de haut pour ~1,9 m, soit 18 pixels par mètre (comme la caméra du jeu).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

BASE_W, BASE_H = 24, 34
# Le dessin est décrit sur une grille 24x34 (18 pixels par mètre) et agrandi par S pour suivre la
# résolution du jeu : S = 24/18 -> 32x45 pour 24 pixels par mètre (toujours ~1,9 m).
S = float(sys.argv[2]) if len(sys.argv) > 2 else 24.0 / 18.0
W, H = round(BASE_W * S), round(BASE_H * S)
OUT = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
OUT.mkdir(parents=True, exist_ok=True)

SKIN = (226, 168, 128)
SKIN_D = (186, 124, 100)
OUTLINE = (24, 14, 30)


def paint(look):
    img = np.zeros((H, W, 4), np.uint8)

    def rect(x0, y0, x1, y1, c):
        # coordonnées de la grille de base -> pixels réels (bords arrondis au pixel le plus proche)
        for y in range(round(y0 * S), max(round((y1 + 1) * S), round(y0 * S) + 1)):
            for x in range(round(x0 * S), max(round((x1 + 1) * S), round(x0 * S) + 1)):
                if 0 <= x < W and 0 <= y < H:
                    img[y, x] = (*c, 255)

    def px(x, y, c):
        rect(x, y, x, y, c)

    coat, coat_d, coat_l = look["coat"], tuple(int(v * 0.68) for v in look["coat"]), tuple(min(255, int(v * 1.3)) for v in look["coat"])
    pants, pants_d = look["pants"], tuple(int(v * 0.7) for v in look["pants"])
    # jambes et bottes
    rect(8, 24, 11, 30, pants)
    rect(13, 24, 16, 30, pants_d)
    rect(8, 29, 11, 33, (44, 28, 38))
    rect(13, 29, 16, 33, (34, 22, 32))
    rect(8, 29, 11, 29, (96, 66, 56))
    rect(13, 29, 16, 29, (80, 56, 50))
    rect(7, 33, 11, 33, (30, 20, 30))
    rect(13, 33, 17, 33, (24, 16, 26))
    # manteau
    rect(7, 13, 17, 25, coat)
    rect(7, 13, 8, 25, coat_l)
    rect(15, 13, 17, 25, coat_d)
    rect(6, 24, 18, 26, coat_d)       # pans du manteau
    rect(11, 13, 13, 17, (232, 224, 208))  # chemise
    rect(12, 18, 12, 24, (216, 170, 70))   # boutons
    rect(7, 21, 17, 21, (36, 22, 32))      # ceinture
    rect(11, 21, 13, 22, (226, 180, 72))   # boucle
    # bras
    rect(4, 14, 6, 22, coat)
    rect(18, 14, 20, 22, coat_d)
    rect(4, 22, 6, 24, SKIN)
    rect(18, 22, 20, 24, SKIN_D)
    # tête
    rect(9, 5, 15, 12, SKIN)
    rect(14, 5, 15, 12, SKIN_D)
    px(10, 8, OUTLINE)
    px(13, 8, OUTLINE)
    px(12, 10, SKIN_D)
    if look["beard"]:
        rect(9, 11, 15, 14, look["beard"])
        rect(11, 11, 13, 11, SKIN_D)
    if look["patch"]:
        rect(9, 7, 11, 9, OUTLINE)
        for x in range(9, 16):
            px(x, 6, OUTLINE)
    if look["hat"] == "tricorne":
        rect(8, 1, 16, 4, (30, 22, 40))
        rect(3, 4, 21, 5, (30, 22, 40))
        rect(4, 3, 7, 3, (30, 22, 40))
        rect(17, 3, 20, 3, (30, 22, 40))
        rect(8, 5, 16, 5, (30, 22, 40))
        px(12, 3, (236, 226, 210))
        rect(9, 2, 15, 2, (60, 44, 70))
        rect(3, 5, 4, 5, (216, 170, 70))
    else:  # bandana rouge
        rect(8, 4, 16, 6, (176, 48, 56))
        rect(8, 4, 16, 4, (210, 80, 84))
        rect(16, 6, 19, 8, (176, 48, 56))
        rect(9, 3, 15, 3, (30, 22, 40))
        px(8, 10, (236, 196, 84))
    # contour sombre
    mask = img[..., 3] > 0
    pm = np.pad(mask, 1)
    near = pm[:-2, 1:-1] | pm[2:, 1:-1] | pm[1:-1, :-2] | pm[1:-1, 2:]
    edge = near & ~mask
    img[edge] = (*OUTLINE, 255)
    return Image.fromarray(img, "RGBA")


paint({"coat": (170, 52, 62), "pants": (74, 70, 104), "beard": (96, 56, 44), "patch": False, "hat": "tricorne"}).save(OUT / "pirate_red.png")
paint({"coat": (52, 90, 150), "pants": (90, 72, 70), "beard": None, "patch": True, "hat": "bandana"}).save(OUT / "pirate_blue.png")
paint({"coat": (62, 128, 74), "pants": (84, 70, 62), "beard": (58, 38, 30), "patch": False, "hat": "bandana"}).save(OUT / "pirate_green.png")
paint({"coat": (204, 158, 58), "pants": (70, 74, 112), "beard": None, "patch": True, "hat": "tricorne"}).save(OUT / "pirate_yellow.png")
print("ok", W, H)
