class_name Land
extends RefCounted
## Le port vu comme terrain : où un pirate peut marcher à terre, et où la coque d'un bateau touche la terre.
## Tout est en coordonnées du monde de jeu (x, z). Les fichiers du port (port_meta.json) sont en (x, y) avec
## z = -y.

## Terre qui arrête les bateaux (x0, z0, x1, z1) : quai pavé, pontons, plage. Mesurés sur les maillages du
## port (ground_cobble, pier_main/west_ground_planks, ground_sand).
const SHIP_LAND: Array = [
	[-42.0, -52.0, 42.0, 0.0],
	[14.0, -0.2, 18.0, 30.0],
	[-24.0, -0.2, -21.0, 14.0],
	[-62.0, -52.0, -42.0, 4.0],
]

var walk_rects: Array = []   ## [x0, y0, x1, y1] en (x, y) du fichier
var obstacles: Array = []
var circles: Array = []
var island_height: Callable = Callable()   ## (Vector2 monde) -> hauteur du sol d'une île ; vide : tout est plat
var island_discs: Array = [] ## terre des îles : [x, z, rayon] en coordonnées du monde (sol à la hauteur 0)


func load_meta(meta: Dictionary) -> void:
	walk_rects = meta.get("walk_rects", [])
	obstacles = meta.get("obstacles", [])
	circles = meta.get("circles", [])


## Vrai si un personnage de rayon `r` peut se tenir en p = (x, z).
func is_walkable(p: Vector2, r: float = 0.22) -> bool:
	for off: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		var q := p + off
		if not _on_ground(Vector2(q.x, -q.y)) or _blocked(Vector2(q.x, -q.y)):
			return false
	return true


func _on_ground(m: Vector2) -> bool:
	for r: Array in walk_rects:
		if m.x >= float(r[0]) and m.x <= float(r[2]) and m.y >= float(r[1]) and m.y <= float(r[3]):
			return true
	for d: Array in island_discs:
		if Vector2(float(d[0]), float(d[1])).distance_to(Vector2(m.x, -m.y)) <= float(d[2]):
			return true
	return false


## Hauteur du sol de base : 0 au port, celle du relief sur une île (plateaux, rampes).
func _ground_level(m: Vector2) -> float:
	if island_height.is_valid() and not island_discs.is_empty():
		for d: Array in island_discs:
			if Vector2(float(d[0]), float(d[1])).distance_to(Vector2(m.x, -m.y)) <= float(d[2]):
				return float(island_height.call(Vector2(m.x, -m.y)))
	return 0.0


func _blocked(m: Vector2) -> bool:
	for o: Array in obstacles:
		if m.x > float(o[0]) and m.x < float(o[2]) and m.y > float(o[1]) and m.y < float(o[3]):
			return true
	for c: Array in circles:
		if m.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]):
			return true
	return false


## Déplace `from` de `delta` en glissant le long des obstacles. Un point déjà coincé peut toujours en sortir.
func move_with_slide(from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	if is_walkable(target):
		return target
	if is_walkable(Vector2(target.x, from.y)):
		return Vector2(target.x, from.y)
	if is_walkable(Vector2(from.x, target.y)):
		return Vector2(from.x, target.y)
	if not is_walkable(from):
		return target   # coincé dans un obstacle : on laisse sortir
	return from


## Le point marchable le plus proche de p (recherche en spirale), ou p si rien à moins de `max_dist`.
func nearest_walkable(p: Vector2, max_dist: float = 8.0) -> Vector2:
	if is_walkable(p):
		return p
	var d := 0.25
	while d <= max_dist:
		for k in 24:
			var q := p + Vector2.from_angle(TAU * k / 24.0) * d
			if is_walkable(q):
				return q
		d += 0.25
	return p


## Vrai si l'un des points est sur la terre ferme.
static func hits_land(points: Array) -> bool:
	for p: Vector2 in points:
		for r: Array in SHIP_LAND:
			if p.x > float(r[0]) and p.x < float(r[2]) and p.y > float(r[1]) and p.y < float(r[3]):
				return true
	return false


## Indice du premier point sur la terre ferme, ou -1.
static func hit_index(points: Array) -> int:
	for i in points.size():
		var p: Vector2 = points[i]
		for r: Array in SHIP_LAND:
			if p.x > float(r[0]) and p.x < float(r[2]) and p.y > float(r[1]) and p.y < float(r[3]):
				return i
	return -1


# ------------------------------------------------------------------ hauteurs, escaliers, intérieurs
# Tout est décrit dans data/town.json, en coordonnées du fichier du port (x, y) ; le monde de jeu est (x, -y).
# Un « niveau » est un rectangle de sol à une hauteur donnée, ou en pente (escalier : hauteur de h0 à h1 le
# long de l'axe). Un niveau « solid » retire le sol de base dessous (on ne passe pas sous un escalier ni sous
# une terrasse pleine) ; un niveau qui ne l'est pas (une galerie) laisse passer dessous. À chaque point on
# garde la hauteur la plus proche de celle du pirate, à une marche près : on ne saute pas d'un étage à l'autre.
# Un intérieur est actif quand le pirate est dans son emplacement au sol : seuls ses niveaux comptent alors.

const NO_SURFACE := INF

var step_tol := 0.3
var levels: Array = []
var interiors: Array = []


## Charge data/town.json (niveaux extérieurs et intérieurs).
func load_town(cfg: Dictionary) -> void:
	step_tol = float(cfg.get("step_tolerance", 0.3))
	levels = cfg.get("levels", [])
	interiors = cfg.get("interiors", [])


## Hauteur du sol sous le point monde `p` (x, z) pour un pirate à la hauteur `cur`, ou NO_SURFACE.
func surface_h(p: Vector2, cur: float) -> float:
	return _surface_h(Vector2(p.x, -p.y), cur)


## Vrai si un pirate de rayon `r` à la hauteur `cur` peut se tenir en `p` ; renvoie sa hauteur ou NO_SURFACE.
func walk_height(p: Vector2, cur: float, r: float = 0.22) -> float:
	var m := Vector2(p.x, -p.y)
	var h := _surface_h(m, cur)
	if h == NO_SURFACE:
		return NO_SURFACE
	for off: Vector2 in [Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
		if _surface_h(m + off, h) == NO_SURFACE:
			return NO_SURFACE
	return h


## Fait avancer un pirate de `delta` à partir de `from` (hauteur `cur`), en glissant le long des obstacles.
## Renvoie (x, z, hauteur).
func step(from: Vector2, delta: Vector2, cur: float) -> Vector3:
	for t: Vector2 in [from + delta, Vector2(from.x + delta.x, from.y), Vector2(from.x, from.y + delta.y)]:
		var h := walk_height(t, cur)
		if h != NO_SURFACE:
			return Vector3(t.x, t.y, h)
	if walk_height(from, cur) == NO_SURFACE:
		return Vector3(from.x + delta.x, from.y + delta.y, cur)   # coincé : on laisse sortir
	return Vector3(from.x, from.y, cur)


## Indice de l'intérieur qui contient le point monde `p`, ou -1 (dehors).
func interior_at(p: Vector2) -> int:
	var m := Vector2(p.x, -p.y)
	for i in interiors.size():
		if _in_rect(m, (interiors[i] as Dictionary)["footprint"]):
			return i
	return -1


static func _in_rect(m: Vector2, r: Array) -> bool:
	return m.x >= float(r[0]) and m.x <= float(r[2]) and m.y >= float(r[1]) and m.y <= float(r[3])


## Hauteur de la surface `s` au point m : plate, ou en pente le long de son axe.
static func _rect_h(s: Dictionary, m: Vector2) -> float:
	if not s.has("axis"):
		return float(s["h"])
	var r: Array = s["rect"]
	var t := 0.0
	if s["axis"] == "y":
		t = (m.y - float(r[1])) / (float(r[3]) - float(r[1]))
	else:
		t = (m.x - float(r[0])) / (float(r[2]) - float(r[0]))
	return lerpf(float(s["h0"]), float(s["h1"]), clampf(t, 0.0, 1.0))


static func _blocked_by(m: Vector2, s: Dictionary) -> bool:
	for o: Array in s.get("obstacles", []):
		if m.x > float(o[0]) and m.x < float(o[2]) and m.y > float(o[1]) and m.y < float(o[3]):
			return true
	for c: Array in s.get("circles", []):
		if m.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]):
			return true
	return false


func _in_door_cut(m: Vector2) -> bool:
	for it: Dictionary in interiors:
		if it.has("door_cut") and _in_rect(m, it["door_cut"]):
			return true
	return false


func _surface_h(m: Vector2, cur: float) -> float:
	var cands: Array[float] = []
	var surfaces: Array = levels
	var base_ok := false
	var idx := -1
	for i in interiors.size():
		if _in_rect(m, (interiors[i] as Dictionary)["footprint"]):
			idx = i
	if idx >= 0:
		surfaces = (interiors[idx] as Dictionary)["surfaces"]
	else:
		base_ok = _on_ground(m) and (not _blocked(m) or _in_door_cut(m))
	var carved := false
	for s: Dictionary in surfaces:
		if _in_rect(m, s["rect"]) and s.get("solid", false):
			carved = true
	for s: Dictionary in surfaces:
		if not _in_rect(m, s["rect"]):
			continue
		if s.get("base", false):
			if not carved and not _blocked_by(m, s):
				cands.append(float(s["h"]))
		elif not _blocked_by(m, s):
			cands.append(_rect_h(s, m))
	if base_ok and not carved:
		cands.append(_ground_level(m))
	var best := NO_SURFACE
	var best_d := step_tol + 0.0001
	for h in cands:
		if absf(h - cur) < best_d:
			best_d = absf(h - cur)
			best = h
	return best
