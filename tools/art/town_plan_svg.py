# -*- coding: utf-8 -*-
"""Maquette en plan de la ville v3 (13/11/2026) : dessine design/ville-v3/plan-maquette.svg.

C'est un document de conception, pas le jeu : il sert à valider les quartiers, les rues, les repères et la place des
services AVANT de construire quoi que ce soit. 1 unité = 1 m. Nord en haut, la mer au sud (comme la caméra du jeu).
Usage : python tools/art/town_plan_svg.py   (Python de Blender : aucun module externe)
"""
import math
import os
import random

W, H = 220.0, 190.0          # m : emprise du dessin
S = 6.0                      # pixels par mètre
rnd = random.Random(7)

# ------------------------------------------------------------------ palette v1 (design/bible-v2.md)
SEA, SEA_L, SAND, GRASS, GRASS_D = "#1F5470", "#2A8290", "#D9B077", "#5A9440", "#2D6444"
PAVE, PAVE_D, WOODC, STONE, BRASS, INK = "#B9AD9C", "#7D7488", "#9C6A43", "#4A4258", "#DCAE5C", "#1C1726"
FACADES = ["#D68A6E", "#DCAE5C", "#5F8FB0", "#93C4A6", "#D9A0A8", "#EFE4CC"]
ROOFS = ["#7A3530", "#B25A3E", "#DE8A5E", "#4A4258"]

out = []


def px(v):
    return round(v * S, 1)


def poly(points, fill, stroke="none", sw=0.0, opacity=1.0, extra=""):
    pts = " ".join("%s,%s" % (px(x), px(y)) for x, y in points)
    out.append('<polygon points="%s" fill="%s" stroke="%s" stroke-width="%s" opacity="%s" %s/>' % (pts, fill, stroke, px(sw), opacity, extra))


def path(points, stroke, width, opacity=1.0, dash=""):
    d = "M " + " L ".join("%s %s" % (px(x), px(y)) for x, y in points)
    out.append('<path d="%s" fill="none" stroke="%s" stroke-width="%s" stroke-linecap="round" stroke-linejoin="round" opacity="%s" %s/>'
               % (d, stroke, px(width), opacity, ('stroke-dasharray="%s"' % dash) if dash else ""))


def circle(x, y, r, fill, stroke="none", sw=0.0, opacity=1.0):
    out.append('<circle cx="%s" cy="%s" r="%s" fill="%s" stroke="%s" stroke-width="%s" opacity="%s"/>' % (px(x), px(y), px(r), fill, stroke, px(sw), opacity))


def text(x, y, s, size=2.6, fill=INK, anchor="middle", weight="normal", halo=True):
    style = 'font-family="Georgia, serif" font-size="%s" text-anchor="%s" font-weight="%s"' % (px(size), anchor, weight)
    if halo:
        out.append('<text x="%s" y="%s" %s fill="none" stroke="#EFE4CC" stroke-width="%s" stroke-linejoin="round" opacity="0.85">%s</text>' % (px(x), px(y), style, px(0.7), s))
    out.append('<text x="%s" y="%s" %s fill="%s">%s</text>' % (px(x), px(y), style, fill, s))


def rot_rect(cx, cy, w, d, ang):
    c, s = math.cos(ang), math.sin(ang)
    return [(cx + c * a - s * b, cy + s * a + c * b) for a, b in ((-w / 2, -d / 2), (w / 2, -d / 2), (w / 2, d / 2), (-w / 2, d / 2))]


# ------------------------------------------------------------------ le terrain
# côte : la terre est au nord de cette ligne (d'ouest en est) ; une baie en croissant, un cap à l'est
COAST = [(0, 131), (14, 133), (30, 136), (44, 134), (52, 128), (62, 123), (76, 119.5), (92, 117.5), (105, 117), (118, 117.5),
         (134, 119.5), (148, 123), (158, 129), (165, 138), (172, 150), (181, 160), (192, 164), (203, 160), (210, 148), (214, 132),
         (220, 126)]


def coast_y(x):
    for (x0, y0), (x1, y1) in zip(COAST, COAST[1:]):
        if x0 <= x <= x1:
            return y0 + (y1 - y0) * (x - x0) / (x1 - x0)
    return 130.0


out.append('<rect x="0" y="0" width="%s" height="%s" fill="%s"/>' % (px(W), px(H), SEA))
# hauts-fonds clairs le long de la côte
poly([(x, y + 7) for x, y in COAST] + [(W, 0), (0, 0)], SEA_L, opacity=0.55)
# terre
poly(COAST + [(W, 0), (0, 0)], GRASS)
# plage des pêcheurs (ouest) et grève du cap
poly([(0, 118), (16, 121), (32, 124), (46, 124), (54, 121), (52, 128), (44, 134), (30, 136), (14, 133), (0, 131)], SAND)
# jungle (bord nord et ouest)
poly([(0, 0), (W, 0), (W, 10), (190, 14), (150, 9), (110, 12), (70, 8), (40, 14), (18, 30), (10, 60), (0, 80)], GRASS_D)
# haute ville : une terrasse à +3 m derrière un mur de soutènement, puis le parvis à +5 m
UP = [(48, 66), (64, 61), (84, 63), (100, 60), (120, 62), (140, 59), (160, 63), (176, 70), (180, 52), (176, 30), (160, 18), (120, 15),
      (84, 17), (60, 22), (48, 40)]
poly(UP, "#7FA84E")
path(UP[:8], STONE, 1.4)            # le mur de soutènement, côté ville basse
# colline du moulin (nord-ouest)
circle(28, 46, 19, "#7FA84E")
circle(28, 46, 12, "#A3C650")
# le cap du fort (est) : plate-forme à +3 m
FORT = [(170, 126), (186, 120), (204, 124), (210, 140), (203, 156), (190, 160), (178, 152), (170, 140)]
poly(FORT, PAVE_D)
poly([(x * 0.86 + 190 * 0.14, y * 0.86 + 140 * 0.14) for x, y in FORT], PAVE)

# ------------------------------------------------------------------ les rues (polylignes, largeur en m)
STREETS = [
    ("quai", [(54, 124), (64, 119), (78, 115.5), (92, 113.5), (105, 113), (118, 113.5), (132, 115.5), (146, 119), (156, 125), (164, 134), (170, 130)], 7.0),
    ("grand_rue", [(105, 104), (102, 94), (106, 84), (100, 75), (104, 66), (111, 58), (108, 48), (110, 40)], 6.0),
    ("rue_marche", [(102, 94), (90, 88), (76, 87), (66, 89)], 4.0),
    ("rue_pecheurs", [(58, 92), (50, 100), (44, 110), (40, 120)], 3.5),
    ("rue_corderie", [(102, 94), (116, 93), (128, 92), (140, 95), (152, 103), (160, 114)], 4.0),
    ("contre_allee_o", [(66, 84), (72, 76), (84, 72), (100, 75)], 3.5),
    ("contre_allee_e", [(106, 84), (120, 82), (134, 86), (140, 96)], 3.5),
    ("montee_fort", [(160, 114), (168, 118), (176, 124)], 3.5),
    ("escalier_est", [(134, 86), (142, 74), (146, 62), (146, 45)], 2.4),
    ("escalier_ouest", [(72, 76), (68, 68), (66, 60), (62, 50.5)], 2.4),
    ("rue_haute", [(60, 50), (76, 46), (92, 48), (110, 46), (128, 48), (146, 44), (164, 48)], 4.0),
    ("chemin_moulin", [(60, 50), (48, 50), (38, 48), (33.5, 47)], 2.4),
    ("chemin_jungle", [(23.5, 40.5), (18, 34), (12, 20)], 2.0),
    ("ruelle_1", [(84, 87.5), (84, 80), (84, 72)], 1.8),
    ("ruelle_2", [(128, 92), (124, 87), (120, 82)], 1.8),
    ("ruelle_3", [(68, 92), (66.5, 104), (68, 116)], 1.8),
    ("ruelle_4", [(140, 95), (141.5, 107), (140, 117)], 1.8),
]
for _name, pts, w in STREETS:
    path(pts, PAVE_D, w + 0.8)
for name, pts, w in STREETS:
    path(pts, "#CFC3AE" if name in ("quai", "grand_rue") else PAVE, w)
for name, pts, w in STREETS:
    if name.startswith("escalier"):
        path(pts, STONE, w * 0.9, dash="2 5")

# ------------------------------------------------------------------ places
PLAZAS = [  # (nom, x, y, rayon x, rayon y)
    ("Place du Débarcadère", 105, 106, 12.0, 8.0),
    ("Place du Marché", 66, 88, 10.0, 7.5),
    ("Parvis de l'église", 110, 40, 9.5, 7.0),
    ("Fontaine", 134, 86, 5.0, 4.5),
]
for _n, x, y, rx, ry in PLAZAS:
    out.append('<ellipse cx="%s" cy="%s" rx="%s" ry="%s" fill="#CFC3AE" stroke="%s" stroke-width="%s"/>' % (px(x), px(y), px(rx), px(ry), PAVE_D, px(0.4)))

# ------------------------------------------------------------------ bâtiments nommés (services et repères)
# (numéro, nom, x, y, largeur, profondeur, angle en degrés, couleur du toit)
NAMED = [
    (1, "Receleur (étal)", 99.0, 108.6, 5.0, 3.5, -6, "#DCAE5C"),
    (2, "Tableau des quêtes", 113.5, 110.5, 2.6, 1.4, 6, "#9C6A43"),
    (3, "Taverne du Pélican Borgne", 86.5, 99.6, 14.0, 10.0, -6, "#7A3530"),
    (4, "Magasin général", 121.5, 103.4, 11.0, 9.0, 8, "#B25A3E"),
    (5, "Chantier naval (halle)", 157.0, 110.5, 15.0, 9.0, 34, "#6A4532"),
    (6, "Voilerie", 134.0, 103.5, 8.0, 6.5, 10, "#DE8A5E"),
    (7, "Armurier et doreur", 73.2, 102.5, 7.0, 6.0, -14, "#4A4258"),
    (8, "Tailleur", 56.5, 78.5, 10.0, 9.0, -45, "#B25A3E"),   # (13/11 : façade tournée vers la place du Marché)
    (9, "Forge", 73.5, 83.0, 6.5, 6.0, -30, "#4A4258"),
    (10, "Halle du marché", 66.0, 88.0, 8.0, 5.0, 0, "#DCAE5C"),
    (11, "Église et clocher", 110.0, 30.0, 11.0, 15.0, 0, "#7A3530"),
    (12, "Maison du gouverneur", 142.0, 34.0, 15.0, 10.0, 6, "#B25A3E"),
    (13, "Moulin", 28.0, 46.0, 6.0, 6.0, 0, "#EFE4CC"),
    (14, "Phare", 193.0, 157.0, 4.5, 4.5, 0, "#EFE4CC"),
    (15, "Batterie du fort", 190.0, 138.0, 16.0, 10.0, 20, "#7D7488"),
    (16, "Entrepôts", 153.0, 92.0, 9.0, 6.5, 30, "#6A4532"),
    (17, "Cimetière marin", 78.0, 32.0, 14.0, 9.0, -6, "#93C4A6"),
    (18, "Cabanes de pêcheurs", 30.0, 124.5, 22.0, 5.0, 5, "#9C6A43"),
    (19, "Bains et lavoir", 94.0, 55.5, 7.0, 5.0, 4, "#5F8FB0"),
    (20, "Capitainerie", 105.0, 97.5, 0.1, 0.1, 0, "#DCAE5C"),
]
NAMED = [n for n in NAMED if n[4] > 1.0]
blocks = []     # (x, y, rayon) : ce qui occupe déjà la place
for _n, _name, x, y, w, d, _a, _c in NAMED:
    blocks.append((x, y, math.hypot(w, d) * 0.5))
for _n, x, y, rx, ry in PLAZAS:
    blocks.append((x, y, min(rx, ry)))


def seg_dist(p, a, b):
    ax, ay, bx, by = a[0], a[1], b[0], b[1]
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy + 1e-9)))
    return math.hypot(p[0] - (ax + t * dx), p[1] - (ay + t * dy))


def street_clear(p, r):
    for _name, pts, w in STREETS:
        for a, b in zip(pts, pts[1:]):
            if seg_dist(p, a, b) < w * 0.5 + r:
                return False
    return True


def inside_poly(p, pts):
    n, c = len(pts), False
    for i in range(n):
        (x0, y0), (x1, y1) = pts[i], pts[(i + 1) % n]
        if (y0 > p[1]) != (y1 > p[1]) and p[0] < (x1 - x0) * (p[1] - y0) / (y1 - y0) + x0:
            c = not c
    return c


# ------------------------------------------------------------------ maisons : le long des rues, des deux côtés, de guingois
houses = []
PATHS = []      # sentiers des maisons en retrait : [porte, point de la rue]

# 13/11, retour de Jimmy sur la maquette grise : « les maisons sont l'une sur l'autre, on se sent à l'étroit ». Même leçon que pour
# le bateau : de la place pour circuler. Règles : jamais moins de GAP m entre deux bâtiments (une ruelle où l'on passe à deux),
# GAP_NAMED autour d'un service ou d'un repère, STREET_MARGIN entre un mur et le bord d'une rue.
GAP = 3.0
GAP_NAMED = 3.2
STREET_MARGIN = 0.8
solids = []      # (cx, cy, w, d, angle, écart voulu) : tout ce qui a des murs


def corners_of(cx, cy, w, d, ang, grow=0.0):
    return rot_rect(cx, cy, w + grow * 2.0, d + grow * 2.0, ang)


def rects_overlap(a, b):
    """Deux rectangles tournés se touchent-ils ? (axes séparateurs)"""
    for poly in (a, b):
        for i in range(4):
            x0, y0 = poly[i]
            x1, y1 = poly[(i + 1) % 4]
            nx, ny = y1 - y0, -(x1 - x0)
            pa = [nx * x + ny * y for x, y in a]
            pb = [nx * x + ny * y for x, y in b]
            if max(pa) < min(pb) or max(pb) < min(pa):
                return False
    return True


def rect_clear_of_streets(cx, cy, w, d, ang):
    pts = corners_of(cx, cy, w, d, ang)
    probes = pts + [((pts[i][0] + pts[(i + 1) % 4][0]) * 0.5, (pts[i][1] + pts[(i + 1) % 4][1]) * 0.5) for i in range(4)] + [(cx, cy)]
    return all(street_clear(q, STREET_MARGIN) for q in probes)


def rect_clear_of_plazas(cx, cy, w, d, ang):
    for q in corners_of(cx, cy, w, d, ang) + [(cx, cy)]:
        for _n, px0, py0, rx, ry in PLAZAS:
            if ((q[0] - px0) / (rx + 1.0)) ** 2 + ((q[1] - py0) / (ry + 1.0)) ** 2 < 1.0:
                return False
    return True


# la terrasse et ses marches occupent le devant de la taverne : (largeur, profondeur) à garder libre devant la façade
FRONT_CLEAR = {3: (17.6, 5.0), 4: (3.0, 1.6), 8: (3.0, 1.6)}
for _num, _name, x, y, w, d, a, _c in NAMED:
    solids.append((x, y, w, d, math.radians(a), GAP_NAMED))
    if _num in FRONT_CLEAR:     # le parvis d'un intérieur (terrasse, marches) : aucune maison dessus
        fw, fd = FRONT_CLEAR[_num]
        ar = math.radians(a)
        off = d * 0.5 + fd * 0.5
        solids.append((x - math.sin(ar) * off, y + math.cos(ar) * off, fw, fd, ar, 0.5))


def along(pts, s):
    """Point et direction à la distance s le long d'une polyligne."""
    for p0, p1 in zip(pts, pts[1:]):
        seg = math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        if s <= seg:
            k = s / seg
            return (p0[0] + (p1[0] - p0[0]) * k, p0[1] + (p1[1] - p0[1]) * k), math.atan2(p1[1] - p0[1], p1[0] - p0[0])
        s -= seg
    return pts[-1], 0.0


for row in (0, 1, 2):                      # 0 : les façades sur la rue ; 1 : un second rang derrière, plus clairsemé (cours, jardins)
    for name, pts, w in STREETS:
        if name in ("montee_fort", "chemin_moulin", "chemin_jungle") or name.startswith("escalier"):
            continue
        sides = (-1,) if name == "quai" else (-1, 1)
        total = sum(math.hypot(q[0] - p0[0], q[1] - p0[1]) for p0, q in zip(pts, pts[1:]))
        for side in sides:
            s = rnd.uniform(1.0, 4.0)
            while s < total - 1.0:
                (bx0, by0), ang = along(pts, s)
                hw, hd = rnd.uniform(6.0, 9.5), rnd.uniform(5.5, 8.0)
                set_back = w * 0.5 + hd * 0.5 + STREET_MARGIN + rnd.uniform(0.3, 1.8) + row * rnd.uniform(10.5, 12.5)   # façades décalées, jamais alignées
                cx = bx0 - math.sin(ang) * side * set_back
                cy = by0 + math.cos(ang) * side * set_back
                rr = math.hypot(hw, hd) * 0.5
                ok = cy < coast_y(cx) - 5.0 and 4 < cx < W - 4 and cy > 22   # (13/11 : plus de maison isolée tout au fond)
                # 13/11 (Jimmy : « des maisons devant le tailleur, on ne comprend pas qu'on peut y entrer ») : rien entre le
                # tailleur et la place du Marché, ni devant sa façade
                ok = ok and not (42 < cx < 65 and 81 < cy < 100)
                # direction de la maison vers sa rue (plan : y vers le bas) ; la façade est le côté « sud » du repère de la maison
                to_street = (math.sin(ang) * side, -math.cos(ang) * side)
                turn = math.atan2(-to_street[0], to_street[1]) + rnd.uniform(-0.07, 0.07)
                if abs(math.cos(turn - ang)) < 0.5:
                    hw, hd = hw, hd      # (la façade est toujours la largeur : rien à échanger, l'angle suit la rue)
                ok = ok and rect_clear_of_streets(cx, cy, hw, hd, turn) and rect_clear_of_plazas(cx, cy, hw, hd, turn)
                mine = corners_of(cx, cy, hw, hd, turn)
                ok = ok and not any(rects_overlap(mine, corners_of(ox, oy, ow, od, oa, og)) for ox, oy, ow, od, oa, og in solids)
                ok = ok and not inside_poly((cx, cy), FORT) and math.hypot(cx - 28, cy - 46) > 23
                # une maison ne chevauche pas le bord d'une terrasse : ses quatre coins sont du même côté du mur
                ok = ok and len(set(inside_poly(q, UP) for q in corners_of(cx, cy, hw, hd, turn, 1.0))) == 1
                if ok and (row == 0 or rnd.random() < 0.75):
                    houses.append((cx, cy, hw, hd, turn, inside_poly((cx, cy), UP)))
                    if row > 0:      # en retrait : un sentier de la porte à la rue
                        door = (cx + to_street[0] * (hd * 0.5 + 0.2), cy + to_street[1] * (hd * 0.5 + 0.2))
                        PATHS.append([door, (bx0 - math.sin(ang) * side * (w * 0.5 - 0.2), by0 + math.cos(ang) * side * (w * 0.5 - 0.2))])
                    solids.append((cx, cy, hw, hd, turn, GAP))
                    blocks.append((cx, cy, rr))
                    s += hw + GAP + rnd.uniform(0.0, 5.0)                       # des trous : jardins, passages, cours
                else:
                    s += 1.0

# jardins et arbres dans les creux
for _k in range(260):
    x, y = rnd.uniform(6, W - 6), rnd.uniform(14, 126)
    if y < coast_y(x) - 4 and street_clear((x, y), 1.6) and all(math.hypot(x - bx, y - by) > br + 1.2 for bx, by, br in blocks) and not inside_poly((x, y), FORT):
        circle(x, y, rnd.uniform(1.2, 2.4), GRASS_D, opacity=0.85)
        circle(x - 0.4, y - 0.5, rnd.uniform(0.6, 1.2), "#A3C650", opacity=0.8)

for a, b in PATHS:
    path([a, b], PAVE, 1.2)
for cx, cy, hw, hd, ang, up in houses:
    poly(rot_rect(cx + 0.6, cy + 0.8, hw, hd, ang), INK, opacity=0.25)                    # ombre
    poly(rot_rect(cx, cy, hw, hd, ang), rnd.choice(FACADES), stroke=INK, sw=0.18)
    poly(rot_rect(cx, cy, hw * 0.96, hd * 0.52, ang), rnd.choice(ROOFS[:3] if not up else ROOFS), opacity=0.9)

for num, name, x, y, w, d, a, c in NAMED:
    ang = math.radians(a)
    poly(rot_rect(x + 0.7, y + 0.9, w, d, ang), INK, opacity=0.3)
    poly(rot_rect(x, y, w, d, ang), c, stroke=BRASS, sw=0.5)

# ------------------------------------------------------------------ pontons, échelles, bateaux
PONTOONS = [("Ponton des pêcheurs", 76, 119.5, 76, 141, 2.6), ("Grand ponton (bateau de l'équipage)", 105, 117, 105, 150, 3.6),
            ("Ponton des marchands", 134, 119.5, 134, 141, 2.6), ("Cale du chantier", 160, 131, 152, 142, 4.0)]
for _n, x0, y0, x1, y1, w in PONTOONS:
    path([(x0, y0), (x1, y1)], "#3A2630", w + 0.6)
    path([(x0, y0), (x1, y1)], WOODC, w)
# le bateau de l'équipage, à quai
poly([(109.5, 128), (112.5, 131), (113, 143), (111.2, 149), (109.5, 143)], "#6A4532", stroke=INK, sw=0.2)
text(118, 139, "bateau", 2.0, anchor="start")
# échelles : sur chaque ponton (bout et milieu) et tous les 18 à 22 m le long du quai et de la grève
LADDERS = [(76, 141.6), (74.4, 130), (105, 150.8), (103, 134), (107, 126), (134, 141.6), (135.6, 130), (57, 124.6), (68, 121.0), (86, 117.6),
           (97, 116.6), (114, 116.6), (125, 117.8), (143, 121.2), (152, 125.4), (166, 140), (176, 154), (207, 153)]
for x, y in LADDERS:
    out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="#E8352B" stroke="%s" stroke-width="%s"/>' % (px(x - 0.7), px(y - 0.7), px(1.4), px(1.4), "#EFE4CC", px(0.25)))

# ------------------------------------------------------------------ vie : PNJ à routine (points) et sources sonores (cercles)
LIFE = [  # (x, y, texte)
    (92, 108, "musicien (terrasse)"), (36, 121, "feu de camp, chants le soir"), (66, 91, "marché : cris, poules"), (73.5, 83, "forge : marteau"),
    (157, 113, "scies, maillets"), (110, 33, "cloche (heures)"), (28, 46, "ailes du moulin"), (134, 86, "fontaine, enfants"),
    (190, 140, "relève de la garde"), (140, 117, "dockers, grue"),
]
for x, y, _t in LIFE:
    circle(x, y, 9.0, "#FFB35C", opacity=0.16)
    circle(x, y, 0.9, "#FFB35C", stroke=INK, sw=0.15)
# boucle des enfants qui courent, ronde de la garde
path([(134, 86), (120, 82), (106, 84), (102, 94), (116, 102), (128, 99), (124, 90), (134, 86)], "#E46BE0", 0.5, dash="3 4")
path([(176, 124), (168, 118), (160, 114), (146, 119), (118, 113.5), (92, 113.5), (64, 119)], "#0072B2", 0.5, dash="3 4")

# ------------------------------------------------------------------ étiquettes
for num, name, x, y, w, d, a, c in NAMED:
    circle(x, y, 1.9, "#EFE4CC", stroke=INK, sw=0.2)
    text(x, y + 0.85, str(num), 2.3, weight="bold", halo=False)
for n, x, y, rx, ry in PLAZAS:
    text(x, y + ry + 2.6, n, 2.3, fill="#3A2630")
text(30, 139.5, "Grève des pêcheurs", 2.6, fill="#3A2630")
text(110, 23, "HAUTE VILLE (+3 à +5 m)", 3.2, weight="bold")
text(100, 79.5, "Grand-Rue", 2.2, fill="#3A2630")
text(110, 70, "VILLE BASSE", 3.2, weight="bold")
text(52, 68, "QUARTIER DU MARCHÉ", 2.6, weight="bold")
text(176, 103, "QUARTIER DES CORDIERS", 2.6, weight="bold")
text(190, 118, "LE CAP (+3 m)", 2.6, weight="bold")
text(28, 22, "jungle (sortie nord-ouest)", 2.3, fill="#EFE4CC", halo=False)
text(105, 166, "LE BASSIN", 4.2, fill="#EFE4CC", weight="bold", halo=False)
text(105, 172, "entrée de la baie : cap et phare à l'est, grève à l'ouest", 2.4, fill="#EFE4CC", halo=False)

# cercles de distance depuis le bateau : 30 m (8 s de marche) et 60 m (17 s)
for r, label in ((30, "30 m : 8 s à pied"), (60, "60 m : 17 s")):
    out.append('<circle cx="%s" cy="%s" r="%s" fill="none" stroke="#FFD23F" stroke-width="%s" stroke-dasharray="%s" opacity="0.9"/>' % (px(105), px(130), px(r), px(0.35), "8 6"))
    text(105 - r * 0.76, 130 + r * 0.72 + 3.0, label, 2.0, fill="#FFD23F", halo=False)

# échelle graphique, nord, comparaison avec la ville actuelle
# l'emprise de la ville actuelle (83 x 92 m), à la même échelle, posée sur le même quai
out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="none" stroke="#EFE4CC" stroke-width="%s" stroke-dasharray="3 6" opacity="0.8"/>' % (px(63.5), px(25), px(83), px(92), px(0.3)))
text(28, 158, "en pointillés blancs : l'emprise de", 2.1, fill="#EFE4CC", halo=False)
text(28, 161.5, "la ville actuelle (83 x 92 m)", 2.1, fill="#EFE4CC", halo=False)
path([(170, 180), (190, 180)], "#EFE4CC", 0.6)
text(180, 178.2, "20 m", 2.2, fill="#EFE4CC", halo=False)
text(210, 178, "N", 3.4, fill="#EFE4CC", weight="bold", halo=False)
path([(210, 186), (210, 180)], "#EFE4CC", 0.5)

# légende
LEG_X, LEG_Y = 160, 4
out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="#EFE4CC" stroke="%s" stroke-width="%s" opacity="0.95"/>' % (px(LEG_X), px(LEG_Y), px(57), px(8 + 3.1 * (len(NAMED) + 5)), INK, px(0.3)))
text(LEG_X + 2, LEG_Y + 4.4, "Port-Cayonne : maquette en plan (v1)", 2.5, anchor="start", weight="bold", halo=False)
yy = LEG_Y + 8.6
for num, name, *_ in NAMED:
    text(LEG_X + 2, yy, "%d  %s" % (num, name), 2.15, anchor="start", halo=False)
    yy += 3.1
for col, label in (("#E8352B", "échelle pour sortir de l'eau"), ("#FFB35C", "vie et son audible de près (rayon 9 m)"), ("#E46BE0", "boucle des enfants qui courent"),
                   ("#0072B2", "ronde de la garde"), ("#FFD23F", "distance depuis le bateau")):
    out.append('<rect x="%s" y="%s" width="%s" height="%s" fill="%s"/>' % (px(LEG_X + 2), px(yy - 1.7), px(2.2), px(1.7), col))
    text(LEG_X + 5.4, yy, label, 2.05, anchor="start", halo=False)
    yy += 3.1


# ------------------------------------------------------------------ le plan en données : data/town_plan.json
# C'est CE fichier que lit le jeu (maquette grise : src/town/town_greybox.gd ; collisions : src/land.gd). Coordonnées du
# « fichier du port », comme l'ancienne ville : x vers l'est, y vers le nord, le bord du quai au grand ponton en (0, 0) ;
# le monde de jeu est (x, -y). Les angles tournent dans le sens trigonométrique de ce repère.
import json


def fx(x):
    return round(x - 105.0, 2)


def fy(y):
    return round(117.0 - y, 2)


def fp(pt):
    return [fx(pt[0]), fy(pt[1])]


# 13/11, décisions de Jimmy : boutiques « mixtes ». intérieur = on entre, coupe sans toit ; tente = grande tente ouverte sur la
# rue, on voit dedans sans entrer (façon Sea of Thieves) ; comptoir = étal ou comptoir sur la rue ; repère = décor et quêtes.
MODES = {1: "tente", 2: "comptoir", 3: "interieur", 4: "interieur", 5: "halle", 6: "tente", 7: "tente", 8: "interieur", 9: "comptoir",
         10: "halle", 11: "repere", 12: "repere", 13: "repere", 14: "repere", 15: "repere", 16: "maison", 17: "jardin", 18: "cabanes", 19: "repere"}
STOREYS = {3: 2, 4: 2, 5: 2, 8: 2, 11: 2, 12: 2, 13: 3, 14: 5, 15: 1, 16: 1, 19: 1}
# qui se tient devant quel bâtiment (identifiants de data/npcs.json) ; décalage le long de la façade en m
STAFF = {1: [("corbin", 0.0)], 5: [("mathurin", 0.0)], 6: [("ariane", 0.0)],
         7: [("armand", -1.8), ("prosper", 1.8)], 15: [("odilon", 0.0)], 11: [("hector", 4.0)]}
# les intérieurs gardés (data/town.json) : l'identifiant de l'intérieur, et la terrasse de la taverne devant sa façade
INTERIORS = {3: "taverne", 4: "magasin", 8: "tailleur"}


land = [fp(q) for q in COAST] + [[115.0, 30.0], [108.0, 78.0], [84.0, 100.0], [40.0, 108.0], [-20.0, 110.0], [-70.0, 104.0], [-100.0, 80.0], [-105.0, 20.0]]
buildings, npcs = [], {}
for num, name, x, y, w, d, a, c in NAMED:
    ang = -math.radians(a)
    mode = MODES.get(num, "repere")
    buildings.append({"id": "b%d" % num, "num": num, "name": name, "x": fx(x), "y": fy(y), "w": w, "d": d, "ang": round(ang, 3),
                      "storeys": STOREYS.get(num, 1), "kind": "service" if mode in ("tente", "comptoir", "interieur", "halle") else "repere", "mode": mode})
    if num in INTERIORS:
        buildings[-1]["interior"] = INTERIORS[num]
        buildings[-1]["door_u"] = 0.0
        buildings[-1]["terrace"] = num == 3
    for who, off in STAFF.get(num, []):
        # devant la façade sud (vers la caméra), à 1,3 m du mur
        lx, ly = off, -(d * 0.5 + 1.3)
        npcs[who] = [round(fx(x) + math.cos(ang) * lx - math.sin(ang) * ly, 2), round(fy(y) + math.sin(ang) * lx + math.cos(ang) * ly, 2)]
for k, (cx, cy, hw, hd, ang, up) in enumerate(houses):
    buildings.append({"id": "m%d" % k, "x": fx(cx), "y": fy(cy), "w": round(hw, 2), "d": round(hd, 2), "ang": round(-ang, 3),
                      "storeys": 1 + (k % 3 != 0) + (k % 11 == 0), "kind": "maison", "mode": "maison"})
plan = {
    "_commentaire": "Plan de la ville v3 (Port-Cayonne), produit par tools/art/town_plan_svg.py : ne pas modifier à la main, changer le script. Coordonnées du fichier du port : x est, y nord, monde de jeu = (x, -y). Lu par src/town/town_greybox.gd (maquette grise) et src/land.gd (collisions).",
    "name": "Port-Cayonne",
    "land": land,
    "sand": [fp(q) for q in [(0, 118), (16, 121), (32, 124), (46, 124), (54, 121), (52, 128), (44, 134), (30, 136), (14, 133), (0, 131)]],
    "levels": [{"id": "haute_ville", "poly": [fp(q) for q in UP], "h": 3.0, "style": "terrasse"},
               {"id": "cap", "poly": [fp(q) for q in FORT], "h": 3.0, "style": "fort"}],
    "ramps": [{"id": "rampe_grand_rue", "a": fp((104, 66.5)), "b": fp((111, 58)), "width": 6.0, "h0": 0.0, "h1": 3.0, "stairs": False},
              {"id": "escalier_est", "a": fp((142.5, 72)), "b": fp((146.5, 60)), "width": 2.4, "h0": 0.0, "h1": 3.0, "stairs": True},
              {"id": "escalier_ouest", "a": fp((68.4, 69.5)), "b": fp((66, 59)), "width": 2.4, "h0": 0.0, "h1": 3.0, "stairs": True},
              {"id": "montee_fort", "a": fp((166, 117)), "b": fp((177.5, 125.5)), "width": 3.5, "h0": 0.0, "h1": 3.0, "stairs": False}],
    "streets": [{"id": n, "pts": [fp(q) for q in pts], "width": w} for n, pts, w in STREETS],
    "paths": [{"pts": [fp(a), fp(b)], "width": 1.2} for a, b in PATHS],
    "plazas": [{"name": n, "x": fx(x), "y": fy(y), "rx": rx, "ry": ry} for n, x, y, rx, ry in PLAZAS],
    "buildings": buildings,
    "pontoons": [{"name": n, "a": fp((x0, y0 - 1.0)), "b": fp((x1, y1)), "width": w} for n, x0, y0, x1, y1, w in PONTOONS],
    "ladders": [fp(q) for q in LADDERS],
    "dock": {"pier_x1": 1.8, "y": -19.0, "heading": "sud"},
    "spawn": [0.0, 6.0],
    "npcs": npcs,
    "wanderers": [{"id": "w_quai", "path": [fp(q) for q in [(64, 119), (92, 113.5), (118, 113.5), (146, 119)]]},
                  {"id": "w_grand_rue", "path": [fp(q) for q in [(105, 104), (102, 94), (106, 84), (100, 75)]]},
                  {"id": "w_marche", "path": [fp(q) for q in [(96, 102), (86, 97), (76, 93), (68, 91)]]},
                  {"id": "w_cordiers", "path": [fp(q) for q in [(116, 102), (128, 99), (140, 101), (152, 106)]]}],
    "life": [{"x": fx(x), "y": fy(y), "what": what} for x, y, what in LIFE],
}
here0 = os.path.dirname(os.path.abspath(__file__))
with open(os.path.normpath(os.path.join(here0, "..", "..", "data", "town_plan.json")), "w", encoding="utf-8", newline="\n") as f:
    json.dump(plan, f, ensure_ascii=False, indent=1)

svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 %s %s" width="%s" height="%s">\n%s\n</svg>\n' % (px(W), px(H), px(W), px(H), "\n".join(out))
here = os.path.dirname(os.path.abspath(__file__))
dest = os.path.normpath(os.path.join(here, "..", "..", "design", "ville-v3"))
os.makedirs(dest, exist_ok=True)
open(os.path.join(dest, "plan-maquette.svg"), "w", encoding="utf-8").write(svg)
print("maisons : %d ; bâtiments nommés : %d ; échelles : %d" % (len(houses), len(NAMED), len(LADDERS)))
