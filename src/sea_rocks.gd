class_name SeaRocks
extends RefCounted
## Les récifs : des rochers à fleur d'eau, en dehors du port. Positions dans data/hull.json ([x, z, rayon] en
## coordonnées du monde). Un bateau qui en touche un se coince et se perce (voir HullDamage).

const SEA_Y_OFFSET := 0.12   ## le rocher dépasse un peu au-dessus de la ligne d'eau

var rocks: Array = []        ## [x, z, rayon]


func load_from(cfg: Dictionary) -> void:
	rocks = cfg.get("rocks", [])


## 12/11 (« à peine sorti du port, 8 rochers autour de moi ») : les récifs ne sont plus une haie à la sortie du port, ils
## entourent les îles, à l'écart du port et espacés, et ils varient : gros rocher, aiguille haute, amas de petits rochers,
## banc de sable à fleur d'eau. Tirage fixe (même mer pour tout l'équipage). Chaque récif : [x, z, rayon, sorte].
func generate(islands: Array, port: Vector2) -> void:
	rocks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var kinds := ["rock", "rock", "spire", "cluster", "cluster", "sand"]
	for isl: Dictionary in islands:
		var c: Vector2 = isl["center"]
		var r := float(isl["radius"])
		var n := rng.randi_range(GameConfig.REEF_PER_ISLAND_MIN, GameConfig.REEF_PER_ISLAND_MAX)
		for k in n:
			for attempt in 12:
				var a := rng.randf() * TAU
				var p := c + Vector2.from_angle(a) * (r + rng.randf_range(GameConfig.REEF_FROM_SHORE_MIN, GameConfig.REEF_FROM_SHORE_MAX))
				if p.distance_to(port) < GameConfig.REEF_PORT_CLEAR or not _free(p, islands, GameConfig.REEF_SPACING) \
						or (GameConfig.TOWN_V3 and p.distance_to(GameConfig.OLD_TOWN_CENTER) < GameConfig.REEF_PORT_CLEAR + 60.0):
					continue
				var kind: String = kinds[rng.randi() % kinds.size()]
				match kind:
					"rock":
						rocks.append([p.x, p.y, rng.randf_range(1.8, 3.2), "rock"])
					"spire":
						rocks.append([p.x, p.y, rng.randf_range(1.4, 2.2), "spire"])
					"sand":
						rocks.append([p.x, p.y, rng.randf_range(3.0, 4.6), "sand"])
					"cluster":   # trois à cinq petits rochers serrés
						for m in rng.randi_range(3, 5):
							var q := p + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 3.2)
							rocks.append([q.x, q.y, rng.randf_range(0.7, 1.3), "small"])
				break


## Vrai si `p` est assez loin des récifs déjà posés et hors des îles.
func _free(p: Vector2, islands: Array, spacing: float) -> bool:
	for isl: Dictionary in islands:
		if p.distance_to(isl["center"]) < float(isl["radius"]) + 6.0:
			return false
	for r: Array in rocks:
		if p.distance_to(Vector2(float(r[0]), float(r[1]))) < spacing:
			return false
	return true


## Premier contact entre les points (x, z) et un récif : Vector2i(indice du récif, indice du point), ou (-1, -1).
func hit(points: Array) -> Vector2i:
	for i in rocks.size():
		var r: Array = rocks[i]
		var c := Vector2(float(r[0]), float(r[1]))
		var rad := float(r[2]) * 0.92
		for j in points.size():
			var p: Vector2 = points[j]
			if p.distance_squared_to(c) < rad * rad:
				return Vector2i(i, j)
	return Vector2i(-1, -1)


## Pose les rochers dans `parent` (le monde fixe). `sea_y` : hauteur de l'eau au repos.
func build(parent: Node3D, sea_y: float) -> void:
	var rock_mat := StandardMaterial3D.new()
	rock_mat.vertex_color_use_as_albedo = true
	rock_mat.roughness = 1.0
	var foam_mat := StandardMaterial3D.new()
	foam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	foam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	foam_mat.albedo_color = Color(0.92, 0.97, 1.0, 0.5)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.86, 0.78, 0.58)
	sand_mat.roughness = 1.0
	for i in rocks.size():
		var r: Array = rocks[i]
		var radius := float(r[2])
		var kind := str(r[3]) if r.size() > 3 else "rock"
		var root := Node3D.new()
		root.position = Vector3(float(r[0]), sea_y + SEA_Y_OFFSET, float(r[1]))
		root.rotation.y = float(i) * 1.37
		parent.add_child(root)
		var parts: Array = []
		match kind:
			"spire":   # une aiguille haute et deux éclats
				parts = [[Vector2.ZERO, 1.0, 2.6], [Vector2(0.7, 0.3) * radius, 0.4, 1.0], [Vector2(-0.5, -0.6) * radius, 0.3, 1.0]]
			"small":
				parts = [[Vector2.ZERO, 1.0, 1.0]]
			"sand":    # un banc de sable plat, avec deux galets
				var bank := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = radius
				sm.height = 0.5
				bank.mesh = sm
				bank.scale = Vector3(1.0, 1.0, 0.45)
				bank.position = Vector3(0, -0.12, 0)
				bank.material_override = sand_mat
				root.add_child(bank)
				parts = [[Vector2(0.4, 0.1) * radius, 0.16, 1.0], [Vector2(-0.3, -0.05) * radius, 0.12, 1.0]]
			_:         # un gros rocher et deux petits à son pied
				parts = [[Vector2.ZERO, 1.0, 1.0], [Vector2(0.78, 0.35) * radius, 0.45, 1.0], [Vector2(-0.55, -0.7) * radius, 0.38, 1.0]]
		for k in parts.size():
			var part: Array = parts[k]
			var mi := MeshInstance3D.new()
			mi.mesh = rock_mesh(i * 7 + k, radius * float(part[1]))
			mi.material_override = rock_mat
			var off: Vector2 = part[0]
			mi.position = Vector3(off.x, 0.0, off.y)
			mi.scale = Vector3(1.0, float(part[2]), 1.0)
			root.add_child(mi)
		var foam := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = radius * (1.15 if kind == "sand" else 1.45)
		ring.bottom_radius = ring.top_radius
		ring.height = 0.02
		foam.mesh = ring
		foam.material_override = foam_mat
		foam.position = Vector3(0.0, 0.05, 0.0)
		foam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(foam)


## Rocher à facettes : une sphère basse (7 x 4) dont les sommets sont déplacés, écrasée, à normales plates.
static func rock_mesh(seed_value: int, radius: float) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100 + seed_value
	var segs := 7
	var rings := 4
	var grid: Array = []
	for ring in rings + 1:
		var row: Array = []
		var phi := PI * float(ring) / float(rings)   # 0 = haut
		for s in segs:
			var theta := TAU * float(s) / float(segs)
			var jitter := rng.randf_range(0.82, 1.16)
			var v := Vector3(sin(phi) * cos(theta), cos(phi), sin(phi) * sin(theta)) * radius * jitter
			v.y *= 0.78
			row.append(v)
		grid.append(row)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for ring in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[ring][s]
			var b: Vector3 = grid[ring][s2]
			var c: Vector3 = grid[ring + 1][s2]
			var d: Vector3 = grid[ring + 1][s]
			_tri(st, a, b, c, radius)
			_tri(st, a, c, d, radius)
	st.generate_normals()
	return st.commit()


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, radius: float) -> void:
	for v: Vector3 in [a, c, b]:   # sens des aiguilles d'une montre vu de l'extérieur
		var h := clampf(v.y / (radius * 0.7) * 0.5 + 0.5, 0.0, 1.0)
		st.set_color(Color(0.16, 0.15, 0.18).lerp(Color(0.38, 0.33, 0.29), h))
		st.add_vertex(v)
