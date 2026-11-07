"""Ramène les rendus 3D du bateau (raw_XX.png) en pixel art : réduction, palette commune,
contour sombre d'un pixel. Écrit un atlas ship_atlas.png (une image par cap) et un aperçu.

Usage : python pixelize_ship.py <dossier des rendus> <dossier de sortie> <taille> <nombre de caps> <colonnes>
L'image k de l'atlas est le bateau tourné de k * 360 / <nombre de caps> degrés, dans le sens
horaire à l'écran, 0 = vers la droite (même convention que la rotation de Godot).
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(sys.argv[1])
OUT = Path(sys.argv[2])
FINAL = int(sys.argv[3]) if len(sys.argv) > 3 else 160
HEADINGS = int(sys.argv[4]) if len(sys.argv) > 4 else 16
COLS = int(sys.argv[5]) if len(sys.argv) > 5 else 4
PALETTE_COLORS = 36
OUTLINE = (22, 14, 30)
ROWS = -(-HEADINGS // COLS)

OUT.mkdir(parents=True, exist_ok=True)
frames = []
for k in range(HEADINGS):
    im = Image.open(SRC / f"raw_{k:02d}.png").convert("RGBA")
    im = im.resize((FINAL, FINAL), Image.Resampling.BOX)
    a = np.asarray(im).astype(np.float32)
    a[..., 3] = np.where(a[..., 3] > 140, 255, 0)
    frames.append(a)

# palette commune calculée sur un échantillon de toutes les images
sample = np.concatenate([f[f[..., 3] > 0][::3, :3] for f in frames[::max(1, HEADINGS // 24)]]).astype(np.uint8)
side = int(np.ceil(np.sqrt(len(sample))))
pad = np.zeros((side * side, 3), np.uint8)
pad[:len(sample)] = sample
pal_img = Image.fromarray(pad.reshape(side, side, 3)).quantize(
    colors=PALETTE_COLORS, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)

atlas = Image.new("RGBA", (FINAL * COLS, FINAL * ROWS), (0, 0, 0, 0))
out_frames = []
for k, f in enumerate(frames):
    rgb = Image.fromarray(f[..., :3].astype(np.uint8)).quantize(palette=pal_img, dither=Image.Dither.NONE).convert("RGB")
    arr = np.asarray(rgb)
    mask = f[..., 3] > 0
    pm = np.pad(mask, 1)
    near = pm[:-2, 1:-1] | pm[2:, 1:-1] | pm[1:-1, :-2] | pm[1:-1, 2:]
    edge = near & ~mask
    rgba = np.zeros((FINAL, FINAL, 4), np.uint8)
    rgba[..., :3] = arr
    rgba[..., 3] = np.where(mask, 255, 0)
    rgba[edge] = (*OUTLINE, 255)
    im = Image.fromarray(rgba, "RGBA")
    atlas.paste(im, ((k % COLS) * FINAL, (k // COLS) * FINAL))
    out_frames.append(im)
atlas.save(OUT / "ship_atlas.png")

# aperçu : 16 caps régulièrement espacés, sur fond de mer, agrandis x2
step = max(1, HEADINGS // 16)
prev = Image.new("RGBA", (FINAL * 4, FINAL * 4), (24, 48, 86, 255))
for n in range(16):
    prev.alpha_composite(out_frames[(n * step) % HEADINGS], ((n % 4) * FINAL, (n // 4) * FINAL))
prev.resize((prev.width * 2, prev.height * 2), Image.Resampling.NEAREST).save(OUT / "ship_sheet_preview.png")
print("ok", HEADINGS, "caps,", FINAL, "px, atlas", atlas.size)
