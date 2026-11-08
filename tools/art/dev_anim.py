"""Planche d'animation : python dev_anim.py sortie.png anim direction [scale]"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_parts as parts, pixel_build as pb, pixel_catalog as pc
ANIMS = {"idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3}
cat = pc.make_catalog(parts.LAYERS, (64, 72), (32, 68), ANIMS, pb.TONES)
look = json.loads(json.dumps(pc.DEFAULT_LOOK))
out, anim, d = sys.argv[1], sys.argv[2], int(sys.argv[3])
scale = int(sys.argv[4]) if len(sys.argv) > 4 else 4
for a in sys.argv[5:]:
    k, v = a.split("="); (look["colors"] if k.startswith("color:") else look["parts"])[k.replace("color:", "")] = v
pb.preview(look, cat, out, anim, tuple(range(ANIMS[anim])), (d,), scale)
