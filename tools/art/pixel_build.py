"""Assemble le pirate en pixel art : feuilles par couche, catalogue, aperçus.
Usage : python pixel_build.py [--nowrite] [--preview sortie.png] [--look fichier.json] [--views S,E,N] [--anim walk --frame 0]
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_parts as parts  # noqa: E402
import pixel_details as det  # noqa: E402
for _m in ('pixel_hair', 'pixel_body', 'pixel_head', 'pixel_hairstyles', 'pixel_weapons'):
    try:
        __import__(_m)
    except ModuleNotFoundError:
        pass
import pixel_pirate as pirate  # noqa: E402
from pixel_pirate import ANIMS, FEET, FLIP_OF_DIR, H, ROOT, TONES, VIEW_OF_DIR, W, Cv  # noqa: E402

# La couleur d'un pixel : même formule que PirateSprite.shade dans le jeu (ombres violettes, lumières chaudes).
SHADOW = np.array([0.10, 0.06, 0.28])
LIGHT_T = np.array([0.07, 0.045, 0.0])
BRIGHT = 1.12


def shade(tint, t):
    s = 1.0 - t
    return np.clip(np.asarray(tint) * t * BRIGHT * (1 - s * 0.35) + SHADOW * s * 0.30 + LIGHT_T * max(0.0, t - 0.88) / 0.12, 0, 1)


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)])


HEAD_CATS = {"head", "nose", "mark", "eyes", "brows", "beard", "mouth", "mustache", "hair", "hat"}


def make_warp(view, category):
    """La rotation 3/4 : x -> x'. Tête : le centre du visage glisse de 3,4 pixels vers la droite (SE) ou le centre de la nuque vers
    la gauche (NE), les bords du crâne ne bougent pas. Corps : le centre glisse de 2 pixels, la silhouette change à peine."""
    if category in HEAD_CATS:
        xs, ys = [-14.0, -8.6, 0.0, 8.6, 14.0], [-14.0, -8.6, 3.4, 8.6, 14.0]
    else:
        xs, ys = [-14.0, -8.0, 0.0, 8.0, 14.0], [-13.2, -7.2, 2.0, 7.2, 13.2]
    if view == "SE":
        return lambda x: 32.0 + np.interp(x - 32.0, xs, ys)
    return lambda x: 32.0 - np.interp(32.0 - x, xs, ys)


# La tête est dessinée dans l'ancien repère (crâne de 15 pixels, menton à y = 29,6) puis réduite de 12 % : son menton tombe sur le cou
# du corps de référence (y = 31,5), le crâne reste centré sur x = 32.
HEAD_XF = (0.88, 32.0, 29.6, 32.0, 31.5)


def draw_layer(lid, view, pose):
    cat, var, slot, fn = parts.LAYERS[lid]
    cv = Cv()
    pirate.set_xform(HEAD_XF if cat in HEAD_CATS and lid not in parts.NATIVE else None)
    try:
        if view in ("SE", "NE"):
            pose.tq = view
            pirate.set_warp(make_warp(view, cat))
            try:
                fn(cv, "S" if view == "SE" else "N", pose)
                det.apply(lid, cv, "S" if view == "SE" else "N", pose)
            finally:
                pirate.set_warp(None)
                pose.tq = None
        else:
            fn(cv, view, pose)
            det.apply(lid, cv, view, pose)
    finally:
        pirate.set_xform(None)
    return cv.t


def flip(t):
    return t[:, ::-1]


def frame_of(lid, anim, f, direction):
    """Les tons d'une couche pour une direction du jeu (vue dessinée, retournée si besoin)."""
    t = draw_layer(lid, VIEW_OF_DIR[direction], parts.Pose(anim, f))
    return flip(t) if FLIP_OF_DIR[direction] else t


def tone_to_rgba(t):
    out = np.zeros((H, W, 4), np.uint8)
    mask = t >= 0
    gray = np.array([int(v * 255 + 0.5) for v in TONES], np.uint8)
    out[mask, :3] = gray[t[mask]][:, None]
    out[mask, 3] = 255
    return out


def build_sheets(lids, anims=None):
    out_root = ROOT / "assets" / "art" / "characters" / "pirate"
    kept = set()
    for anim, n in ANIMS.items():
        if anims and anim not in anims:
            continue
        dest = out_root / anim
        dest.mkdir(parents=True, exist_ok=True)
        for lid in lids:
            sheet = np.zeros((8 * H, n * W, 4), np.uint8)
            cache = {}
            for f in range(n):
                for d in range(8):
                    key = (VIEW_OF_DIR[d], FLIP_OF_DIR[d])
                    if key not in cache:
                        cache[key] = {}
                    if f not in cache[key]:
                        cache[key][f] = tone_to_rgba(frame_of(lid, anim, f, d))
                    sheet[d * H:(d + 1) * H, f * W:(f + 1) * W] = cache[key][f]
            if sheet[..., 3].max() == 0:
                continue
            Image.fromarray(sheet).save(dest / f"{lid}.png")
            kept.add(lid)
    return kept


def compose(look, cat, anim, f, direction):
    """Le pirate assemblé (image RGBA) pour un look : même ordre et mêmes couleurs que dans le jeu."""
    canvas = np.zeros((H, W, 4), np.float64)
    # l'arme des animations de tir se dessine par-dessus tout (elle n'est pas dans l'apparence du joueur)
    sequence = [(c, look["parts"].get(c, "none")) for c in cat["order"]]
    if anim.startswith(("shoot_", "slash_")):
        sequence.append(("weapon", anim[len("shoot_"):]))   # (« shoot_ » et « slash_ » ont la même longueur)
    for c, var in sequence:
        if var == "none" or var not in cat["parts"][c]["layers"]:
            continue
        for lay in cat["parts"][c]["layers"][var]:
            if lay["id"] not in parts.LAYERS:
                continue
            t = frame_of(lay["id"], anim, f, direction)
            col = lay["color"]
            tint = hexrgb(col if col.startswith("#") else look["colors"][col])
            m = t >= 0
            for ti in range(len(TONES)):
                sel = m & (t == ti)
                if sel.any():
                    canvas[sel, :3] = shade(tint, TONES[ti])
                    canvas[sel, 3] = 1.0
    return Image.fromarray((canvas * 255 + 0.5).astype(np.uint8), "RGBA")


def preview(look, cat, path, anim="idle", frames=(0,), dirs=(0, 1, 4), scale=8, bg=(60, 110, 120)):
    cells = []
    for f in frames:
        for d in dirs:
            cells.append(compose(look, cat, anim, f, d))
    sheet = Image.new("RGBA", (W * scale * len(cells), H * scale), bg + (255,))
    for i, im in enumerate(cells):
        sheet.alpha_composite(im.resize((W * scale, H * scale), Image.NEAREST), (i * W * scale, 0))
    sheet.convert("RGB").save(path)


def write_all(anims=None):
    import pixel_catalog as pc
    lids = list(parts.LAYERS)
    kept = build_sheets(lids, anims)
    cat = pc.make_catalog({k: v for k, v in parts.LAYERS.items() if k in kept}, (W, H), FEET, ANIMS, TONES)
    (ROOT / "data").mkdir(exist_ok=True)
    (ROOT / "data" / "character_parts.json").write_text(json.dumps(cat, indent=1, ensure_ascii=False), encoding="utf-8")
    print("couches :", len(kept), "- catalogue écrit")


if __name__ == "__main__" and "--write" in sys.argv:
    write_all()
