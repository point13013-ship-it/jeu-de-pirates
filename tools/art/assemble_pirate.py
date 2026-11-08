"""Réduit les rendus Blender du pirate en feuilles de sprites par couche, et écrit le catalogue.

Usage : python assemble_pirate.py <dossier rendu par make_pirate.py> [--preview] [--look <fichier json>]
Écrit :
  assets/art/characters/pirate/<anim>/<couche>.png   une feuille par couche : colonne = image, ligne = direction
  data/character_parts.json                          catalogue (pièces, palettes, correspondance couche -> couleur)
Avec --preview : écrit aussi <dossier>/preview.png, le pirate assemblé avec le look par défaut.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

import os
ROOT = Path(os.environ["PIRATE_ROOT"]).resolve() if os.environ.get("PIRATE_ROOT") else Path(__file__).resolve().parents[2]  # PIRATE_ROOT : essais hors du jeu
RAW = Path(sys.argv[1]).resolve()
manifest = json.loads((RAW / "manifest.json").read_text(encoding="utf-8"))
FW, FH = manifest["frame"]
THRESH = 0.33                            # couverture mini d'un pixel pour qu'il existe (plus bas : les détails fins survivent)
TONES = (0.30, 0.56, 0.74, 0.88, 1.0)    # le 1er ton ne sert qu'au CONTOUR (la couleur de la pièce, très foncée) ; les 4 autres ombrent
TONE_EDGES = (0.70, 0.83, 0.93)          # seuils entre les 4 tons d'ombrage (valeurs brutes du rendu)
# Pièces entourées d'un fin contour (façon Eastward) : chacune se détache de ce qu'elle recouvre (barbe sur le visage,
# cheveux sur le front, manteau sur le pantalon...). Pas les traits du visage ni les petits ornements.
OUTLINE_CATS = {"head", "hands", "hair", "beard", "hat", "shirt", "coat", "belt", "pants", "boots"}
OUTLINE_SLOTS = {"skin", "hair", "hat", "cloth", "boot", "belt"}

# Couleur d'une couche : (catégorie, emplacement) -> canal de couleur du joueur, ou « #rrggbb » fixe.
LAYER_COLORS = {
    "pants.cloth": "pants", "pants.skin": "skin",
    "boots.boot": "boots", "boots.skin": "skin",
    "shirt.skin": "skin", "shirt.cloth": "shirt", "shirt.stripe": "shirt_stripe",
    "coat.cloth": "coat", "coat.trim": "coat_trim",
    "belt.belt": "belt", "belt.buckle": "#e6b84a",
    "hands.skin": "skin", "head.skin": "skin", "nose.skin": "skin",
    "mark.patch": "#15101a", "mark.scar": "scar", "mark.frame": "#e6b84a",
    "eyes.white": "#f6f1e6", "eyes.iris": "eyes", "brows.hair": "hair", "mouth.mouth": "#6a1f2a",
    "mouth.teeth": "#f6f1e6", "mouth.pipe": "#6b4423",
    "beard.hair": "hair", "mustache.hair": "hair", "hair.hair": "hair",
    "hat.hat": "hat", "hat.trim": "hat_trim",
}

CHANNELS = {  # canal -> (libellé, palette)
    "skin": ("Peau", ["#fbe0c8", "#f1c7a3", "#dca47a", "#bf8458", "#946039", "#6b4128", "#4a2c1c", "#e8c0d0"]),
    "hair": ("Cheveux et barbe", ["#1b1410", "#3a2416", "#6b4423", "#a8692f", "#d8a64a", "#e8d9a8", "#a8281f",
                                  "#d6d6d6", "#2d4d8f", "#2f7a4a", "#8a4fa8", "#e86aa0"]),
    "eyes": ("Yeux", ["#3a2a1c", "#6b4423", "#2d5fa8", "#3f8f5f", "#8a8f94", "#a8281f", "#8a4fa8", "#e6b84a"]),
    "scar": ("Cicatrice", ["#c97a6e", "#a8504a", "#e0a8a0"]),
    "shirt": ("Chemise", ["#f2ead8", "#d94a3b", "#2d5fa8", "#3f8f5f", "#e6b84a", "#2a2a33", "#8a4fa8", "#e8844a"]),
    "shirt_stripe": ("Rayures", ["#2a3f78", "#a8281f", "#2a2a33", "#f2ead8"]),
    "coat": ("Manteau / gilet", ["#7a1f2a", "#223a66", "#2f5a3a", "#2a2a33", "#6b4423", "#d8c7a0", "#5a2f78", "#a8281f"]),
    "coat_trim": ("Parements", ["#e6b84a", "#d6d6d6", "#f2ead8", "#1b1410", "#a8281f"]),
    "pants": ("Pantalon", ["#3a3a46", "#6b4423", "#2d4d8f", "#d8c7a0", "#2a2a33", "#7a1f2a", "#3f6f4a"]),
    "boots": ("Bottes", ["#2e1d14", "#5a3a22", "#1b1410", "#7a1f2a", "#8a8f94"]),
    "hat": ("Chapeau", ["#2a2a33", "#7a1f2a", "#223a66", "#d8b45a", "#d94a3b", "#f2ead8", "#2f5a3a"]),
    "hat_trim": ("Ruban du chapeau", ["#e6b84a", "#d94a3b", "#f2ead8", "#1b1410", "#2d5fa8"]),
    "belt": ("Ceinture / écharpe", ["#4a2f1c", "#d94a3b", "#e6b84a", "#2a2a33", "#2d5fa8", "#f2ead8"]),
}

PART_LABELS = {  # catégorie -> (libellé, peut-être absente)
    "head": ("Visage", False), "hands": ("Mains", False), "nose": ("Nez", False), "eyes": ("Yeux", False),
    "brows": ("Sourcils", True), "mouth": ("Bouche", False), "mark": ("Signe", True), "hair": ("Coiffure", True),
    "beard": ("Barbe", True), "mustache": ("Moustache", True), "hat": ("Chapeau", True), "shirt": ("Haut", False),
    "coat": ("Manteau", True), "belt": ("Ceinture", True), "pants": ("Pantalon", False), "boots": ("Chaussures", False),
}


VARIANT_LABELS = {
    "head": {"round": "Rond"},
    "hands": {"bare": "Nues"},
    "nose": {"small": "Petit", "big": "Gros", "pointy": "Pointu", "round": "Rond", "flat": "Épaté"},
    "eyes": {"round": "Ronds", "narrow": "Fins", "angry": "Méchants", "wide": "Grands", "sleepy": "Endormis"},
    "brows": {"normal": "Normaux", "thick": "Épais", "angry": "Froncés", "raised": "Levés"},
    "mouth": {"smile": "Sourire", "neutral": "Neutre", "grin": "Grand sourire", "frown": "Boudeuse", "open": "Qui crie", "pipe": "Pipe"},
    "mark": {"patch_l": "Cache-œil gauche", "patch_r": "Cache-œil droit", "scar": "Cicatrice", "monocle": "Monocle", "earrings": "Boucles d'oreille"},
    "hair": {"short": "Courts", "buzz": "Ras", "long": "Longs", "ponytail": "Queue de cheval", "bun": "Chignon",
             "mohawk": "Crête", "afro": "Afro", "pigtails": "Couettes", "pompadour": "Banane", "dreads": "Dreadlocks",
             "bob": "Carré", "curly": "Bouclés"},
    "beard": {"stubble": "Barbe de trois jours", "goatee": "Bouc", "full": "Barbe pleine", "long": "Longue barbe",
              "braid": "Barbe tressée", "chinstrap": "Favoris", "twin": "Deux nattes", "forked": "Barbe fourchue",
              "chops": "Pattes", "bushy": "Broussaille"},
    "mustache": {"thin": "Fine", "handlebar": "Guidon", "walrus": "Morse", "chevron": "Chevron"},
    "hat": {"tricorn": "Tricorne", "bicorn": "Bicorne", "bandana": "Bandana", "straw": "Chapeau de paille",
            "cap": "Calot", "tophat": "Haut-de-forme", "turban": "Turban", "headband": "Bandeau"},
    "shirt": {"bare": "Torse nu", "tee": "T-shirt", "pirate": "Chemise de pirate", "striped": "Marinière"},
    "coat": {"vest": "Gilet", "jacket": "Veste", "captain": "Manteau de capitaine"},
    "belt": {"belt": "Ceinture", "sash": "Écharpe", "baldric": "Baudrier"},
    "pants": {"long": "Long", "shorts": "Short", "rolled": "Retroussé"},
    "boots": {"high": "Hautes bottes", "shoes": "Souliers", "barefoot": "Pieds nus", "sandals": "Sandales"},
}

DEFAULT_LOOK = {
    "parts": {"head": "round", "hands": "bare", "nose": "small", "eyes": "round", "brows": "normal", "mouth": "smile",
              "hair": "short", "beard": "full", "mustache": "none", "hat": "tricorn", "mark": "none",
              "shirt": "pirate", "coat": "captain", "belt": "sash", "pants": "long", "boots": "high"},
    "colors": {"skin": "#dca47a", "hair": "#3a2416", "eyes": "#2d5fa8", "scar": "#c97a6e", "shirt": "#f2ead8",
               "shirt_stripe": "#2a3f78", "coat": "#7a1f2a", "coat_trim": "#e6b84a", "pants": "#3a3a46",
               "boots": "#2e1d14", "hat": "#2a2a33", "hat_trim": "#e6b84a", "belt": "#d94a3b"},
}


def reduce(path: Path, outline: bool = False) -> np.ndarray:
    """Image 4x -> image finale 48x64 (moyenne pondérée par l'alpha, alpha en tout-ou-rien)."""
    im = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
    ss = im.shape[1] // FW
    a = im[..., 3:4]
    pre = im[..., :3] * a
    pre = pre.reshape(FH, ss, FW, ss, 3).mean(axis=(1, 3))
    aa = a.reshape(FH, ss, FW, ss, 1).mean(axis=(1, 3))
    rgb = np.where(aa > 1e-6, pre / np.maximum(aa, 1e-6), 0.0)
    out = np.zeros((FH, FW, 4), np.uint8)
    # Teintes de gris en 4 paliers : un aplat par ton, comme du pixel art, et peu de couleurs distinctes
    # (le filtre « palette » du jeu laisse intactes les couleurs exactes des pirates, voir pixel_look.gdshader).
    v = rgb.mean(axis=-1)
    tone = np.where(v < TONE_EDGES[0], TONES[1], np.where(v < TONE_EDGES[1], TONES[2],
                    np.where(v < TONE_EDGES[2], TONES[3], TONES[4])))
    out[..., :3] = np.clip(tone[..., None] * 255.0 + 0.5, 0, 255).astype(np.uint8)
    solid = aa[..., 0] >= THRESH
    out[..., 3] = np.where(solid, 255, 0)
    if outline:
        grown = solid.copy()
        grown[1:, :] |= solid[:-1, :]
        grown[:-1, :] |= solid[1:, :]
        grown[:, 1:] |= solid[:, :-1]
        grown[:, :-1] |= solid[:, 1:]
        ring = grown & ~solid
        out[ring, :3] = int(TONES[0] * 255.0 + 0.5)
        out[ring, 3] = 255
    return out


def hexrgb(h: str):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))


def build():
    out_root = ROOT / "assets" / "art" / "characters" / "pirate"
    empty = set(manifest["layers"])
    kept = {}
    for anim_dir in sorted((RAW / "raw").iterdir()):
        anim = anim_dir.name
        nf = manifest["anims"][anim]
        for layer_dir in sorted(anim_dir.iterdir()):
            lid = layer_dir.name
            sheet = np.zeros((8 * FH, nf * FW, 4), np.uint8)
            for p in layer_dir.glob("f*_d*.png"):
                f, d = p.stem[1:].split("_d")
                info = manifest["layers"][lid]
                img = reduce(p, info["category"] in OUTLINE_CATS and info["slot"] in OUTLINE_SLOTS)
                sheet[int(d) * FH:(int(d) + 1) * FH, int(f) * FW:(int(f) + 1) * FW] = img
            if sheet[..., 3].max() == 0:
                continue
            empty.discard(lid)
            dest = out_root / anim
            dest.mkdir(parents=True, exist_ok=True)
            Image.fromarray(sheet).save(dest / f"{lid}.png")
            kept.setdefault(lid, 0)
            kept[lid] += 1
    parts = {}
    for lid, info in manifest["layers"].items():
        if lid in empty:
            continue
        cat = info["category"]
        parts.setdefault(cat, {"variants": [], "layers": {}})
        if info["variant"] not in parts[cat]["variants"]:
            parts[cat]["variants"].append(info["variant"])
        parts[cat]["layers"].setdefault(info["variant"], []).append(
            {"id": lid, "slot": info["slot"], "color": LAYER_COLORS[f"{cat}.{info['slot']}"]})
    catalog = {
        "frame": manifest["frame"], "feet": manifest["feet"], "directions": 8, "anims": manifest["anims"],
        "order": [c for c in manifest["categories"] if c in parts],
        "parts": {c: {"label": PART_LABELS[c][0], "optional": PART_LABELS[c][1], **parts[c]} for c in parts},
        "channels": {k: {"label": v[0], "palette": v[1]} for k, v in CHANNELS.items()},
        "tones": list(TONES), "labels": VARIANT_LABELS,
        "default_look": DEFAULT_LOOK,
    }
    (ROOT / "data").mkdir(exist_ok=True)
    (ROOT / "data" / "character_parts.json").write_text(json.dumps(catalog, indent=1, ensure_ascii=False), encoding="utf-8")
    print("couches gardées :", len(parts), "catégories,", sum(len(p["layers"]) for p in parts.values()), "variantes")


def compose(anim: str, frame: int, direction: int, look: dict) -> Image.Image:
    cat = json.loads((ROOT / "data" / "character_parts.json").read_text(encoding="utf-8"))
    canvas = np.zeros((FH, FW, 4), np.float64)
    for c in cat["order"]:
        variant = look["parts"].get(c, "none")
        if variant == "none" or variant not in cat["parts"][c]["layers"]:
            continue
        for lay in cat["parts"][c]["layers"][variant]:
            path = ROOT / "assets" / "art" / "characters" / "pirate" / anim / f"{lay['id']}.png"
            if not path.exists():
                continue
            sheet = np.asarray(Image.open(path).convert("RGBA"), dtype=np.float64) / 255.0
            img = sheet[direction * FH:(direction + 1) * FH, frame * FW:(frame + 1) * FW]
            col = lay["color"]
            tint = np.array(hexrgb(col if col.startswith("#") else look["colors"][col]))
            rgb = np.clip(img[..., :3] * tint * 1.0, 0, 1)
            a = img[..., 3:4]
            canvas[..., :3] = rgb * a + canvas[..., :3] * (1 - a)
            canvas[..., 3:4] = np.maximum(canvas[..., 3:4], a)
    return Image.fromarray((canvas * 255 + 0.5).astype(np.uint8), "RGBA")


def preview(look: dict, anim="walk", frames=(0,), tag="preview"):
    dirs = range(8)
    scale = 5
    sheet = Image.new("RGBA", (FW * len(dirs) * scale, FH * len(frames) * scale), (96, 150, 150, 255))
    for r, f in enumerate(frames):
        for d in dirs:
            im = compose(anim, f, d, look).resize((FW * scale, FH * scale), Image.NEAREST)
            sheet.alpha_composite(im, (d * FW * scale, r * FH * scale))
    sheet.save(RAW / f"{tag}.png")
    print("aperçu :", RAW / f"{tag}.png")


if __name__ == "__main__":
    if "--nobuild" not in sys.argv:
        build()
    if "--preview" in sys.argv:
        look = DEFAULT_LOOK
        if "--look" in sys.argv:
            look = json.loads(Path(sys.argv[sys.argv.index("--look") + 1]).read_text())
        anims = [a.name for a in (RAW / "raw").iterdir()]
        preview(look, "walk" if "walk" in anims else anims[0], (0,))


def gallery(anim="walk"):
    """Une planche : chaque variante de chaque catégorie, sur le look par défaut, vue de face et de profil."""
    cat = json.loads((ROOT / "data" / "character_parts.json").read_text(encoding="utf-8"))
    cells = []
    for c in cat["order"]:
        for v in cat["parts"][c]["variants"]:
            look = json.loads(json.dumps(DEFAULT_LOOK))
            if c in ("pants", "boots", "shirt", "belt"):
                look["parts"]["coat"] = "none"
                look["parts"]["belt"] = "none"
            if c in ("hair", "beard", "mustache", "mark", "eyes", "brows", "mouth", "nose"):
                look["parts"]["hat"] = "none"
            if c == "hat":
                look["parts"]["hair"] = "short"
            look["parts"][c] = v
            cells.append((c, v, look))
    cols = 8
    sc = 4
    rows = (len(cells) + cols - 1) // cols
    sheet = Image.new("RGBA", (cols * FW * sc * 2, rows * (FH * sc + 12)), (96, 150, 150, 255))
    from PIL import ImageDraw
    dr = ImageDraw.Draw(sheet)
    for i, (c, v, look) in enumerate(cells):
        x, y = (i % cols) * FW * sc * 2, (i // cols) * (FH * sc + 12)
        for k, d in enumerate((0, 2)):
            im = compose(anim, 0, d, look).resize((FW * sc, FH * sc), Image.NEAREST)
            sheet.alpha_composite(im, (x + k * FW * sc, y + 12))
        dr.text((x + 2, y), f"{c}-{v}", fill=(255, 255, 255, 255))
    sheet.save(RAW / "gallery.png")
    print("galerie :", RAW / "gallery.png", len(cells))


if "--gallery" in sys.argv:
    _anims = [d.name for d in (RAW / "raw").iterdir()]
    gallery("idle" if "idle" in _anims else _anims[0])
