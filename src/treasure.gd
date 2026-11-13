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


## La maquette d'un trésor, centrée sur son origine, environ 0,4 m de large.
## 13/11 (retours de la session à 3, piste choisie par Jimmy : « une forme par valeur ») : la valeur se lit à la silhouette,
## même de loin. Bourse de cuir, coffret cerclé de fer, coffre bombé cerclé de laiton, coffre d'amiral cerclé d'or (il
## scintille), coffre noir aux chaînes avec une serrure en crâne et une lueur rose (il scintille aussi).
static func make_icon(id: String) -> Node3D:
	var d := by_id(id)
	var root := Node3D.new()
	if d.is_empty():
		return root
	match str(d["shape"]):
		"purse":
			var bag := _mi(_sph(0.17), Color("6a4532"), Vector3(0, -0.03, 0))
			bag.scale = Vector3(1.0, 0.85, 0.92)
			root.add_child(bag)
			root.add_child(_mi(_cyl(0.05, 0.08, 0.08), Color("6a4532"), Vector3(0, 0.12, 0)))
			root.add_child(_mi(_cyl(0.062, 0.062, 0.025), Color("cf9c62"), Vector3(0, 0.125, 0)))   # le lacet
			root.add_child(_mi(_cyl(0.10, 0.05, 0.06), Color("9c6a43"), Vector3(0, 0.185, 0)))      # le col qui s'évase
			root.add_child(_mi(_cyl(0.045, 0.045, 0.014), Color("ffd23f"), Vector3(0.03, 0.215, 0.02)))   # une pièce dépasse
		"casket":
			_chest(root, Vector3(0.36, 0.17, 0.24), Color("9c6a43"), Color("6a4532"), Color("7d7488"), [-0.11, 0.11], false)
		"chest":
			_chest(root, Vector3(0.44, 0.21, 0.28), Color("9c6a43"), Color("6a4532"), Color("dcae5c"), [-0.14, 0.14], true)
		"gold_chest":
			_chest(root, Vector3(0.50, 0.23, 0.31), Color("6a4532"), Color("3a2630"), Color("ffd23f"), [-0.19, 0.0, 0.19], true)
			for sx: float in [-1.0, 1.0]:   # coins d'or
				for sz: float in [-1.0, 1.0]:
					root.add_child(_mi(_box(Vector3(0.05, 0.25, 0.05)), Color("ffd23f"), Vector3(sx * 0.235, -0.10, sz * 0.14)))
			root.add_child(_sparkles(Color("ffe2a0"), 5))
		"cursed":
			_chest(root, Vector3(0.50, 0.23, 0.31), Color("2e2a44"), Color("1c1726"), Color("4a4258"), [-0.17, 0.17], true)
			# les chaînes : une ceinture à mi-hauteur et un tour par-dessus le couvercle
			root.add_child(_mi(_box(Vector3(0.53, 0.035, 0.34)), Color("7d7488"), Vector3(0, -0.08, 0)))
			var over := _mi(_cyl(0.168, 0.168, 0.04), Color("7d7488"), Vector3(0, 0.035, 0))
			over.rotation.z = PI * 0.5
			root.add_child(over)
			# la lueur sous le couvercle
			root.add_child(_glow(_box(Vector3(0.515, 0.02, 0.325)), Color("e46be0"), Vector3(0, 0.035, 0)))
			# la serrure en crâne
			root.add_child(_mi(_sph(0.062), Color("efe4cc"), Vector3(0, 0.0, 0.165)))
			root.add_child(_mi(_box(Vector3(0.066, 0.045, 0.04)), Color("efe4cc"), Vector3(0, -0.06, 0.17)))
			for sx2: float in [-1.0, 1.0]:
				root.add_child(_glow(_sph(0.017), Color("e46be0"), Vector3(sx2 * 0.026, 0.008, 0.218)))
			root.add_child(_sparkles(Color("e46be0"), 7))
	return root


## Un coffre : caisse de bois, couvercle plat ou bombé, cerclages de métal (positions en x), serrure.
static func _chest(root: Node3D, size: Vector3, wood: Color, lid_wood: Color, metal: Color, straps: Array, domed: bool) -> void:
	var top := 0.035                       # hauteur du plan de joint : la caisse est dessous, le couvercle dessus
	var base_y := top - size.y * 0.5
	root.add_child(_mi(_box(size), wood, Vector3(0, base_y, 0)))
	root.add_child(_mi(_box(Vector3(size.x + 0.012, 0.03, size.z + 0.012)), lid_wood, Vector3(0, base_y - size.y * 0.5 + 0.015, 0)))   # la plinthe
	if domed:
		var lid := _mi(_cyl(size.z * 0.5, size.z * 0.5, size.x), lid_wood, Vector3(0, top, 0))
		lid.rotation.z = PI * 0.5
		root.add_child(lid)
	else:
		root.add_child(_mi(_box(Vector3(size.x + 0.02, 0.055, size.z + 0.02)), lid_wood, Vector3(0, top + 0.0275, 0)))
	for x: float in straps:
		root.add_child(_mi(_box(Vector3(0.045, size.y + 0.004, size.z + 0.014)), metal, Vector3(x, base_y, 0)))
		if domed:
			var hoop := _mi(_cyl(size.z * 0.5 + 0.008, size.z * 0.5 + 0.008, 0.045), metal, Vector3(x, top, 0))
			hoop.rotation.z = PI * 0.5
			root.add_child(hoop)
		else:
			root.add_child(_mi(_box(Vector3(0.045, 0.06, size.z + 0.03)), metal, Vector3(x, top + 0.0275, 0)))
	root.add_child(_mi(_box(Vector3(0.07, 0.085, 0.03)), metal, Vector3(0, top - 0.02, size.z * 0.5 + 0.012)))   # la serrure


## Une pièce qui brille toute seule (lueur du coffre maudit).
static func _glow(mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := _mi(mesh, c, pos)
	var m := mi.material_override as StandardMaterial3D
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.6
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Le scintillement des deux trésors les plus chers : quelques éclats qui montent et s'éteignent autour du coffre.
static func _sparkles(c: Color, amount: int) -> CPUParticles3D:
	var ps := CPUParticles3D.new()
	ps.amount = amount
	ps.lifetime = 1.1
	ps.randomness = 0.6
	ps.local_coords = true
	ps.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	ps.emission_sphere_radius = 0.3
	ps.direction = Vector3.UP
	ps.spread = 20.0
	ps.gravity = Vector3.ZERO
	ps.initial_velocity_min = 0.08
	ps.initial_velocity_max = 0.2
	ps.scale_amount_min = 0.6
	ps.scale_amount_max = 1.2
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.0))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1.0, 0.0))
	ps.scale_amount_curve = curve
	var quad := BoxMesh.new()
	quad.size = Vector3(0.035, 0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	quad.material = m
	ps.mesh = quad
	ps.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ps.position = Vector3(0, 0.05, 0)
	return ps
