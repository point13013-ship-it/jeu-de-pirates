class_name ShipModel
extends Node3D
## Modèle 3D d'un bateau et ses données de jeu : collisions du pont, cabine, points d'interaction.
## Les calculs de jeu se font dans le repère du modèle (x vers l'étrave, y vers bâbord, en mètres
## avant mise à l'échelle) ; to_local3() convertit vers la scène Godot.

const SCALE := 1.5            ## mètres de jeu par unité du modèle
const WALK_RADIUS := 0.28     ## rayon du personnage, en unités du modèle

var ship_name: String = ""
var meta: Dictionary = {}
var shift: float = 0.0
var length: float = 16.0
var beam: float = 5.6
var boxes: Array = []          ## [x0, y0, x1, y1]
var circles: Array = []        ## [x, y, rayon]
var cabin: Dictionary = {}
var cannons: Array = []        ## [x, y, côté, z]

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


## Vrai si un personnage de rayon WALK_RADIUS peut se tenir en bp.
func is_walkable(bp: Vector2) -> bool:
	var r := WALK_RADIUS
	var u := (bp.x + length * 0.5) / length
	if u < 0.03 or u > 0.96:
		return false
	if not inside_cabin(bp) and absf(bp.y) > half_width(bp.x) - 0.5:
		return false
	for b: Array in boxes:
		if bp.x > float(b[0]) - r and bp.x < float(b[2]) + r and bp.y > float(b[1]) - r and bp.y < float(b[3]) + r:
			return false
	for c: Array in circles:
		if bp.distance_to(Vector2(float(c[0]), float(c[1]))) < float(c[2]) + r:
			return false
	return true


## Déplace `from` de `delta` en glissant le long des obstacles.
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
	return from


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
