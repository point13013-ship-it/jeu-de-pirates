class_name MeshKit
extends RefCounted
## Assemble plusieurs boîtes, boules et cylindres colorés en UN seul maillage (une couleur par sommet). Un palmier ou
## un buisson qui faisait 40 noeuds n'en fait plus qu'un : beaucoup moins d'appels de dessin. Formes à facettes plates.

var _st := SurfaceTool.new()


func _init() -> void:
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)


static func look(dir: Vector3) -> Basis:
	var d := dir.normalized()
	var up := Vector3.UP if absf(d.y) < 0.98 else Vector3.RIGHT
	return Basis.looking_at(d, up)


func _tri(a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	# sens des aiguilles d'une montre vu de l'extérieur
	var n := (b - a).cross(c - a)
	var out := (a + b + c) / 3.0 - center
	if n.dot(out) > 0.0:
		var t := b
		b = c
		c = t
	for v: Vector3 in [a, b, c]:
		_st.set_color(col)
		_st.add_vertex(v)


## Boîte de taille `size`, orientée et placée par `xf`.
func box(xf: Transform3D, size: Vector3, col: Color) -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for sx in [-1.0, 1.0]:
		for sy in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				p.append(xf * Vector3(sx * h.x, sy * h.y, sz * h.z))
	var c := xf.origin
	for q: Array in [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]:
		_tri(p[q[0]], p[q[1]], p[q[2]], col, c)
		_tri(p[q[0]], p[q[2]], p[q[3]], col, c)


## Ellipsoïde bas : `segs` x `rings` facettes, rayon `r`, échelle/orientation par `xf`.
func ball(xf: Transform3D, r: float, col: Color, segs: int = 8, rings: int = 4) -> void:
	var grid: Array = []
	for ring in rings + 1:
		var phi := PI * float(ring) / rings
		var row: Array[Vector3] = []
		for s in segs:
			var th := TAU * float(s) / segs
			row.append(xf * (Vector3(sin(phi) * cos(th), cos(phi), sin(phi) * sin(th)) * r))
		grid.append(row)
	for ring in rings:
		for s in segs:
			var s2 := (s + 1) % segs
			var a: Vector3 = grid[ring][s]
			var b: Vector3 = grid[ring][s2]
			var c: Vector3 = grid[ring + 1][s2]
			var d: Vector3 = grid[ring + 1][s]
			if ring > 0:
				_tri(a, b, c, col, xf.origin)
			if ring < rings - 1:
				_tri(a, c, d, col, xf.origin)


## Cylindre (ou cône tronqué) le long de l'axe Y local, de -h/2 à h/2 ; `r0` en bas, `r1` en haut ; avec bouchons.
func cyl(xf: Transform3D, r0: float, r1: float, h: float, col: Color, segs: int = 8) -> void:
	var bot: Array[Vector3] = []
	var top: Array[Vector3] = []
	for s in segs:
		var th := TAU * float(s) / segs
		bot.append(xf * Vector3(cos(th) * r0, -h * 0.5, sin(th) * r0))
		top.append(xf * Vector3(cos(th) * r1, h * 0.5, sin(th) * r1))
	var cb := xf * Vector3(0, -h * 0.5, 0)
	var ct := xf * Vector3(0, h * 0.5, 0)
	for s in segs:
		var s2 := (s + 1) % segs
		_tri(bot[s], bot[s2], top[s2], col, xf.origin)
		_tri(bot[s], top[s2], top[s], col, xf.origin)
		_tri(ct, top[s], top[s2], col, xf.origin)
		if r0 > 0.0:
			_tri(cb, bot[s2], bot[s], col, xf.origin)


## Cylindre entre deux points (branche, tronc incliné).
func between(a: Vector3, b: Vector3, r0: float, r1: float, col: Color, segs: int = 6) -> void:
	var d := b - a
	var basis := Basis(Quaternion(Vector3.UP, d.normalized()))
	cyl(Transform3D(basis, (a + b) * 0.5), r0, r1, d.length(), col, segs)


func commit() -> ArrayMesh:
	_st.generate_normals()
	return _st.commit()


static var _mat: StandardMaterial3D

## Matière commune : couleur de sommet, mate.
static func material() -> StandardMaterial3D:
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.vertex_color_use_as_albedo = true
		_mat.roughness = 1.0
		_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return _mat


func instance(parent: Node3D, pos: Vector3 = Vector3.ZERO, yaw: float = 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = commit()
	mi.material_override = material()
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi
