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

var _model: Node3D
var _sails: Array = []         ## {node, top, base: Transform3D}
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
	_model = scene.instantiate() as Node3D
	_model.scale = Vector3.ONE * SCALE
	add_child(_model)
	_index_nodes(_model)
	return true


func _index_nodes(node: Node) -> void:
	var s := String(node.name)
	if node is Node3D:
		var n3 := node as Node3D
		if s.begins_with("sail_z"):
			var digits := s.substr(6)
			var top := float(digits.to_int()) / 100.0
			_sails.append({"node": n3, "top": top, "base": n3.transform})
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
	var s := maxf(0.1, open)
	var m_scale := Basis.from_scale(Vector3(1.0, s, 1.0))
	for entry: Dictionary in _sails:
		var top: float = entry["top"]
		var m := Transform3D(m_scale, Vector3(0.0, top * (1.0 - s), 0.0))
		(entry["node"] as Node3D).transform = m * (entry["base"] as Transform3D)


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
