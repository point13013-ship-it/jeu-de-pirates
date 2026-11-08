class_name WorldLoot
extends RefCounted
## Le butin posé dans le monde : trésors qui flottent après un naufrage, boulets et planches qui tombent d'un tonneau brisé,
## bourses d'or. Un objet est {id, kind, pos, target, ttl, age, node, vel, from, hop}. `kind` :
##   "t:<id>"  un trésor (data/treasures.json),  "ball"  un boulet,  "plank"  une planche,  "g:<n>"  une bourse de n pièces.
## L'hôte (ou le solo) crée, fait dériver et fait expirer ; les clients copient l'état reçu (net_state / apply_net).
## L'affichage tient compte de l'endroit : à flot, l'objet suit la houle ; à terre, il repose sur le sol.

const PICK_RANGE := 1.3        ## m : à cette distance un joueur ramasse l'objet
const HOP_TIME := 0.45         ## s : durée du petit saut d'un objet qui jaillit
const DRIFT_DAMP := 0.7

var items: Array = []
var sea_y := -1.45
var wave: Callable = Callable()          ## (Vector2 monde) -> hauteur de la houle
var over_water: Callable = Callable()    ## (Vector2 monde) -> vrai si c'est la mer
var ground: Callable = Callable()        ## (Vector2 monde) -> hauteur du sol à terre
var _root: Node3D
var _next_id := 1
var _time := 0.0


func setup(parent: Node3D) -> void:
	_root = Node3D.new()
	_root.name = "WorldLoot"
	parent.add_child(_root)


func count() -> int:
	return items.size()


## Crée un objet (hôte ou solo). `from` : d'où il jaillit (un tonneau qui éclate), sinon il apparaît en place.
## Renvoie son identifiant.
func spawn(kind: String, pos: Vector2, ttl: float = 400.0, from: Vector2 = Vector2.INF, vel: Vector2 = Vector2.ZERO) -> int:
	var id := _next_id
	_next_id += 1
	_add(id, kind, pos, ttl, from, vel)
	return id


func _add(id: int, kind: String, pos: Vector2, ttl: float, from: Vector2, vel: Vector2) -> void:
	var it := {"id": id, "kind": kind, "pos": pos if from == Vector2.INF else from, "target": pos, "ttl": ttl, "age": 0.0,
			"vel": vel, "from": from, "hop": 0.0 if from != Vector2.INF else HOP_TIME, "node": null}
	if _root != null:
		it["node"] = _make_node(kind)
		_root.add_child(it["node"])
	items.append(it)


func index_of(id: int) -> int:
	for i in items.size():
		if int((items[i] as Dictionary)["id"]) == id:
			return i
	return -1


## Retire l'objet `id` et renvoie son genre, « » s'il n'existe plus.
func take(id: int) -> String:
	var i := index_of(id)
	if i < 0:
		return ""
	var it: Dictionary = items[i]
	var kind := str(it["kind"])
	_free_item(i)
	return kind


func _free_item(i: int) -> void:
	var it: Dictionary = items[i]
	if it["node"] != null:
		(it["node"] as Node).queue_free()
	items.remove_at(i)


## L'objet le plus proche de `p` à moins de `r` m dont le genre passe `accept` (Callable(kind) -> bool), ou -1.
func nearest(p: Vector2, r: float = PICK_RANGE, accept: Callable = Callable()) -> int:
	var best := -1
	var best_d := r
	for it: Dictionary in items:
		if accept.is_valid() and not bool(accept.call(str(it["kind"]))):
			continue
		var d := (it["pos"] as Vector2).distance_to(p)
		if d < best_d:
			best_d = d
			best = int(it["id"])
	return best


## Déplace l'objet `id` en `p` (halé par un grappin) : il cesse de dériver.
func move_to(id: int, p: Vector2) -> void:
	var i := index_of(id)
	if i < 0:
		return
	var it: Dictionary = items[i]
	it["pos"] = p
	it["target"] = p
	it["vel"] = Vector2.ZERO
	it["from"] = Vector2.INF
	it["hop"] = HOP_TIME
	it["ttl"] = maxf(float(it["ttl"]), 60.0)


func pos_of(id: int) -> Vector2:
	var i := index_of(id)
	return (items[i] as Dictionary)["pos"] as Vector2 if i >= 0 else Vector2.INF


## Chaque image. `authority` : l'hôte fait dériver et expirer les objets ; les autres se rapprochent de la position reçue.
func step(delta: float, authority: bool) -> void:
	_time += delta
	for i in range(items.size() - 1, -1, -1):
		var it: Dictionary = items[i]
		it["age"] = float(it["age"]) + delta
		var pos: Vector2 = it["pos"]
		var water := _is_water(pos)
		if authority:
			it["ttl"] = float(it["ttl"]) - delta
			if float(it["ttl"]) <= 0.0:
				_free_item(i)
				continue
			if water:
				var v: Vector2 = it["vel"]
				pos += v * delta
				it["vel"] = v * exp(-delta * DRIFT_DAMP)
				it["target"] = pos
		else:
			pos = pos.lerp(it["target"], 1.0 - exp(-delta * 8.0))
		var hop := 0.0
		if float(it["hop"]) < HOP_TIME and (it["from"] as Vector2) != Vector2.INF:
			it["hop"] = float(it["hop"]) + delta
			var k := clampf(float(it["hop"]) / HOP_TIME, 0.0, 1.0)
			pos = (it["from"] as Vector2).lerp(it["target"], k)
			hop = sin(PI * k) * 1.1
		it["pos"] = pos
		var node := it["node"] as Node3D
		if node == null:
			continue
		var y := 0.0
		if water:
			y = sea_y + (float(wave.call(pos)) if wave.is_valid() else 0.0) + 0.1 + sin(_time * 2.1 + float(it["id"])) * 0.04
		else:
			y = (float(ground.call(pos)) if ground.is_valid() else 0.0) + 0.16
		node.position = Vector3(pos.x, y + hop, pos.y)
		node.rotation.y += delta * (0.6 if str(it["kind"]).begins_with("t:") else 0.0)
		var glint := node.get_node_or_null("glint") as Node3D
		if glint != null:
			glint.position.y = 0.62 + sin(_time * 3.0 + float(it["id"])) * 0.08
			glint.scale = Vector3.ONE * (0.8 + 0.25 * sin(_time * 5.0 + float(it["id"])))


func _is_water(p: Vector2) -> bool:
	return bool(over_water.call(p)) if over_water.is_valid() else true


# ------------------------------------------------------------------ réseau

## L'état à envoyer aux clients : [[id, kind, x, z], …].
func net_state() -> Array:
	var out: Array = []
	for it: Dictionary in items:
		var p: Vector2 = it["pos"]
		out.append([int(it["id"]), str(it["kind"]), p.x, p.y])
	return out


## Client : copie la liste reçue (ajoute les nouveaux, déplace les autres, retire ceux qui ont disparu).
func apply_net(s: Array) -> void:
	var seen := {}
	for e: Array in s:
		var id := int(e[0])
		seen[id] = true
		var p := Vector2(float(e[2]), float(e[3]))
		var i := index_of(id)
		if i < 0:
			_add(id, str(e[1]), p, 1.0e9, Vector2.INF, Vector2.ZERO)
			var it: Dictionary = items[items.size() - 1]
			it["pos"] = p
			it["hop"] = HOP_TIME
		else:
			(items[i] as Dictionary)["target"] = p
	for i in range(items.size() - 1, -1, -1):
		if not seen.has(int((items[i] as Dictionary)["id"])):
			_free_item(i)


# ------------------------------------------------------------------ apparence

static func _mat(c: Color, unshaded: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.7
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _make_node(kind: String) -> Node3D:
	var root := Node3D.new()
	var body: Node3D
	var glow := false
	if kind.begins_with("t:"):
		body = Treasure.make_icon(kind.substr(2))
		body.scale = Vector3.ONE * 2.3
		glow = true
	elif kind == "ball":
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.18
		sm.height = 0.36
		mi.mesh = sm
		mi.material_override = _mat(Color(0.14, 0.14, 0.18))
		body = mi
	elif kind == "plank":
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.07, 0.18)
		mi.mesh = bm
		mi.material_override = _mat(Color(0.78, 0.58, 0.34))
		body = mi
	else:   # « g:<n> » : une bourse
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.2
		sm.height = 0.36
		mi.mesh = sm
		mi.material_override = _mat(Color(0.88, 0.68, 0.18))
		body = mi
		glow = true
	body.name = "body"
	root.add_child(body)
	if glow:
		var g := MeshInstance3D.new()
		var gm := SphereMesh.new()
		gm.radius = 0.1
		gm.height = 0.2
		gm.radial_segments = 6
		gm.rings = 3
		g.mesh = gm
		g.material_override = _mat(Color(1.0, 0.92, 0.45), true)
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.name = "glint"
		root.add_child(g)
	return root
