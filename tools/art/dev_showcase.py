"""Planche de présentation : python dev_showcase.py sortie.png [scale] [graines]"""
import json, random, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_parts as parts, pixel_build as pb, pixel_catalog as pc
from PIL import Image
ANIMS = {"idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3}
cat = pc.make_catalog(parts.LAYERS, (64, 72), (32, 68), ANIMS, pb.TONES)
out = sys.argv[1]
scale = int(sys.argv[2]) if len(sys.argv) > 2 else 5
seeds = [int(x) for x in (sys.argv[3] if len(sys.argv) > 3 else "1,2,3,4,5,6").split(",")]
def rnd(seed):
    r = random.Random(seed)
    look = json.loads(json.dumps(pc.DEFAULT_LOOK))
    for c in cat["order"]:
        opts = (["none"] if cat["parts"][c]["optional"] else []) + cat["parts"][c]["variants"]
        if c == "mark":
            look["parts"][c] = "none" if r.random() < 0.8 else r.choice(opts)
        else:
            look["parts"][c] = r.choice(opts)
    for ch, v in cat["channels"].items():
        look["colors"][ch] = r.choice(v["palette"])
    return look
cells = [pb.compose(rnd(s), cat, "idle", 0, d if d != -1 else 0) for s in seeds for d in (0,)]
sheet = Image.new("RGBA", (64 * scale * len(cells), 72 * scale), (74, 104, 112, 255))
for i, im in enumerate(cells):
    sheet.alpha_composite(im.resize((64 * scale, 72 * scale), Image.NEAREST), (i * 64 * scale, 0))
sheet.convert("RGB").save(out)
