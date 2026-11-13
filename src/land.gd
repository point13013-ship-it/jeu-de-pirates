class_name Land
extends RefCounted
## Le port vu comme terrain : où un pirate peut marcher à terre, et où la coque d'un bateau touche la terre.
## Tout est en coordonnées du monde de jeu (x, z). Les fichiers du port (port_meta.json) sont en (x, y) avec
## z = -y.

## Terre qui arrête les bateaux (x0, z0, x1, z1) : quai pavé, pontons, plage. Mesurés sur les maillages du
## port (ground_cobble, pier_main/west_ground_planks, ground_sand).
const SHIP_LAND: Array = [
	[-42.0, -92.4, 42.0, 0.0],
	[-50.0, -132.0, 50.0, -92.0],   # (12/11 : la haute ville et sa colline, derrière les remparts)
	[14.0, -0.2, 18.0, 30.0],
	[-24.0, -0.2, -21.0, 14.0],
	# (la plage à l'ouest, [-62, -52, -42, 4], a été retirée : bug 1.5 du lot 1 ; c'est désormais la mer jusqu'au quai)
]

var walk_rects: Array = []   ## [x0, y0, x1, y1] en (x, y) du fichier
var obstacles: Array = []
var circles: Array = []
var island_height: Callable = Callable()   ## (Vector2 monde) -> hauteur du sol d'une île ; vide : tout est plat
var island_steep: Callable = Callable()    ## (Vector2 monde) -> vrai si la pente d'une île est trop raide pour y marcher (13/11 : relief)
var island_discs: Array = [] ## terre des îles : [x, z, rayon] en coordonnées du monde (sol à la hauteur 0)
# Ville v3 (13/11, data/town_plan.json) : le sol et les murs viennent du plan, plus de rectangles écrits à la main.
var walk_polys: Array = []   ## sol où l'on marche : polygones (PackedVector2Array) en (x, y) du fichier
var obbs: Array = []         ## murs : rectangles tournés [cx, cy, demi-largeur, demi-profondeur, angle]
var sand_polys: Array = []   ## plages de la ville (on y sort de l'eau à pied)
var ladders: Array = []      ## échelles du quai et des pontons : Vector2 en (x, y) du fichier
static var ship_polys: Array = []   ## terre qui arrête les bateaux, en coordonnées du monde ; vide : les rectangles SHIP_LAND


## Charge le plan de la ville v3 : sol (terre et pontons), murs des bâtiments, plages, échelles.
func load_plan(plan: Dictionary) -> void:
	walk_rects = []
	obstacles = []
	circles = []
	walk_polys = [_poly(plan.get("land", []))]
	sand_polys = [_poly(plan.get("sand", []))]
	ship_polys = [_world_poly(plan.get("land", []))]
	for pt: Dictionary in plan.get("pontoons", []):
		var a := Vector2(float(pt["a"][0]), float(pt["a"][1]))
		var b := Vector2(float(pt["b"][0]), float(pt["b"][1]))
		var side := (b - a).normalized().orthogonal() * float(pt["width"]) * 0.5
		var quad := [[a.x + side.x, a.y + side.y], [b.x + side.x, b.y + side.y], [b.x - side.x, b.y - side.y], [a.x - side.x, a.y - side.y]]
		walk_polys.append(_poly(quad))
		ship_polys.append(_world_poly(quad))
	obbs = []
	for b: Dictionary in plan.get("buildings", []):
		if str(b.get("mode", "")) in ["tente", "comptoir", "halle", "jardin"]:
			continue   # ouverts : on y entre à pied (leurs poteaux et comptoirs sont des cercles, posés par la maquette)
		obbs.append([float(b["x"]), float(b["y"]), float(b["w"]) * 0.5, float(b["d"]) * 0.5, float(b["ang"])])
	ladders = []
	for l: Array in plan.get("ladders", []):
		# 13/11 : le point du plan est un peu en retrait ; l'échelle est au vrai bord du sol, côté eau (comme la maquette la dessine)
		var at := Vector2(float(l[0]), float(l[1]))
		var out := Vector2.ZERO
		for k in 16:
			var dir := Vector2.from_angle(TAU * k / 16.0)
			if not _in_walk_polys(at + dir * 1.1):
				out += dir
		out = out.normalized() if out.length() > 0.01 else Vector2(0, -1)
		for step in 40:
			if not _in_walk_polys(at + out * 0.1):
				break
			at += out * 0.1
		ladders.append(at)


func _in_walk_polys(m: Vector2) -> bool:
	for poly: PackedVector2Array in walk_polys:
		if Geometry2D.is_point_in_polygon(m, poly):
			return true
	return false


static func _poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Array in pts:
		out.append(Vector2(float(q[0]), float(q[1])))
	return out


static func _world_poly(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for q: Array in pts:
		out.append(Vector2(float(q[0]), -float(q[1])))
	return out


static func _in_obb(m: Vector2, o: Array) -> bool:
	var d := (m - Vector2(float(o[0]), float(o[1]))).rotated(-float(o[4]))
	return absf(d.x) < float(o[2]) and absf(d.y) < float(o[3])


## Vrai si le point monde `p` est sur le sol de la ville v3 (terre ou ponton), pas sur une île.
func on_town(p: Vector2) -> bool:
	for poly: PackedVector2Array in walk_polys:
		if Geometry2D.is_point_in_polygon(Vector2(p.x, -p.y), poly):
			return true
	return false


## Ville v3 : un nageur ne sort de l'eau que par une plage ou par une échelle (à moins de `reach` m).
func can_exit_water(p: Vector2, reach: float) -> bool:
	if walk_polys.is_empty() or not on_town(p):
		return true
	var m := Vector2(p.x, -p.y)
	for poly: PackedVector2Array in sand_polys:
		if Geometry2D.is_point_in_polygon(m, poly):
			return true
	for l: Vector2 in ladders:
		if l.distance_to(m) <= reach:
			return true
	return false


## 13/11 — l'ancienne ville posée ailleurs (ville secondaire) : ses rectangles de sol, ses murs, ses poteaux et la terre qui
## arrête les bateaux s'ajoutent à ceux de la ville v3, décalés de `at` (monde x, z). `min_x` : coupe de la plage ouest retirée.
func add_port(meta: Dictionary, at: Vector2, min_x: float) -> void:
	var s := Vector2(at.x, -at.y)   # (le même décalage dans le repère du fichier : y = -z)
	for r: Array in meta.get("walk_rects", []):
		walk_rects.append([float(r[0]) + s.x, float(r[1]) + s.y, float(r[2]) + s.x, float(r[3]) + s.y])
	for o: Array in meta.get("obstacles", []):
		obstacles.append([float(o[0]) + s.x, float(o[1]) + s.y, float(o[2]) + s.x, float(o[3]) + s.y])
	for c: Array in meta.get("circles", []):
		if float(c[0]) > min_x:
			circles.append([float(c[0]) + s.x, float(c[1]) + s.y, float(c[2])])
	for r: Array in SHIP_LAND:
		ship_polys.append(PackedVector2Array([Vector2(float(r[0]), float(r[1])) + at, Vector2(float(r[2]), float(r[1])) + at,
				Vector2(float(r[2]), float(r[3])) + at, Vector2(float(r[0]), float(r[3])) + at]))


## Ses terrasses, ses escaliers et ses intérieurs (data/town.json), décalés de même (« xf », voir _lm). À appeler après load_town.
func add_town(cfg: Dictionary, at: Vector2) -> void:
	var xf := [0.0, 0.0, at.x, -at.y, 0.0]
	for l: Dictionary in cfg.get("levels", []):
		var l2: Dictionary = l.duplicate(true)
		l2["xf"] = xf
		levels.append(l2)
	for it: Dictionary in cfg.get("interiors", []):
		var it2: Dictionary = it.duplicate(true)
		it2["xf"] = xf
		interiors.append(it2)


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


## Vrai si le point monde p = (x, z) est en mer (ni sur le port, ni sur une île) : un saut y finit à la nage.
func is_over_water(p: Vector2) -> bool:
	return not _on_ground(Vector2(p.x, -p.y))


func _on_ground(m: Vector2) -> bool:
	for r: Array in walk_rects:
		if m.x >= float(r[0]) and m.x <= float(r[2]) and m.y >= float(r[1]) and m.y <= float(r[3]):
			return true
	for poly: PackedVector2Array in walk_polys:
		if Geometry2D.is_point_in_polygon(m, poly):
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
	for o: Array in obbs:
		if _in_obb(m, o):
			return true
	for c: Array in circles:
		if m.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]):
			return true
	if island_steep.is_valid() and island_steep.call(Vector2(m.x, -m.y)):
		return true   # (une falaise ou un flanc trop raide d'une île à relief)
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
		if _ship_hits(p):
			return true
	return false


static func _ship_hits(p: Vector2) -> bool:
	if not ship_polys.is_empty():
		for poly: PackedVector2Array in ship_polys:
			if Geometry2D.is_point_in_polygon(p, poly):
				return true
		return false
	for r: Array in SHIP_LAND:
		if p.x > float(r[0]) and p.x < float(r[2]) and p.y > float(r[1]) and p.y < float(r[3]):
			return true
	return false


## Indice du premier point sur la terre ferme, ou -1.
static func hit_index(points: Array) -> int:
	for i in points.size():
		if _ship_hits(points[i]):
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
	var inside_from := interior_at(from)
	for t: Vector2 in [from + delta, Vector2(from.x + delta.x, from.y), Vector2(from.x, from.y + delta.y)]:
		var h := walk_height(t, cur)
		if h != NO_SURFACE:
			# 13/11 (retour : « on traverse les murs des maisons où l'on peut entrer ») : on ne passe du dehors au dedans (et
			# l'inverse) que par la porte
			var inside_to := interior_at(t)
			if inside_to != inside_from and not _through_door(from, t, inside_to if inside_to >= 0 else inside_from):
				continue
			return Vector3(t.x, t.y, h)
	if walk_height(from, cur) == NO_SURFACE:
		# 13/11 (retour : « on traverse les murs des maisons ») : un pirate posé à la mauvaise hauteur (au pied d'une terrasse,
		# après un saut) passait pour « coincé » et traversait alors tout, murs compris. S'il y a un sol sous lui à une autre
		# hauteur, on le recale dessus au lieu de le laisser filer ; il ne sort librement que s'il est vraiment dans un obstacle.
		var m := Vector2(from.x, -from.y)
		if _surface_h(m, cur) == NO_SURFACE:
			var best := NO_SURFACE
			for h2 in _candidates(m):
				if best == NO_SURFACE or absf(h2 - cur) < absf(best - cur):
					best = h2
			if best != NO_SURFACE:
				return Vector3(from.x, from.y, best)
		return Vector3(from.x + delta.x, from.y + delta.y, cur)   # coincé : on laisse sortir
	return Vector3(from.x, from.y, cur)


## Vrai si le pas de `a` à `b` (monde x/z) passe par la porte de l'intérieur `idx` : l'un des deux points est dans
## l'embrasure (élargie d'un demi-pas). Un intérieur sans porte décrite laisse passer partout (comme avant).
func _through_door(a: Vector2, b: Vector2, idx: int) -> bool:
	if idx < 0 or idx >= interiors.size():
		return true
	var it: Dictionary = interiors[idx]
	if not it.has("door_cut"):
		return true
	var r: Array = it["door_cut"]
	for p: Vector2 in [a, b]:
		var m := _lm(Vector2(p.x, -p.y), it)
		if m.x >= float(r[0]) - 0.35 and m.x <= float(r[2]) + 0.35 and m.y >= float(r[1]) - 0.7 and m.y <= float(r[3]) + 0.7:
			return true
	return false


## Hauteur de saut (m au-dessus du sol) qui suffit pour passer au-dessus d'un poteau, d'un tonneau ou d'un arbuste.
const LOW_CLEAR := 0.5


## Vrai si un pirate en l'air, à `alt` mètres au-dessus du sol, peut se trouver en `p` (monde x/z). Contrairement à la marche, un
## saut ne s'arrête pas au bord du quai ni de la plage (c'est ce qui l'empêchait de plonger ou de franchir un vide) : seuls les
## murs des bâtiments l'arrêtent, et les petits obstacles (poteaux, tonneaux, arbres) tant qu'on est trop bas.
func air_clear(p: Vector2, alt: float) -> bool:
	var m := Vector2(p.x, -p.y)
	for o: Array in obstacles:
		if m.x > float(o[0]) and m.x < float(o[2]) and m.y > float(o[1]) and m.y < float(o[3]):
			return false
	for o: Array in obbs:
		if _in_obb(m, o):
			return false
	if alt < LOW_CLEAR:
		for c: Array in circles:
			if m.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]):
				return false
	return true


## Fait avancer un pirate en l'air de `delta` à partir de `from` : libre au-dessus du vide et des petits obstacles, en glissant le
## long des murs. À l'intérieur d'un bâtiment, les murs comptent comme à pied (`cur` : hauteur du sol sous le pirate).
func air_move(from: Vector2, delta: Vector2, alt: float, cur: float) -> Vector2:
	if interior_at(from) >= 0 or interior_at(from + delta) >= 0:
		var r := step(from, delta, cur)
		return Vector2(r.x, r.y)
	for t: Vector2 in [from + delta, Vector2(from.x + delta.x, from.y), Vector2(from.x, from.y + delta.y)]:
		if air_clear(t, alt) and not _raised_wall(t, cur + alt):
			return t
	return from


## Vrai si, en `p`, le seul sol est plus haut que les pieds (`alt` absolue) : le flanc d'une estrade, d'une terrasse ou d'un
## plateau d'île qu'on n'a pas sauté assez haut pour franchir. On glisse contre, au lieu de passer « dessous » et d'être ensuite
## renvoyé au point de départ.
func _raised_wall(p: Vector2, alt: float) -> bool:
	if is_over_water(p):
		return false
	return not _candidates(Vector2(p.x, -p.y)).is_empty() and surface_below(p, alt) == NO_SURFACE


## Ce qui se dresse en `p` (monde x/z) et qu'un crochet peut saisir : « mur » (bâtiment), « objet » (poteau, tonneau, arbre) ou « ».
func blocker_at(p: Vector2) -> String:
	var m := Vector2(p.x, -p.y)
	for o: Array in obstacles:
		if m.x > float(o[0]) and m.x < float(o[2]) and m.y > float(o[1]) and m.y < float(o[3]):
			return "mur"
	for o: Array in obbs:
		if _in_obb(m, o):
			return "mur"
	for c: Array in circles:
		if m.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]):
			return "objet"
	return ""


## Indice de l'intérieur qui contient le point monde `p`, ou -1 (dehors).
func interior_at(p: Vector2) -> int:
	var m := Vector2(p.x, -p.y)
	for i in interiors.size():
		var it: Dictionary = interiors[i]
		if _in_rect(_lm(m, it), it["footprint"]):
			return i
	return -1


## Ville v3 : un intérieur ou un niveau de data/town.json peut être déplacé et tourné (« xf » : [ancien centre x, y, nouveau
## centre x, y, angle]). Ses rectangles restent écrits dans leur repère d'origine : on y ramène le point à tester.
static func _lm(m: Vector2, s: Dictionary) -> Vector2:
	if not s.has("xf"):
		return m
	var x: Array = s["xf"]
	return (m - Vector2(float(x[2]), float(x[3]))).rotated(-float(x[4])) + Vector2(float(x[0]), float(x[1]))


## L'inverse : un point du repère d'origine d'une surface, dans le repère du fichier.
static func from_local(m: Vector2, s: Dictionary) -> Vector2:
	if not s.has("xf"):
		return m
	var x: Array = s["xf"]
	return (m - Vector2(float(x[0]), float(x[1]))).rotated(float(x[4])) + Vector2(float(x[2]), float(x[3]))


static func _in_rect(m: Vector2, r: Array) -> bool:
	return m.x >= float(r[0]) and m.x <= float(r[2]) and m.y >= float(r[1]) and m.y <= float(r[3])


## Ville v3 : une surface est un rectangle (« rect »), un polygone (« poly » : terrasse, cap) ou une rampe orientée (« ramp » :
## [ax, ay, bx, by, largeur], la hauteur va de h0 en a à h1 en b ; escalier ou pente).
static func _in_surface(m: Vector2, s: Dictionary) -> bool:
	if s.has("rect"):
		return _in_rect(m, s["rect"])
	if s.has("ramp"):
		var r: Array = s["ramp"]
		var a := Vector2(float(r[0]), float(r[1]))
		var ab := Vector2(float(r[2]), float(r[3])) - a
		var t := (m - a).dot(ab) / ab.length_squared()
		return t >= 0.0 and t <= 1.0 and absf((m - a).cross(ab.normalized())) <= float(r[4]) * 0.5
	if s.has("poly"):
		return Geometry2D.is_point_in_polygon(m, s["poly"])
	return false


## Hauteur de la surface `s` au point m : plate, ou en pente le long de son axe.
static func _rect_h(s: Dictionary, m: Vector2) -> float:
	if s.has("ramp"):
		var rr: Array = s["ramp"]
		var a := Vector2(float(rr[0]), float(rr[1]))
		var ab := Vector2(float(rr[2]), float(rr[3])) - a
		return lerpf(float(s["h0"]), float(s["h1"]), clampf((m - a).dot(ab) / ab.length_squared(), 0.0, 1.0))
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
		if it.has("door_cut") and _in_rect(_lm(m, it), it["door_cut"]):
			return true
	return false


## Hauteur de la plus haute surface SOUS un pirate en l'air dont les pieds sont à l'altitude absolue `alt` (une marche de
## tolérance au-dessus), ou NO_SURFACE. C'est ce qu'il faut à la fin d'un saut : `surface_h` ne cherche qu'à une marche de la
## hauteur du sol d'où l'on est parti, et ne voyait donc jamais une estrade ou un plateau plus haut que ça. Le jeu renvoyait
## alors le pirate à son point de départ (bug 1.1 du lot 1).
func surface_below(p: Vector2, alt: float) -> float:
	var best := NO_SURFACE
	for h in _candidates(Vector2(p.x, -p.y)):
		if h <= alt + step_tol and (best == NO_SURFACE or h > best):
			best = h
	return best


## Le point le plus proche de `p` (monde x/z) où un pirate tient debout à la hauteur `h`, ou Vector2.INF à plus de `max_dist`.
func nearest_standable(p: Vector2, h: float, max_dist: float) -> Vector2:
	if walk_height(p, h) != NO_SURFACE:
		return p
	var d := 0.1
	while d <= max_dist:
		for k in 16:
			var q := p + Vector2.from_angle(TAU * k / 16.0) * d
			if walk_height(q, h) != NO_SURFACE:
				return q
		d += 0.1
	return Vector2.INF


## Toutes les hauteurs de sol possibles au point m (coordonnées du fichier), à toutes les hauteurs.
func _candidates(m: Vector2) -> Array[float]:
	var cands: Array[float] = []
	var surfaces: Array = levels
	var base_ok := false
	var idx := -1
	for i in interiors.size():
		if _in_rect(_lm(m, interiors[i]), (interiors[i] as Dictionary)["footprint"]):
			idx = i
	if idx >= 0:
		surfaces = (interiors[idx] as Dictionary)["surfaces"]
		m = _lm(m, interiors[idx])   # (les surfaces d'un intérieur sont dans son repère d'origine)
	else:
		base_ok = _on_ground(m) and (not _blocked(m) or _in_door_cut(m))
	var carved := false
	var on_ramp := false   # (ville v3 : là où passe une rampe, elle seule compte : elle entaille la terrasse qu'elle rejoint)
	for s: Dictionary in surfaces:
		if _in_surface(_lm(m, s), s) and s.get("solid", false):
			carved = true
			if s.has("ramp"):
				on_ramp = true
	for s: Dictionary in surfaces:
		var ml := _lm(m, s)
		if not _in_surface(ml, s) or (on_ramp and s.has("poly")):
			continue
		if s.has("poly") and _blocked(m):
			continue   # (un mur de bâtiment posé sur une terrasse arrête comme au sol)
		if s.get("base", false):
			if not carved and not _blocked_by(ml, s):
				cands.append(float(s["h"]))
		elif not _blocked_by(ml, s):
			cands.append(_rect_h(s, ml))
	if base_ok and not carved:
		cands.append(_ground_level(m))
	return cands


func _surface_h(m: Vector2, cur: float) -> float:
	var cands := _candidates(m)
	var best := NO_SURFACE
	var best_d := step_tol + 0.0001
	for h in cands:
		if absf(h - cur) < best_d:
			best_d = absf(h - cur)
			best = h
	return best
