"""Galerie de travail : python dev_gallery.py sortie.png catégorie [vues] [scale] [clé=valeur ...]"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_parts as parts
import pixel_build as pb
import pixel_catalog as pc
from PIL import Image, ImageDraw
ANIMS = {"idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3}
cat = pc.make_catalog(parts.LAYERS, (64, 72), (32, 68), ANIMS, pb.TONES)
out, category = sys.argv[1], sys.argv[2]
dirs = [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "0,2,4").split(",")]
scale = int(sys.argv[4]) if len(sys.argv) > 4 else 4
base = json.loads(json.dumps(pc.DEFAULT_LOOK))
for a in sys.argv[5:]:
    k, v = a.split("=")
    (base["colors"] if k.startswith("color:") else base["parts"])[k.replace("color:", "")] = v
variants = cat["parts"][category]["variants"]
if cat["parts"][category]["optional"]:
    pass
W, H = 64, 72
crop = (6, 8, 58, 62) if category not in ("shirt", "coat", "belt", "pants", "boots") else (6, 20, 58, 72)
cw, ch = (crop[2] - crop[0]) * scale, (crop[3] - crop[1]) * scale
cols = 4
rows = (len(variants) + cols - 1) // cols
sheet = Image.new("RGB", (cols * cw * len(dirs), rows * (ch + 12)), (60, 110, 120))
dr = ImageDraw.Draw(sheet)
for i, v in enumerate(variants):
    look = json.loads(json.dumps(base))
    look["parts"][category] = v
    x0, y0 = (i % cols) * cw * len(dirs), (i // cols) * (ch + 12)
    for k, d in enumerate(dirs):
        im = pb.compose(look, cat, "idle", 0, d).crop(crop).resize((cw, ch), Image.NEAREST)
        sheet.paste(im, (x0 + k * cw, y0 + 12), im)
    dr.text((x0 + 2, y0), f"{category}-{v}", fill=(255, 255, 255))
sheet.save(out)
print("ok", len(variants))
