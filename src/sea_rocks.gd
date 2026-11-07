class_name SeaRocks
extends RefCounted
## Les récifs : des rochers à fleur d'eau, en dehors du port. Positions dans data/hull.json ([x, z, rayon] en
## coordonnées du monde). Un bateau qui en touche un se coince et se perce (voir HullDamage).

const SEA_Y_OFFSET := 0.12   ## le rocher dépasse un peu au-dessus de la ligne d'eau

var rocks: Array = []        ## [x, z, rayon]


func load_from(cfg: Dictionary) -> void:
	rocks = cfg.get("rocks", [])


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
	for i in rocks.size():
		var r: Array = rocks[i]
		var radius := float(r[2])
		var root := Node3D.new()
		root.position = Vector3(float(r[0]), sea_y + SEA_Y_OFFSET, float(r[1]))
		parent.add_child(root)
		# un gros rocher et deux petits à son pied
		var parts: Array = [[Vector2.ZERO, 1.0], [Vector2(0.78, 0.35) * radius, 0.45], [Vector2(-0.55, -0.7) * radius, 0.38]]
		for k in parts.size():
			var part: Array = parts[k]
			var mi := MeshInstance3D.new()
			mi.mesh = rock_mesh(i * 7 + k, radius * float(part[1]))
			mi.material_override = rock_mat
			var off: Vector2 = part[0]
			mi.position = Vector3(off.x, 0.0, off.y)
			root.add_child(mi)
		var foam := MeshInstance3D.new()
		var ring := CylinderMesh.new()
		ring.top_radius = radius * 1.45
		ring.bottom_radius = radius * 1.45
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
