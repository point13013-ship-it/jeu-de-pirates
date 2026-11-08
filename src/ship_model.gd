class_name ShipModel
extends Node3D
## Modèle 3D d'un bateau et ses données de jeu : collisions du pont, cabine, points d'interaction.
## Les calculs de jeu se font dans le repère du modèle (x vers l'étrave, y vers bâbord, en mètres
## avant mise à l'échelle) ; to_local3() convertit vers la scène Godot.

const SCALE := 1.5            ## mètres de jeu par unité du modèle
const WALK_RADIUS := 0.12     ## rayon du personnage, en unités du modèle
const RAIL_MARGIN := 0.28      ## distance minimale du pirate au plat-bord
const MIN_LANE := 0.45        ## demi-largeur minimale du couloir de marche (vers l'étrave)

var ship_name: String = ""
var meta: Dictionary = {}
var shift: float = 0.0
var length: float = 16.0
var beam: float = 5.6
var boxes: Array = []          ## [x0, y0, x1, y1]
var circles: Array = []        ## [x, y, rayon]
var cabin: Dictionary = {}
var cannons: Array = []        ## [x, y, côté, z]
var ladders: Array = []        ## [x, y du pirate, côté, y de la coque] : échelles de coque
var nests: Array = []          ## [x, y, z du plancher, hauteur du mât]
var mast_ladder: Array = []    ## [x, y, z bas, z haut] : échelle du mât le plus haut, vers son nid
var bow_x := 0.0               ## abscisse la plus avancée où l'on peut se tenir (la pointe)
var low_boxes: Array = []      ## indices des boîtes qu'on peut enjamber d'un saut (caisses), les autres sont des murs
var low_circles: Array = []    ## indices des cercles qu'on peut enjamber (barre, tonneau) ; les mâts sont trop hauts
var cannon_stubs: Array = []   ## les petits canons du modèle d'origine, masqués : le jeu pose des canons plus gros (ShipCannons)
var masts: Array = []          ## [x, hauteur] de chaque mât
var crate_pos := Vector2.INF   ## où se trouve la pile de caisses du pont (repère du modèle), INF si le modèle n'en a pas
var stash_pos := Vector2.INF   ## où se trouve le coffre du capitaine, dans la cabine (repère du modèle)

const RAIL_HEIGHT := 0.5       ## m : au-dessus de cette hauteur de saut, on passe par-dessus le plat-bord
const LOW_CLEAR := 0.65        ## m : hauteur de saut qui suffit pour enjamber une caisse, un tonneau ou la roue

var _model: Node3D
var _sails: Array = []         ## {node, top, base: Transform3D, alpha}
var _sail_pivot: Array = []    ## par voile : abscisse (repère du glb) de l'axe du mât autour duquel elle pivote, NAN si elle ne pivote pas
var _sail_open_v := 1.0
var _sail_trim_v := 0.0
var _cuts: Array = []          ## {node, normal: Vector2, always: bool}


## Charge le modèle `p_name` (sloop, brigantin, galion). Renvoie false si un fichier manque.
func load_ship(p_name: String) -> bool:
	var scene := load("res://assets/models/ship/%s.glb" % p_name) as PackedScene
	var f := FileAccess.open("res://assets/models/ship/%s_meta.json" % p_name, FileAccess.READ)
	if scene == null or f == null:
		return false
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	if not parsed is Dictionary:
		return false
	ship_name = p_name
	meta = parsed
	shift = float(meta.get("shift", 0.0))
	length = float(meta.get("length", 16.0))
	beam = float(meta.get("beam", 5.6))
	boxes = meta.get("boxes", [])
	circles = meta.get("circles", [])
	cabin = meta.get("cabin", {})
	cannons = meta.get("cannons", [])
	ladders = meta.get("ladders", [])
	nests = meta.get("nests", [])
	mast_ladder = meta.get("mast_ladder", [])
	bow_x = float(meta.get("bow_x", length * 0.5 - 0.4))
	masts = meta.get("masts", [])
	_compute_low_obstacles()
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_index_nodes(_model)
	_compute_sail_pivots()
	return true


## Quels obstacles du pont un saut peut enjamber : tout ce qui n'est pas un mur de cabine ni un mât.
func _compute_low_obstacles() -> void:
	low_boxes.clear()
	low_circles.clear()
	for i in boxes.size():
		var b: Array = boxes[i]
		# un mur de cabine ou un château d'étrave est trop haut ; une caisse (moins de 1,1 m de côté) s'enjambe
		var tall := float(b[2]) - float(b[0]) > 1.1 or float(b[3]) - float(b[1]) > 1.1
		if not cabin.is_empty():
			tall = tall or (float(b[2]) > float(cabin["x0"]) - 0.3 and float(b[0]) < float(cabin["x1"]) + 0.3 \
					and float(b[3]) > float(cabin["y0"]) - 0.3 and float(b[1]) < float(cabin["y1"]) + 0.3)
		if not tall:
			low_boxes.append(i)
	for i in circles.size():
		var c: Array = circles[i]
		var is_mast := false
		for m: Array in masts:
			if absf(float(c[0]) - float(m[0])) < 0.06 and absf(float(c[1])) < 0.06:
				is_mast = true
		if not is_mast:
			low_circles.append(i)


func _index_nodes(node: Node) -> void:
	var s := String(node.name)
	if node is Node3D:
		var n3 := node as Node3D
		if s == "cannon" or s.begins_with("cannon_"):
			cannon_stubs.append(n3)
			n3.visible = false
		if s == "crate":
			# la pile de caisses du pont : c'est elle qui devient la caisse de provisions (voir crate_pos)
			crate_pos = Vector2(n3.position.x - shift, -n3.position.z)
		if s == "int_chest":
			# le coffre de la cabine : le coffre du capitaine, où l'équipage dépose les trésors
			stash_pos = Vector2(n3.position.x - shift, -n3.position.z)
		if s.begins_with("sail_z"):
			var digits := s.substr(6)
			var top := float(digits.to_int()) / 100.0
			_sails.append({"node": n3, "top": top, "base": n3.transform, "alpha": 1.0})
		elif s.begins_with("cut_"):
			var info := {"node": n3, "normal": Vector2.ZERO, "always": true}
			if s.begins_with("cut_wall_") or s.begins_with("cut_win_"):
				var tag := s.substr(9 if s.begins_with("cut_wall_") else 8, 1)
				var normals := {"w": Vector2(-1, 0), "e": Vector2(1, 0), "n": Vector2(0, 1), "s": Vector2(0, -1)}
				if normals.has(tag):
					info["normal"] = normals[tag]
					info["always"] = false
			_cuts.append(info)
	for child in node.get_children():
		_index_nodes(child)


## Position dans le repère local de la scène (mètres de jeu) d'un point du pont.
func to_local3(bp: Vector2, height_offset: float = 0.0) -> Vector3:
	return Vector3((bp.x + shift) * SCALE, deck_height(bp.x) + height_offset, -bp.y * SCALE)


## Demi-largeur de la coque (unités du modèle) à l'abscisse bx.
func half_width(bx: float) -> float:
	var u := (bx + length * 0.5) / length
	if u <= 0.0 or u >= 1.0:
		return 0.0
	return beam * 0.5 * (0.90 + 0.10 * minf(1.0, u * 3.0)) * (1.0 - 0.96 * pow(u, 2.4))


## Hauteur du pont (mètres de jeu) à l'abscisse bx.
func deck_height(bx: float) -> float:
	var u := clampf((bx + length * 0.5) / length, 0.0, 1.0)
	return (0.62 * pow(u, 2.2) + 0.34 * pow(1.0 - u, 2.5)) * (length / 13.0) * SCALE


## Vrai si le point est dans la cabine (porte comprise).
func inside_cabin(bp: Vector2) -> bool:
	if cabin.is_empty():
		return false
	return bp.x > float(cabin["x0"]) and bp.x < float(cabin["door_x"]) \
			and bp.y > float(cabin["y0"]) and bp.y < float(cabin["y1"])


## Vrai si un personnage de rayon WALK_RADIUS peut se tenir en bp. On peut aller jusqu'à la pointe de
## l'étrave : le long du plat-bord la marge est de 0,5, mais jamais moins de MIN_LANE de part et d'autre
## de l'axe, pour que le passage vers l'avant reste ouvert.
func is_walkable(bp: Vector2) -> bool:
	var r := WALK_RADIUS
	var u := (bp.x + length * 0.5) / length
	if u < 0.03 or bp.x > bow_x:
		return false
	if not inside_cabin(bp) and absf(bp.y) > maxf(half_width(bp.x) - RAIL_MARGIN, MIN_LANE):
		return false
	for b: Array in boxes:
		if bp.x > float(b[0]) - r and bp.x < float(b[2]) + r and bp.y > float(b[1]) - r and bp.y < float(b[3]) + r:
			return false
	for c: Array in circles:
		if bp.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + r:
			return false
	return true


## Déplace `from` de `delta` en glissant le long des obstacles. Un pirate déjà coincé dans un obstacle
## (au sortir de la barre, par exemple) peut toujours en sortir.
func move_with_slide(from: Vector2, delta: Vector2) -> Vector2:
	var target := from + delta
	if is_walkable(target):
		return target
	var try_x := Vector2(from.x + delta.x, from.y)
	if is_walkable(try_x):
		return try_x
	var try_y := Vector2(from.x, from.y + delta.y)
	if is_walkable(try_y):
		return try_y
	if not is_walkable(from):
		return target
	return from


## Vrai si un pirate sauté à la hauteur `h` (m au-dessus du pont) peut se trouver en bp : en dessous du plat-bord c'est
## la marche normale ; au-dessus, il passe par-dessus le bastingage (et sort du bateau), enjambe les caisses, le tonneau
## et la roue, mais pas les murs de la cabine ni les mâts.
func is_walkable_air(bp: Vector2, h: float) -> bool:
	if h < RAIL_HEIGHT:
		return is_walkable(bp) or not over_hull(bp)   # en bas : le pont, ou déjà au-dessus de l'eau
	var r := WALK_RADIUS
	for i in boxes.size():
		if h >= LOW_CLEAR and i in low_boxes:
			continue
		var b: Array = boxes[i]
		if bp.x > float(b[0]) - r and bp.x < float(b[2]) + r and bp.y > float(b[1]) - r and bp.y < float(b[3]) + r:
			return false
	for i in circles.size():
		if h >= LOW_CLEAR and i in low_circles:
			continue
		var c: Array = circles[i]
		if bp.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + r:
			return false
	return true


## Comme move_with_slide, mais en l'air (voir is_walkable_air).
func move_air(from: Vector2, delta: Vector2, h: float) -> Vector2:
	var target := from + delta
	if is_walkable_air(target, h):
		return target
	var try_x := Vector2(from.x + delta.x, from.y)
	if is_walkable_air(try_x, h):
		return try_x
	var try_y := Vector2(from.x, from.y + delta.y)
	if is_walkable_air(try_y, h):
		return try_y
	return from


## Vrai si le point est au-dessus de la coque (pont, plat-bord compris) et pas au-dessus de l'eau.
func over_hull(bp: Vector2) -> bool:
	var u := (bp.x + length * 0.5) / length
	return u > 0.0 and u < 1.0 and absf(bp.y) <= half_width(bp.x)


## Où retombe un pirate qui touche le pont en bp : le point lui-même s'il est libre, le point libre voisin s'il
## est sur la coque (une caisse, le plat-bord), Vector2.INF s'il est au-dessus de l'eau.
func landing_spot(bp: Vector2) -> Vector2:
	if is_walkable(bp):
		return bp
	if over_hull(bp):
		var q := nearest_walkable(bp, 1.6)
		if is_walkable(q):
			return q
	return Vector2.INF


## Le point libre le plus proche de bp (recherche en spirale), ou bp si rien à moins de max_dist.
func nearest_walkable(bp: Vector2, max_dist: float = 3.0) -> Vector2:
	if is_walkable(bp):
		return bp
	var d := 0.1
	while d <= max_dist:
		for k in 24:
			var q := bp + Vector2.from_angle(TAU * k / 24.0) * d
			if is_walkable(q):
				return q
		d += 0.1
	return bp


## Les points de la coque (repère monde, x/z) pour tester la rencontre avec la terre : le contour,
## du cul à l'étrave, aux deux bords.
func hull_points_world(sim_pos: Vector2, yaw: float) -> Array:
	var pts: Array = []
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0    # vers bâbord, en x/z
	for i in 9:
		var bx := -length * 0.5 + length * (float(i) / 8.0)
		var hw := half_width(bx) * SCALE
		var center := sim_pos + fwd * ((bx + shift) * SCALE)
		pts.append(center + left * hw)
		pts.append(center - left * hw)
		if i == 8:
			pts.append(center)
	return pts


## Masque les voiles dont le haut dépasse `z` (unités du modèle) : vu d'en haut, elles cachent le pirate
## perché dans le nid de pie. Passer une valeur très grande les remet toutes.
func hide_sails_above(z: float) -> void:
	for entry: Dictionary in _sails:
		(entry["node"] as Node3D).visible = float(entry["top"]) <= z


## Règle l'ouverture visuelle des voiles (0..1) : elles se resserrent vers leur vergue.
func set_sail_open(open: float) -> void:
	_sail_open_v = open
	_apply_sails()


## Oriente les vergues (angle en radian, dans le sens de Vector2.rotated : 0 = perpendiculaires à la coque) : chaque
## voile carrée pivote autour de son mât. Les voiles de pointe (foc, artimon) ne bougent pas.
func set_sail_trim(angle: float) -> void:
	if is_equal_approx(angle, _sail_trim_v):
		return
	_sail_trim_v = angle
	_apply_sails()


func _apply_sails() -> void:
	var s := maxf(0.1, _sail_open_v)
	var m_scale := Basis.from_scale(Vector3(1.0, s, 1.0))
	for k in _sails.size():
		var entry: Dictionary = _sails[k]
		var top: float = entry["top"]
		var m := Transform3D(m_scale, Vector3(0.0, top * (1.0 - s), 0.0))
		var pivot: float = _sail_pivot[k]
		var t := m * (entry["base"] as Transform3D)
		if not is_nan(pivot) and absf(_sail_trim_v) > 0.0001:
			# autour de l'axe vertical du mât (repère du modèle) ; Vector2.rotated(a) = rotation d'axe Y de -a
			var rot := Transform3D(Basis(Vector3.UP, -_sail_trim_v), Vector3.ZERO)
			t = Transform3D(Basis(), Vector3(pivot, 0.0, 0.0)) * rot * Transform3D(Basis(), Vector3(-pivot, 0.0, 0.0)) * t
		(entry["node"] as Node3D).transform = t


## Cherche pour chaque voile le mât qui la porte (le plus proche de son centre) : l'abscisse du pivot, NAN pour les
## voiles qui ne pivotent pas (foc, artimon, ornements loin des mâts).
func _compute_sail_pivots() -> void:
	_sail_pivot.clear()
	for entry: Dictionary in _sails:
		var node := entry["node"] as Node3D
		var pivot := NAN
		var lname := String(node.name)
		if node is MeshInstance3D and not lname.contains("jib") and not lname.contains("spanker"):
			var mi := node as MeshInstance3D
			var center: Vector3 = (entry["base"] as Transform3D) * mi.get_aabb().get_center()
			var best := 1.6
			for m: Array in masts:
				var mx := float(m[0]) + shift
				if absf(mx - center.x) < best:
					best = absf(mx - center.x)
					pivot = mx
		_sail_pivot.append(pivot)


## Les voiles que l'on voit à travers : celles que le rayon du pirate vers la caméra traverse deviennent transparentes
## (même idée que les bâtiments du port), les autres restent pleines. `origin` : la tête du pirate ; `to_cam` : direction
## vers la caméra ; `active` faux : tout redevient plein.
func update_sail_fade(origin: Vector3, to_cam: Vector3, active: bool, delta: float, target_alpha: float = 0.3) -> void:
	for entry: Dictionary in _sails:
		var node := entry["node"] as Node3D
		if not (node is MeshInstance3D):
			continue
		var mi := node as MeshInstance3D
		var want := 1.0
		if active and mi.visible and mi.mesh != null:
			var box := (mi.global_transform * mi.get_aabb()).grow(0.45)
			if box.intersects_ray(origin, to_cam) != null:
				want = target_alpha
		var a: float = entry["alpha"]
		if is_equal_approx(a, want):
			continue
		a = move_toward(a, want, delta * 4.0)
		entry["alpha"] = a
		mi.transparency = 0.0 if a > 0.995 else 1.0 - a


## Masque le toit et les murs tournés vers la caméra quand le joueur est dans la cabine.
## La caméra regarde vers -z : un mur dont la normale (en monde) a une composante +z est de son côté.
func update_cutaway(player_inside: bool) -> void:
	var basis := global_transform.basis
	for entry: Dictionary in _cuts:
		var node: Node3D = entry["node"]
		if not player_inside:
			node.visible = true
			continue
		if entry["always"]:
			node.visible = false
			continue
		var n: Vector2 = entry["normal"]
		var world_normal := basis * Vector3(n.x, 0.0, -n.y)
		node.visible = world_normal.z <= 0.1


## Écoutille du pont (unités du modèle), qui mène à la cale. Le sloop n'en a pas dans son modèle : on en
## pose une à l'exécution (voir sailing_game.gd).
func hatch_pos() -> Vector2:
	return Vector2(1.6 if length > 11.0 else 1.2, 0.0)


## Beaucoup de points de la coque (repère monde, x/z), cinq par station : sert à toucher un récif plus petit
## que l'écart entre deux points du contour.
func hull_points_dense(sim_pos: Vector2, yaw: float) -> Array:
	var pts: Array = []
	var fwd := Vector2(cos(yaw), -sin(yaw))
	var left := Vector2(-fwd.y, fwd.x) * -1.0
	for i in 17:
		var bx := -length * 0.5 + length * (float(i) / 16.0)
		var hw := half_width(bx) * SCALE
		var center := sim_pos + fwd * ((bx + shift) * SCALE)
		for k in [-1.0, -0.5, 0.0, 0.5, 1.0]:
			pts.append(center + left * hw * k)
	return pts


## Où une partie de la coque touche : à partir de la liste de `hull_points_dense` et de l'indice du point
## touché, renvoie {bx, side} (abscisse dans le repère du modèle, +1 bâbord / -1 tribord).
func dense_hit_info(index: int) -> Dictionary:
	var station := floori(index / 5.0)
	var k := index % 5
	var bx := -length * 0.5 + length * (float(station) / 16.0)
	var side := -1 if k < 2 else (1 if k > 2 else 0)
	return {"bx": bx, "side": side}


## Où la coque touche : à partir de l'indice d'un point de `hull_points_world`, renvoie {bx, side}
## (abscisse dans le repère du modèle, +1 bâbord / -1 tribord).
func contour_hit_info(index: int) -> Dictionary:
	var station := mini(floori(index / 2.0), 8)
	return {"bx": -length * 0.5 + length * (float(station) / 8.0), "side": 1 if index % 2 == 0 else -1}
