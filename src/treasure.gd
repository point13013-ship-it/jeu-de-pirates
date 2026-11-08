class_name Treasure
extends RefCounted
## Les trésors (data/treasures.json) : ce qu'on rapporte au receleur. Un trésor est un identifiant (« calice ») ; ici,
## la valeur, le nom, le tirage au sort pondéré et la petite maquette qu'on porte au-dessus de la tête ou qui flotte.

const PATH := "res://data/treasures.json"

static var _defs: Array = []


static func defs() -> Array:
	if _defs.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		var parsed: Variant = JSON.parse_string(f.get_as_text()) if f != null else null
		if parsed is Dictionary:
			_defs = (parsed as Dictionary).get("treasures", [])
	return _defs


static func by_id(id: String) -> Dictionary:
	for d: Dictionary in defs():
		if str(d["id"]) == id:
			return d
	return {}


static func exists(id: String) -> bool:
	return not by_id(id).is_empty()


static func value_of(id: String) -> int:
	return int(by_id(id).get("value", 0))


static func name_of(id: String) -> String:
	return str(by_id(id).get("name", "trésor"))


## Rang d'un trésor dans le fichier (les échanges réseau envoient ce rang), -1 s'il est inconnu.
static func index_of(id: String) -> int:
	var all := defs()
	for i in all.size():
		if str((all[i] as Dictionary)["id"]) == id:
			return i
	return -1


static func id_at(index: int) -> String:
	var all := defs()
	if index < 0 or index >= all.size():
		return ""
	return str((all[index] as Dictionary)["id"])


## Tire un trésor au hasard selon les poids ; `rarity` > 1 favorise les rares (butin d'un coffre bien gardé).
static func roll(rng: RandomNumberGenerator, rarity: float = 1.0) -> String:
	var all := defs()
	if all.is_empty():
		return ""
	var total := 0.0
	var weights: Array[float] = []
	for d: Dictionary in all:
		var w := float(d["weight"])
		w = pow(w, 1.0 / maxf(rarity, 0.2))   # rarity grand : les poids se rapprochent, donc les rares sortent plus
		weights.append(w)
		total += w
	var pick := rng.randf() * total
	for i in all.size():
		pick -= weights[i]
		if pick <= 0.0:
			return str((all[i] as Dictionary)["id"])
	return str((all[all.size() - 1] as Dictionary)["id"])


## Valeur totale d'une liste d'identifiants.
static func total_value(ids: Array) -> int:
	var sum := 0
	for id in ids:
		sum += value_of(str(id))
	return sum


static func _mi(mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	mi.material_override = m
	mi.position = pos
	return mi


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


static func _cyl(r_top: float, r_bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bottom
	c.height = h
	c.radial_segments = 10
	return c


static func _sph(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 10
	s.rings = 6
	return s


## La maquette d'un trésor, centrée sur son origine, environ 0,4 m de large : un coffret, un calice, un sac, un crâne, une couronne.
static func make_icon(id: String) -> Node3D:
	var d := by_id(id)
	var root := Node3D.new()
	if d.is_empty():
		return root
	var col := Color.html(str(d["color"]))
	var dark := Color(col.r * 0.55, col.g * 0.55, col.b * 0.55)
	match str(d["shape"]):
		"chest":
			root.add_child(_mi(_box(Vector3(0.44, 0.22, 0.28)), Color(0.45, 0.28, 0.14), Vector3(0, 0, 0)))
			root.add_child(_mi(_box(Vector3(0.46, 0.08, 0.3)), col, Vector3(0, 0.15, 0)))
			root.add_child(_mi(_box(Vector3(0.06, 0.28, 0.3)), col, Vector3(0, 0.02, 0)))
		"cup":
			root.add_child(_mi(_cyl(0.14, 0.05, 0.2), col, Vector3(0, 0.1, 0)))
			root.add_child(_mi(_cyl(0.03, 0.03, 0.14), dark, Vector3(0, -0.05, 0)))
			root.add_child(_mi(_cyl(0.12, 0.12, 0.04), col, Vector3(0, -0.14, 0)))
		"sack":
			var sack := _mi(_sph(0.2), Color(0.55, 0.42, 0.28), Vector3(0, 0, 0))
			sack.scale = Vector3(1.0, 1.1, 1.0)
			root.add_child(sack)
			for k in 3:
				root.add_child(_mi(_sph(0.06), col, Vector3(-0.1 + 0.1 * k, 0.2, 0.06 * (k % 2))))
		"skull":
			root.add_child(_mi(_sph(0.17), col, Vector3(0, 0.04, 0)))
			root.add_child(_mi(_box(Vector3(0.18, 0.1, 0.14)), col, Vector3(0, -0.12, 0.02)))
			root.add_child(_mi(_sph(0.04), Color(0.06, 0.05, 0.05), Vector3(-0.06, 0.06, 0.14)))
			root.add_child(_mi(_sph(0.04), Color(0.06, 0.05, 0.05), Vector3(0.06, 0.06, 0.14)))
		"crown":
			root.add_child(_mi(_cyl(0.17, 0.15, 0.12), col, Vector3(0, 0, 0)))
			for k in 5:
				var a := TAU * float(k) / 5.0
				root.add_child(_mi(_cyl(0.0, 0.04, 0.12), Color(1.0, 0.92, 0.4), Vector3(cos(a) * 0.15, 0.12, sin(a) * 0.15)))
			root.add_child(_mi(_sph(0.045), Color(0.3, 0.8, 1.0), Vector3(0, 0.02, 0.17)))
	return root
