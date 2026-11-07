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
	return false


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
