"""Aperçu de travail : python dev_preview.py sortie.png [anim] [frame] [vues] [scale] [catégorie=variante ...]"""
import json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_parts as parts
import pixel_build as pb
import pixel_catalog as pc
cat = pc.make_catalog(parts.LAYERS, (64, 72), (32, 68), {"idle": 4, "walk": 8, "carry_idle": 4, "carry_walk": 8, "helm": 1, "climb": 4, "jump": 3}, pb.TONES)
look = json.loads(json.dumps(pc.DEFAULT_LOOK))
out = sys.argv[1]
anim = sys.argv[2] if len(sys.argv) > 2 else "idle"
frame = int(sys.argv[3]) if len(sys.argv) > 3 else 0
dirs = [int(x) for x in (sys.argv[4] if len(sys.argv) > 4 else "0,2,4").split(",")]
scale = int(sys.argv[5]) if len(sys.argv) > 5 else 8
for a in sys.argv[6:]:
    k, v = a.split("=")
    if k.startswith("color:"):
        look["colors"][k[6:]] = v
    else:
        look["parts"][k] = v
pb.preview(look, cat, out, anim, (frame,), dirs, scale)
