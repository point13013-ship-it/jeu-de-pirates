"""Écrit data/hand_anchors.json : où est la main qui tient l'arme, à chaque image de chaque animation, dans chacune des 8 directions
du jeu (coordonnées de la case 64x72 du pirate, y vers le bas). Le jeu y pose l'arme dessinée par WeaponArt (voir src/character/weapon_art.gd).

La main d'arme est celle du bras proche en vue de profil et en 3/4, celle de droite de l'image de face et de dos : la même règle que
les armes de pixel_weapons.py. Pour une main qui pend, le point de prise est le milieu de la paume ; pour un poing (visée) ou un
bras levé, le centre du poing.
Usage : python export_hand_anchors.py"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import pixel_build as pb  # noqa: E402,F401  (charge les modules de dessin)
import pixel_body as body  # noqa: E402
import pixel_parts as parts  # noqa: E402
import pixel_pirate as pirate  # noqa: E402
from pixel_pirate import ANIMS, FLIP_OF_DIR, ROOT, VIEW_OF_DIR  # noqa: E402

W = pirate.W


def grip(view_name, f_anim, f):
    """(x, y) du point de prise, dans l'image dessinée (avant le retournement gauche-droite des directions de gauche)."""
    P = parts.Pose(f_anim, f)
    tq = view_name if view_name in ("SE", "NE") else None
    inner = {"SE": "S", "NE": "N"}.get(view_name, view_name)
    if tq:
        P.tq = tq
        pirate.set_warp(pb.make_warp(view_name, "body"))
    try:
        lst = body.arms(inner, P)
        if inner == "E" or tq:
            a = lst[-1]
        else:
            a = [x for x in lst if x["side"] == "R"][0]
        (ex, ey), (x, y) = a["pts"][-2], a["pts"][-1]
        shift = pirate.rigid_shift(x)
        fist = bool(a.get("fist")) and ey - y <= 4
        if fist or ey - y > 4:                     # poing ou bras levé : le bloc est centré sur le poignet
            return x + shift, y
        out = -1 if (inner != "E" and a["side"] == "L") else 1
        cx = int(x // 1)
        y0 = int(round(y)) + 1
        return cx + shift + (1.0 if out > 0 else 0.0), y0 + 4.0   # milieu de la paume
    finally:
        pirate.set_warp(None)


def main():
    out = {"frame": [W, pirate.H], "anims": {}}
    for anim, n in ANIMS.items():
        per_dir = []
        for d in range(8):
            row = []
            for f in range(n):
                x, y = grip(VIEW_OF_DIR[d], anim, f)
                if FLIP_OF_DIR[d]:
                    x = W - x
                row.append([round(float(x), 1), round(float(y), 1)])
            per_dir.append(row)
        out["anims"][anim] = per_dir
    path = ROOT / "data" / "hand_anchors.json"
    path.write_text(json.dumps(out, separators=(",", ":")), encoding="utf-8")
    print("écrit", path, "-", len(out["anims"]), "animations")


if __name__ == "__main__":
    main()
