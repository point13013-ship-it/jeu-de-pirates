"""Aperçu des animations de tir et de pouvoir : une planche par animation (lignes : les 8 directions, colonnes : les images).
Usage : python dev_actions.py <dossier de sortie> [anim ...]   (par défaut : cast, shoot_pistolet, shoot_tromblon, shoot_fusil)"""
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_build as pb  # noqa: E402

out = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
out.mkdir(parents=True, exist_ok=True)
anims = sys.argv[2:] or ["cast", "shoot_pistolet", "shoot_tromblon", "shoot_fusil"]
cat = json.loads((pb.ROOT / "data" / "character_parts.json").read_text(encoding="utf-8"))
look = cat["default_look"]
S = 4
for anim in anims:
    n = pb.ANIMS[anim]
    sheet = Image.new("RGBA", (pb.W * S * n, pb.H * S * 8), (60, 110, 120, 255))
    for d in range(8):
        for f in range(n):
            im = pb.compose(look, cat, anim, f, d).resize((pb.W * S, pb.H * S), Image.NEAREST)
            sheet.alpha_composite(im, (f * pb.W * S, d * pb.H * S))
    sheet.convert("RGB").save(out / f"{anim}.png")
    print("ecrit", out / f"{anim}.png")
