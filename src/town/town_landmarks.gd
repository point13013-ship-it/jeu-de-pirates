class_name TownLandmarks
extends RefCounted
## Les repères et les lieux ouverts de la ville v3 (13/11/2026) : ce qui n'est pas une maison ordinaire. Église et clocher,
## maison du gouverneur, moulin (ses ailes tournent), phare, batterie du fort, cabanes de pêcheurs ; halles du marché et du
## chantier naval ; grandes tentes ouvertes sur la rue (on voit dedans sans entrer) ; tableau des quêtes et forge en plein air.
## Même format que TownHouse : un MeshInstance3D à six surfaces (enduit, toit, bois, pierre, clair, vitres) avec les métas
## « colors », « kinds », « glass », « lit », que le jeu habille et rend transparent quand il cache le pirate.

const P := TownHouse.S_PLASTER
const R := TownHouse.S_ROOF
const W := TownHouse.S_WOOD
const S := TownHouse.S_STONE
const T := TownHouse.S_TRIM
const G := TownHouse.S_GLASS
const STONE := Color("7d7488")
const STONE_LIGHT := Color("b9ad9c")
const CREAM := Color("efe4cc")
const WOOD := Color("6a4532")
const WOOD_DARK := Color("3a2630")
const TILE := Color("b25a3e")
const GLASS := Color("ffe2a0")


## Ce qui tourne tout seul (ailes du moulin, faisceau du phare).
class Spinner extends Node3D:
	var axis := Vector3.UP
	var speed := 0.5
	func _process(delta: float) -> void:
		rotate(axis, speed * delta)


static func _surfaces() -> Array[SurfaceTool]:
	var st: Array[SurfaceTool] = []
	for k in 6:
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append(s)
	return st


static func _finish(root: Node3D, st: Array[SurfaceTool], id: String, colors: Array, kinds: Array, lit: bool) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	var keep: Array = []
	for k in st.size():
		var before := mesh.get_surface_count()
		st[k].commit(mesh)
		if mesh.get_surface_count() > before:
			keep.append(k)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "bldg_%s" % id
	var cols: Array = []
	var kds: Array = []
	var glass := -1
	for i in keep.size():
		cols.append(colors[keep[i]])
		kds.append(kinds[keep[i]])
		if keep[i] == G:
			glass = i
	mi.set_meta("colors", cols)
	mi.set_meta("kinds", kds)
	mi.set_meta("glass", glass)
	mi.set_meta("lit", lit)
	root.add_child(mi)
	return mi


static func _frame(b: Dictionary, base: float) -> Dictionary:
	return {"c": Vector2(float(b["x"]), float(b["y"])), "ang": float(b["ang"]), "base": base}


## Un toit en pointe (quatre pans) centré en (u, v), de demi-côtés hu et hv, posé à la hauteur y.
static func _pyramid(st: SurfaceTool, f: Dictionary, u: float, v: float, hu: float, hv: float, y: float, rise: float) -> void:
	var top := TownHouse._p(f, Vector3(u, v, y + rise))
	var c: Array[Vector3] = [TownHouse._p(f, Vector3(u - hu, v - hv, y)), TownHouse._p(f, Vector3(u + hu, v - hv, y)),
			TownHouse._p(f, Vector3(u + hu, v + hv, y)), TownHouse._p(f, Vector3(u - hu, v + hv, y))]
	for i in 4:
		TownGreybox._raw_quad(st, c[i], c[(i + 1) % 4], top, top, Vector3.ZERO)


## Une tour dont les murs se resserrent vers le haut (moulin, phare) : demi-côté r0 en bas, r1 en haut.
static func _tapered(st: SurfaceTool, f: Dictionary, r0: float, r1: float, z0: float, z1: float, sides: int = 8) -> void:
	for k in sides:
		var a0 := TAU * k / sides + PI / sides
		var a1 := TAU * (k + 1) / sides + PI / sides
		var out := TownHouse._dir(f, Vector3(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5), 0.15))
		TownGreybox._raw_quad(st, TownHouse._p(f, Vector3(cos(a0) * r0, sin(a0) * r0, z0)), TownHouse._p(f, Vector3(cos(a1) * r0, sin(a1) * r0, z0)),
				TownHouse._p(f, Vector3(cos(a1) * r1, sin(a1) * r1, z1)), TownHouse._p(f, Vector3(cos(a0) * r1, sin(a0) * r1, z1)), out)


static func _cone(st: SurfaceTool, f: Dictionary, r: float, z: float, rise: float, sides: int = 8) -> void:
	var top := TownHouse._p(f, Vector3(0, 0, z + rise))
	for k in sides:
		var a0 := TAU * k / sides + PI / sides
		var a1 := TAU * (k + 1) / sides + PI / sides
		TownGreybox._raw_quad(st, TownHouse._p(f, Vector3(cos(a0) * r, sin(a0) * r, z)), TownHouse._p(f, Vector3(cos(a1) * r, sin(a1) * r, z)), top, top, Vector3.ZERO)


# ------------------------------------------------------------------ repères

## Renvoie le bâtiment du repère `b`, ou null si ce numéro n'a pas de modèle (la maquette grise le dessine alors).
static func build(root: Node3D, b: Dictionary, base: float, circles: Array, extras: Dictionary) -> MeshInstance3D:
	match int(b.get("num", 0)):
		11:
			return _church(root, b, base)
		12:
			return _governor(root, b, base)
		13:
			return _mill(root, b, base)
		14:
			return _lighthouse(root, b, base, extras)
		15:
			return _battery(root, b, base)
		19:
			return _baths(root, b, base)
	return null


static func _church(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	var h := 6.6
	TownHouse._box(st[S], f, Vector3(0, 0, 0.3), Vector3(w + 0.3, d + 0.3, 0.6))
	TownHouse._box(st[P], f, Vector3(0, 0, 0.6 + (h - 0.6) * 0.5), Vector3(w, d, h - 0.6))
	TownHouse._box(st[T], f, Vector3(0, 0, h - 0.1), Vector3(w + 0.2, d + 0.2, 0.2))
	# contreforts et hautes fenêtres sur les côtés
	for su: float in [-1.0, 1.0]:
		for k in 4:
			var v := -d * 0.5 + d * (float(k) + 0.5) / 4.0
			TownHouse._box(st[S], f, Vector3(su * (w * 0.5 + 0.25), v - d / 8.0, 2.2), Vector3(0.5, 0.7, 4.4))
			TownHouse._obox(st[T], f, Vector2(su * (w * 0.5 + 0.02), v), Vector2(0, 1), Vector2(su, 0), 3.4, Vector3(1.0, 0.06, 3.0))
			TownHouse._obox(st[G], f, Vector2(su * (w * 0.5 + 0.05), v), Vector2(0, 1), Vector2(su, 0), 3.4, Vector3(0.7, 0.06, 2.7))
	# façade sud : grande porte, marches, rosace
	TownHouse._box(st[T], f, Vector3(0, -d * 0.5 - 0.03, 2.1), Vector3(2.6, 0.08, 3.8))
	TownHouse._box(st[W], f, Vector3(0, -d * 0.5 - 0.07, 1.95), Vector3(2.1, 0.1, 3.3))
	for k in 3:
		TownHouse._box(st[S], f, Vector3(0, -d * 0.5 - 0.5 - 0.45 * k, 0.3 - 0.1 * k), Vector3(4.4 - 0.5 * k, 0.5, 0.6 - 0.2 * k))
	TownHouse._box(st[T], f, Vector3(0, -d * 0.5 - 0.03, 5.2), Vector3(1.9, 0.08, 1.9))
	TownHouse._box(st[G], f, Vector3(0, -d * 0.5 - 0.07, 5.2), Vector3(1.4, 0.08, 1.4))
	TownHouse._roof(st, f, w, d, h, 3.4)
	# clocher, au fond à gauche : il dépasse de tout le quartier (repère de la ville)
	var tu := -w * 0.5 + 2.4
	var tv := d * 0.5 - 2.4
	TownHouse._box(st[P], f, Vector3(tu, tv, 7.5), Vector3(4.4, 4.4, 15.0))
	TownHouse._box(st[T], f, Vector3(tu, tv, 11.0), Vector3(4.6, 4.6, 0.25))
	TownHouse._box(st[T], f, Vector3(tu, tv, 15.0), Vector3(4.8, 4.8, 0.3))
	for n: Vector2 in [Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1)]:   # les ouvertures de la cloche
		TownHouse._obox(st[W], f, Vector2(tu, tv) + n * 2.22, Vector2(-n.y, n.x), n, 13.0, Vector3(1.5, 0.08, 2.4))
	_pyramid(st[R], f, tu, tv, 2.6, 2.6, 15.15, 4.2)
	TownHouse._box(st[T], f, Vector3(tu, tv, 20.2), Vector3(0.14, 0.14, 1.8))
	TownHouse._box(st[T], f, Vector3(tu, tv, 20.5), Vector3(0.9, 0.14, 0.14))
	return _finish(root, st, str(b["id"]), [CREAM, Color("7a3530"), WOOD_DARK, STONE, Color("d8cbb0"), GLASS], [0, 1, 2, 3, 4, 4], true)


static func _governor(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	var storey := 3.2
	var top := 0.6 + storey * 2.0
	TownHouse._box(st[S], f, Vector3(0, 0, 0.3), Vector3(w + 0.3, d + 0.3, 0.6))
	TownHouse._box(st[P], f, Vector3(0, 0, (0.6 + top) * 0.5), Vector3(w, d, top - 0.6))
	TownHouse._box(st[T], f, Vector3(0, 0, 0.6 + storey), Vector3(w + 0.14, d + 0.14, 0.18))
	TownHouse._box(st[T], f, Vector3(0, 0, top - 0.12), Vector3(w + 0.24, d + 0.24, 0.26))
	# galerie à colonnes sur toute la façade, balcon au-dessus
	var cols := 7
	for k in cols:
		var u := -w * 0.5 + 0.5 + (w - 1.0) * float(k) / (cols - 1)
		TownHouse._box(st[T], f, Vector3(u, -d * 0.5 - 1.7, 0.6 + storey * 0.5), Vector3(0.36, 0.36, storey))
		TownHouse._box(st[T], f, Vector3(u, -d * 0.5 - 1.75, 0.6 + storey + 0.55), Vector3(0.1, 0.1, 0.9))
	TownHouse._box(st[S], f, Vector3(0, -d * 0.5 - 1.0, 0.3), Vector3(w + 0.3, 2.2, 0.6))
	TownHouse._box(st[W], f, Vector3(0, -d * 0.5 - 0.95, 0.6 + storey + 0.06), Vector3(w + 0.2, 2.0, 0.14))
	TownHouse._box(st[T], f, Vector3(0, -d * 0.5 - 1.75, 0.6 + storey + 1.0), Vector3(w + 0.2, 0.1, 0.1))
	for k in 3:
		TownHouse._box(st[S], f, Vector3(0, -d * 0.5 - 2.3 - 0.4 * k, 0.25 - 0.1 * k), Vector3(4.0, 0.4, 0.5 - 0.2 * k))
	# portes et fenêtres : sept travées, la porte au milieu
	for k in 7:
		var u2 := -w * 0.5 + w * (float(k) + 0.5) / 7.0
		if k == 3:
			TownHouse._door(st, f, u2, -d * 0.5, true)
		else:
			TownHouse._window(st, f, Vector2(u2, -d * 0.5), Vector2(0, -1), 0.6 + 1.1, true)
		TownHouse._window(st, f, Vector2(u2, -d * 0.5), Vector2(0, -1), 0.6 + storey + 1.1, true)
	for su: float in [-1.0, 1.0]:
		for k in 3:
			var v := -d * 0.5 + d * (float(k) + 0.5) / 3.0
			for s2 in 2:
				TownHouse._window(st, f, Vector2(su * w * 0.5, v), Vector2(su, 0), 0.6 + storey * s2 + 1.1, true)
	TownHouse._roof(st, f, w, d, top, 2.6)
	for su2: float in [-1.0, 1.0]:
		TownHouse._box(st[S], f, Vector3(su2 * w * 0.3, 0, top + 2.2), Vector3(0.8, 0.8, 3.0))
	# le mât et son pavillon, sur le faîte
	TownHouse._box(st[W], f, Vector3(0, 0, top + 4.6), Vector3(0.12, 0.12, 4.4))
	TownHouse._box(st[T], f, Vector3(0.9, 0, top + 6.2), Vector3(1.7, 0.05, 1.0))
	return _finish(root, st, str(b["id"]), [Color("e8c9a0"), TILE, Color("3a5f7a"), STONE, CREAM, GLASS], [0, 1, 2, 3, 4, 4], true)


static func _mill(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var r := float(b["w"]) * 0.5
	_tapered(st[S], f, r + 0.15, r + 0.1, 0.0, 0.7)
	_tapered(st[P], f, r, r * 0.72, 0.7, 9.0)
	_cone(st[R], f, r * 0.72 + 0.4, 9.0, 3.0)
	TownHouse._box(st[W], f, Vector3(0, -r - 0.04, 1.75), Vector3(1.1, 0.1, 2.1))
	TownHouse._box(st[T], f, Vector3(0, -r * 0.86 - 0.05, 5.4), Vector3(0.9, 0.08, 1.1))
	TownHouse._box(st[G], f, Vector3(0, -r * 0.86 - 0.09, 5.4), Vector3(0.66, 0.08, 0.86))
	var mi := _finish(root, st, str(b["id"]), [CREAM, Color("6a4532"), WOOD_DARK, STONE, CREAM, GLASS], [0, 2, 2, 3, 4, 4], true)
	# les ailes : quatre bras de bois et leur toile, qui tournent face au sud (vers la caméra)
	var hub := Spinner.new()
	var out := TownHouse._dir(f, Vector3(0, -1, 0))
	hub.axis = out
	hub.speed = 0.55
	hub.position = TownHouse._p(f, Vector3(0, -r * 0.8 - 0.7, 9.6))
	var arms := SurfaceTool.new()
	arms.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sails := SurfaceTool.new()
	sails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var right := TownHouse._dir(f, Vector3(1, 0, 0))
	for k in 4:
		var dir := right.rotated(out, PI * 0.5 * k)
		var side := dir.rotated(out, PI * 0.5)
		for seg: Array in [[arms, 0.0, 6.4, 0.09, 0.0], [sails, 1.3, 6.2, 0.75, 0.8]]:
			var a := dir * float(seg[1]) + side * float(seg[4])
			var e := dir * float(seg[2]) + side * float(seg[4])
			var hw := side * float(seg[3])
			for o: float in [0.0, 0.03]:   # deux faces : on voit l'aile des deux côtés
				TownGreybox._raw_quad(seg[0], a - hw + out * o, a + hw + out * o, e + hw + out * o, e - hw + out * o, -out if o == 0.0 else out)
	var am := MeshInstance3D.new()
	var mesh := ArrayMesh.new()
	arms.commit(mesh)
	sails.commit(mesh)
	am.mesh = mesh
	am.set_surface_override_material(0, TownGreybox._mat(WOOD_DARK))
	am.set_surface_override_material(1, TownGreybox._mat(CREAM))
	hub.add_child(am)
	root.add_child(hub)
	return mi


static func _lighthouse(root: Node3D, b: Dictionary, base: float, extras: Dictionary) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var r := float(b["w"]) * 0.5
	_tapered(st[S], f, r + 0.5, r + 0.3, 0.0, 1.2)
	_tapered(st[P], f, r, r * 0.8, 1.2, 6.0)
	_tapered(st[R], f, r * 0.8, r * 0.7, 6.0, 9.0)        # la bande rouge
	_tapered(st[P], f, r * 0.7, r * 0.58, 9.0, 13.0)
	TownHouse._box(st[S], f, Vector3(0, 0, 13.1), Vector3(r * 1.9, r * 1.9, 0.25))   # la galerie
	_tapered(st[G], f, r * 0.5, r * 0.5, 13.2, 15.0)      # la lanterne
	_cone(st[R], f, r * 0.62, 15.0, 1.6)
	TownHouse._box(st[W], f, Vector3(0, -r - 0.02, 2.3), Vector3(1.0, 0.1, 2.0))
	var mi := _finish(root, st, str(b["id"]), [CREAM, Color("b23a30"), WOOD_DARK, STONE, CREAM, GLASS], [4, 4, 2, 3, 4, 4], true)
	extras["beacon"] = TownHouse._p(f, Vector3(0, 0, 14.1))
	return mi


static func _battery(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	TownHouse._box(st[S], f, Vector3(0, 0, 0.5), Vector3(w, d, 1.0))            # la plate-forme
	for su: float in [-1.0, 1.0]:                                             # parapets à créneaux
		TownHouse._box(st[S], f, Vector3(su * (w * 0.5 - 0.3), 0, 1.5), Vector3(0.6, d, 1.0))
	TownHouse._box(st[S], f, Vector3(0, d * 0.5 - 0.3, 1.5), Vector3(w, 0.6, 1.0))
	var merlons := int(w / 1.6)
	for k in merlons:
		if k % 2 == 0:
			TownHouse._box(st[S], f, Vector3(-w * 0.5 + w * (float(k) + 0.5) / merlons, -d * 0.5 + 0.3, 1.55), Vector3(w / merlons, 0.6, 1.1))
	for k in 4:   # quatre canons vers le large
		var u := -w * 0.5 + w * (float(k) + 0.5) / 4.0
		TownHouse._box(st[W], f, Vector3(u, -d * 0.5 + 1.6, 1.25), Vector3(0.8, 1.2, 0.5))
		TownHouse._box(st[R], f, Vector3(u, -d * 0.5 + 1.0, 1.65), Vector3(0.34, 2.2, 0.34))
	TownHouse._box(st[W], f, Vector3(w * 0.3, d * 0.2, 4.5), Vector3(0.14, 0.14, 7.0))
	TownHouse._box(st[T], f, Vector3(w * 0.3 + 1.0, d * 0.2, 7.3), Vector3(1.9, 0.05, 1.2))
	return _finish(root, st, str(b["id"]), [STONE, Color("2e2a44"), WOOD, STONE, Color("1c1726"), GLASS], [3, 4, 2, 3, 4, 4], false)


static func _baths(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	TownHouse._box(st[S], f, Vector3(0, 0, 0.35), Vector3(w, d, 0.7))
	TownHouse._box(st[T], f, Vector3(0, 0, 0.72), Vector3(w - 0.8, d - 0.8, 0.06))   # l'eau du lavoir
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			TownHouse._box(st[W], f, Vector3(su * (w * 0.5 - 0.25), sv * (d * 0.5 - 0.25), 1.9), Vector3(0.24, 0.24, 2.4))
	TownHouse._roof(st, f, w, d, 3.1, 1.3)
	return _finish(root, st, str(b["id"]), [CREAM, TILE, WOOD, STONE_LIGHT, Color("5f8fb0"), GLASS], [0, 1, 2, 3, 4, 4], false)


# ------------------------------------------------------------------ lieux ouverts

## Une halle : poteaux et charpente de bois, toit de tuiles. `kind` : « marche » (étals) ou « chantier » (une coque sur cale).
static func hall(root: Node3D, b: Dictionary, base: float, circles: Array) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	var c := Vector2(float(b["x"]), float(b["y"]))
	var ang := float(b["ang"])
	var h := 4.2
	var bays := maxi(int(w / 4.0), 2)
	for k in bays + 1:
		for sv: float in [-1.0, 1.0]:
			var l := Vector2(-w * 0.5 + 0.3 + (w - 0.6) * float(k) / bays, sv * (d * 0.5 - 0.3))
			TownHouse._box(st[W], f, Vector3(l.x, l.y, h * 0.5), Vector3(0.34, 0.34, h))
			TownHouse._box(st[S], f, Vector3(l.x, l.y, 0.2), Vector3(0.6, 0.6, 0.4))
			var p := c + l.rotated(ang)
			circles.append([p.x, p.y, 0.32])
		TownHouse._box(st[W], f, Vector3(-w * 0.5 + 0.3 + (w - 0.6) * float(k) / bays, 0, h - 0.15), Vector3(0.26, d - 0.4, 0.26))
	for sv2: float in [-1.0, 1.0]:
		TownHouse._box(st[W], f, Vector3(0, sv2 * (d * 0.5 - 0.3), h - 0.15), Vector3(w - 0.4, 0.26, 0.26))
	TownHouse._roof(st, f, w + 0.6, d + 0.6, h, 2.0)
	if int(b.get("num", 0)) == 5:
		# chantier naval : une coque en construction sur sa cale (quille, couples, bordé commencé)
		TownHouse._box(st[W], f, Vector3(0, 0, 0.45), Vector3(w * 0.74, 0.3, 0.3))
		for k in 9:
			var u := -w * 0.34 + w * 0.68 * float(k) / 8.0
			var half := 1.5 * sin(PI * (0.12 + 0.76 * float(k) / 8.0))
			TownHouse._box(st[T], f, Vector3(u, 0, 0.75), Vector3(0.14, half * 2.0, 0.14))
			for sv3: float in [-1.0, 1.0]:
				TownHouse._box(st[T], f, Vector3(u, sv3 * half, 1.35), Vector3(0.14, 0.14, 1.3))
		for sv4: float in [-1.0, 1.0]:
			TownHouse._box(st[W], f, Vector3(0, sv4 * 2.2, 0.25), Vector3(w * 0.5, 0.3, 0.5))   # les tins de la cale
		var hp := c
		circles.append([hp.x, hp.y, 1.4])
		for su: float in [-1.0, 1.0]:
			var q := c + Vector2(su * w * 0.2, 0).rotated(ang)
			circles.append([q.x, q.y, 1.3])
	else:
		# marché : trois étals à auvent, leurs cageots
		for k in 3:
			var u2 := -w * 0.3 + w * 0.3 * k
			TownHouse._box(st[W], f, Vector3(u2, 0.4, 0.5), Vector3(1.8, 0.8, 1.0))
			TownHouse._box(st[P] if k % 2 == 0 else st[T], f, Vector3(u2, 0.4, 1.12), Vector3(1.5, 0.6, 0.24))
			var sp := c + Vector2(u2, 0.4).rotated(ang)
			circles.append([sp.x, sp.y, 0.75])
	return _finish(root, st, str(b["id"]), [Color("d68a6e"), TILE, WOOD, STONE, CREAM, GLASS], [4, 1, 2, 3, 4, 4], false)


## Une grande tente ouverte sur la rue : toile rayée, fond et côtés de toile, comptoir, caisses, lanterne.
static func tent(root: Node3D, b: Dictionary, base: float, circles: Array, extras: Dictionary) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	var c := Vector2(float(b["x"]), float(b["y"]))
	var ang := float(b["ang"])
	var front := 3.7
	var back := 2.1
	var hu := w * 0.5
	var hv := d * 0.5
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			TownHouse._box(st[W], f, Vector3(su * hu, sv * hv, (front if sv < 0.0 else back) * 0.5), Vector3(0.2, 0.2, front if sv < 0.0 else back))
			var p := c + Vector2(su * hu, sv * hv).rotated(ang)
			circles.append([p.x, p.y, 0.22])
	# la toile du toit, en bandes de deux couleurs ; elle déborde devant
	var stripes := maxi(int(w / 0.9), 4)
	for k in stripes:
		var u0 := -hu - 0.3 + (w + 0.6) * float(k) / stripes
		var u1 := -hu - 0.3 + (w + 0.6) * float(k + 1) / stripes
		var over := 0.9
		var slope := (front - back) / d
		TownGreybox._raw_quad(st[P] if k % 2 == 0 else st[T], TownHouse._p(f, Vector3(u0, -hv - over, front + slope * over)), TownHouse._p(f, Vector3(u1, -hv - over, front + slope * over)),
				TownHouse._p(f, Vector3(u1, hv + 0.2, back - slope * 0.2)), TownHouse._p(f, Vector3(u0, hv + 0.2, back - slope * 0.2)), Vector3.ZERO)
		# le lambrequin qui pend devant
		TownGreybox._raw_quad(st[P] if k % 2 == 0 else st[T], TownHouse._p(f, Vector3(u0, -hv - over, front + slope * over)), TownHouse._p(f, Vector3(u1, -hv - over, front + slope * over)),
				TownHouse._p(f, Vector3(u1, -hv - over, front + slope * over - 0.4)), TownHouse._p(f, Vector3(u0, -hv - over, front + slope * over - 0.4)), TownHouse._dir(f, Vector3(0, -1, 0)))
	# fond de toile, demi-côtés
	TownHouse._box(st[T], f, Vector3(0, hv, back * 0.5), Vector3(w, 0.06, back))
	for su2: float in [-1.0, 1.0]:
		TownHouse._box(st[T], f, Vector3(su2 * hu, hv * 0.4, back * 0.5), Vector3(0.06, d * 0.6, back))
	# comptoir au fond, étagère, caisses et tonneau sur les côtés
	var cv := hv * 0.3
	TownHouse._box(st[W], f, Vector3(0, cv, 0.5), Vector3(w * 0.62, 0.7, 1.0))
	TownHouse._box(st[S], f, Vector3(0, cv, 1.03), Vector3(w * 0.66, 0.8, 0.07))
	TownHouse._box(st[W], f, Vector3(0, hv - 0.3, 1.5), Vector3(w * 0.7, 0.4, 0.08))
	TownHouse._box(st[W], f, Vector3(0, hv - 0.3, 2.0), Vector3(w * 0.7, 0.4, 0.08))
	for k in maxi(int(w * 0.6 / 0.6), 2):
		var u2 := -w * 0.3 + w * 0.6 * (float(k) + 0.5) / maxi(int(w * 0.6 / 0.6), 2)
		TownHouse._box(st[R], f, Vector3(u2, hv - 0.3, 1.7 if k % 2 == 0 else 2.2), Vector3(0.32, 0.3, 0.32))
	for t: float in [-0.28, 0.0, 0.28]:
		var cp := c + Vector2(w * t, cv).rotated(ang)
		circles.append([cp.x, cp.y, 0.5])
	for su3: float in [-1.0, 1.0]:
		TownHouse._box(st[W], f, Vector3(su3 * (hu - 0.7), -hv * 0.3, 0.4), Vector3(0.8, 0.8, 0.8))
		var bp := c + Vector2(su3 * (hu - 0.7), -hv * 0.3).rotated(ang)
		circles.append([bp.x, bp.y, 0.55])
	# la lanterne, pendue à l'entrée
	TownHouse._box(st[W], f, Vector3(0, -hv, front - 0.25), Vector3(0.04, 0.04, 0.5))
	TownHouse._box(st[G], f, Vector3(0, -hv, front - 0.6), Vector3(0.3, 0.3, 0.36))
	(extras["lamps"] as Array).append(TownHouse._p(f, Vector3(0, -hv, front - 0.9)))
	var canvas: Color = [Color("b23a30"), Color("3a5f7a"), Color("2d6444")][int(b.get("num", 0)) % 3]
	return _finish(root, st, str(b["id"]), [canvas, Color("dcae5c"), WOOD, Color("9c6a43"), CREAM, GLASS], [4, 4, 2, 2, 4, 4], true)


## Le tableau des quêtes : un panneau de bois sous un petit toit, couvert d'avis.
static func quest_board(root: Node3D, b: Dictionary, base: float, circles: Array) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := maxf(float(b["w"]), 2.6)
	for su: float in [-1.0, 1.0]:
		TownHouse._box(st[W], f, Vector3(su * w * 0.5, 0, 1.4), Vector3(0.18, 0.18, 2.8))
	TownHouse._box(st[W], f, Vector3(0, 0, 1.55), Vector3(w, 0.1, 1.5))
	for k in 5:
		TownHouse._box(st[T], f, Vector3(-w * 0.36 + w * 0.18 * k, -0.07, 1.4 + 0.25 * ((k * 3) % 3 - 1)), Vector3(0.36, 0.03, 0.46))
	TownHouse._roof(st, f, w + 0.5, 0.9, 2.75, 0.45)
	var c := Vector2(float(b["x"]), float(b["y"]))
	for t: float in [-0.4, 0.0, 0.4]:
		var p := c + Vector2(w * t, 0).rotated(float(b["ang"]))
		circles.append([p.x, p.y, 0.4])
	return _finish(root, st, str(b["id"]), [CREAM, TILE, WOOD, STONE, CREAM, GLASS], [4, 1, 2, 3, 4, 4], false)


## La forge en plein air : foyer de pierre et sa hotte, enclume, bac de trempe, auvent.
static func forge(root: Node3D, b: Dictionary, base: float, circles: Array, extras: Dictionary) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	var c := Vector2(float(b["x"]), float(b["y"]))
	var ang := float(b["ang"])
	TownHouse._box(st[S], f, Vector3(0, d * 0.25, 0.55), Vector3(2.4, 1.6, 1.1))        # le foyer
	TownHouse._box(st[G], f, Vector3(0, d * 0.25 - 0.1, 1.14), Vector3(1.4, 0.9, 0.1))   # les braises
	TownHouse._box(st[S], f, Vector3(0, d * 0.25 + 0.5, 2.9), Vector3(1.4, 0.7, 3.6))    # la cheminée
	TownHouse._box(st[R], f, Vector3(-1.7, -d * 0.1, 0.4), Vector3(0.5, 0.5, 0.8))       # le billot
	TownHouse._box(st[R], f, Vector3(-1.7, -d * 0.1, 0.95), Vector3(0.9, 0.34, 0.3))     # l'enclume
	TownHouse._box(st[W], f, Vector3(1.8, -d * 0.1, 0.35), Vector3(0.9, 0.9, 0.7))       # le bac de trempe
	TownHouse._box(st[T], f, Vector3(1.8, -d * 0.1, 0.71), Vector3(0.7, 0.7, 0.04))
	for su: float in [-1.0, 1.0]:
		TownHouse._box(st[W], f, Vector3(su * (w * 0.5 - 0.2), -d * 0.5 + 0.2, 1.6), Vector3(0.2, 0.2, 3.2))
		var p := c + Vector2(su * (w * 0.5 - 0.2), -d * 0.5 + 0.2).rotated(ang)
		circles.append([p.x, p.y, 0.22])
	TownGreybox._raw_quad(st[P], TownHouse._p(f, Vector3(-w * 0.5, -d * 0.5, 3.2)), TownHouse._p(f, Vector3(w * 0.5, -d * 0.5, 3.2)),
			TownHouse._p(f, Vector3(w * 0.5, d * 0.3, 3.9)), TownHouse._p(f, Vector3(-w * 0.5, d * 0.3, 3.9)), Vector3.ZERO)
	for q: Array in [[0.0, d * 0.25, 1.3], [-1.7, -d * 0.1, 0.6], [1.8, -d * 0.1, 0.6]]:
		var cp := c + Vector2(float(q[0]), float(q[1])).rotated(ang)
		circles.append([cp.x, cp.y, float(q[2]) * 0.6])
	(extras["lamps"] as Array).append(TownHouse._p(f, Vector3(0, d * 0.25 - 0.4, 1.6)))
	return _finish(root, st, str(b["id"]), [Color("6a4532"), Color("2e2a44"), WOOD, STONE, Color("5f8fb0"), Color("ff8a3c")], [2, 4, 2, 3, 4, 4], true)


## Les cabanes de pêcheurs : trois cabanes de planches sur pilotis bas, des filets qui sèchent entre elles.
static func huts(root: Node3D, b: Dictionary, base: float) -> MeshInstance3D:
	var st := _surfaces()
	var f := _frame(b, base)
	var w := float(b["w"])
	var d := float(b["d"])
	for k in 3:
		var u := -w * 0.5 + w * (float(k) + 0.5) / 3.0
		var hw := w / 3.0 - 2.0
		TownHouse._box(st[W], f, Vector3(u, 0, 0.25), Vector3(hw + 0.3, d + 0.2, 0.5))
		TownHouse._box(st[P], f, Vector3(u, 0, 1.7), Vector3(hw, d - 0.4, 2.4))
		TownHouse._box(st[W], f, Vector3(u - hw * 0.2, -d * 0.5 + 0.17, 1.5), Vector3(0.9, 0.08, 1.9))
		TownHouse._obox(st[T], f, Vector2(u + hw * 0.25, -d * 0.5 + 0.18), Vector2(1, 0), Vector2(0, -1), 1.9, Vector3(0.8, 0.06, 0.8))
		TownHouse._obox(st[G], f, Vector2(u + hw * 0.25, -d * 0.5 + 0.15), Vector2(1, 0), Vector2(0, -1), 1.9, Vector3(0.6, 0.06, 0.6))
		var fr := {"c": (f["c"] as Vector2) + Vector2(u, 0).rotated(float(f["ang"])), "ang": float(f["ang"]), "base": float(f["base"])}
		TownHouse._roof(st, fr, hw, d - 0.4, 2.9, 1.1)
		if k < 2:   # le séchoir à filets, entre deux cabanes
			var gu := u + w / 6.0
			for su: float in [-1.0, 1.0]:
				TownHouse._box(st[W], f, Vector3(gu + su * 0.7, 0, 1.0), Vector3(0.12, 0.12, 2.0))
			TownHouse._box(st[W], f, Vector3(gu, 0, 1.95), Vector3(1.6, 0.1, 0.1))
			TownHouse._box(st[T], f, Vector3(gu, 0, 1.3), Vector3(1.3, 0.04, 1.2))
	return _finish(root, st, str(b["id"]), [Color("9c6a43"), Color("6a4532"), WOOD_DARK, STONE, Color("93c4a6"), GLASS], [2, 2, 2, 3, 4, 4], true)
