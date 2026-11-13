class_name TownGreybox
extends RefCounted
## Maquette grise de la ville v3 (13/11/2026) : la ville de data/town_plan.json en volumes simples, pour marcher dedans et juger
## les distances, les vues et ce que la caméra cache AVANT de modéliser quoi que ce soit (design/ville-v3/conception.md, étape 3).
## Aucun bel objet ici, c'est voulu. Couleurs : herbe, pavé, pierre, façades claires ; laiton = un service, blanc = un repère.
## Tout est en coordonnées du fichier du port (x, y) ; le monde de jeu est (x, -y), comme l'ancienne ville.

const GRASS := Color("5a9440")
const GROUND := Color(0.011, 0.022, 0.033)   ## repère : les surfaces qui reçoivent le sol peint (TownGround), pas une couleur
const SAND := Color("d9b077")
const PAVE := Color("b9ad9c")
const PAVE_MAIN := Color("cfc3ae")
const STONE := Color("7d7488")
const STONE_DARK := Color("4a4258")
const TERRACE := Color("7fa84e")
const WOOD := Color("9c6a43")
const WOOD_DARK := Color("3a2630")
const WALLS: Array[Color] = [Color("d8d0c2"), Color("cbbfae"), Color("e4dccd"), Color("c2b8aa")]
const ROOFS: Array[Color] = [Color("8a6a62"), Color("9a7466"), Color("7a6468")]
const SERVICE := Color("dcae5c")
const LANDMARK := Color("efe4cc")
const LADDER := Color("e8352b")
const STOREY := 2.7          ## m par étage (13/11 : 3,0 ; avec le toit, les maisons se cachaient les unes les autres)
const SEA_FLOOR := -3.2      ## bas du mur de quai


## Construit la maquette sous `parent`. Renvoie {root, buildings : [MeshInstance3D avec la méta « colors »], circles : cercles
## d'obstacle à ajouter (poteaux, comptoirs), en coordonnées du fichier}.
static func build(parent: Node3D, plan: Dictionary) -> Dictionary:
	var root := Node3D.new()
	root.name = "ville_v3_maquette"
	parent.add_child(root)
	var acc := {}          # couleur -> SurfaceTool : tout le décor fixe, une surface par couleur
	var circles: Array = []
	var buildings: Array = []
	var spills: Array = []      # façades éclairées la nuit : [pied du mur sud, largeur, angle, hauteur du sol]
	var extras := {"lamps": []}  # lumières en plus (lanternes des tentes, forge : points monde) et « beacon » : le feu du phare
	var ramps: Array = plan.get("ramps", [])
	var levels: Array = plan.get("levels", [])

	# la terre, son mur de quai, la plage
	var land := Land._poly(plan.get("land", []))
	_fill(acc, GROUND, land, 0.0)   # (un seul sol, peint par TownGround : herbe, pavés, sable ; plus de dalles empilées)
	_skirt(acc, STONE, land, 0.0, SEA_FLOOR)

	# terrasses (haute ville, cap) : entaillées par les rampes qui y montent
	for lvl: Dictionary in levels:
		var h := float(lvl["h"])
		var pieces: Array = [Land._poly(lvl["poly"])]
		for r: Dictionary in ramps:
			var cut := _ramp_quad(r, 0.15)
			var next: Array = []
			for piece: PackedVector2Array in pieces:
				next.append_array(Geometry2D.clip_polygons(piece, cut))
			pieces = next
		for piece: PackedVector2Array in pieces:
			if Geometry2D.is_polygon_clockwise(piece):
				continue   # (un trou : aucune rampe n'en fait, par sécurité)
			_fill(acc, GROUND, piece, h)
			_skirt(acc, STONE, piece, h, 0.0)

	# rampes et escaliers
	for r: Dictionary in ramps:
		var q := _ramp_quad(r, 0.0)
		var h0 := float(r["h0"])
		var h1 := float(r["h1"])
		var col := STONE_DARK if bool(r.get("stairs", false)) else PAVE_MAIN
		_quad(acc, GROUND, _w(q[0], h0 + 0.02), _w(q[1], h1 + 0.02), _w(q[2], h1 + 0.02), _w(q[3], h0 + 0.02), Vector3.UP)
		if bool(r.get("stairs", false)):   # les nez de marche d'un escalier : une arête sombre tous les 50 cm
			var steps := maxi(int(q[0].distance_to(q[1]) / 0.5), 2)
			for k in range(1, steps):
				var u := float(k) / steps
				var a5 := q[0].lerp(q[1], u)
				var b5 := q[3].lerp(q[2], u)
				var hh := lerpf(h0, h1, u) + 0.03
				var along := (q[1] - q[0]).normalized() * 0.05
				_quad(acc, col, _w(a5, hh), _w(a5 + along, hh), _w(b5 + along, hh), _w(b5, hh), Vector3.UP)
		# les deux joues, pour qu'on ne voie pas dessous
		_quad(acc, STONE, _w(q[0], h0), _w(q[1], h1), _w(q[1], 0.0), _w(q[0], 0.0), Vector3.ZERO)
		_quad(acc, STONE, _w(q[3], h0), _w(q[2], h1), _w(q[2], 0.0), _w(q[3], 0.0), Vector3.ZERO)

	# pontons et leurs pieux
	for pt: Dictionary in plan.get("pontoons", []):
		var a2 := Vector2(float(pt["a"][0]), float(pt["a"][1]))
		var b2 := Vector2(float(pt["b"][0]), float(pt["b"][1]))
		var side2 := (b2 - a2).normalized().orthogonal() * float(pt["width"]) * 0.5
		_prism(acc, WOOD, PackedVector2Array([a2 + side2, b2 + side2, b2 - side2, a2 - side2]), -0.35, 0.02)
		var len := a2.distance_to(b2)
		var posts := maxi(int(len / 5.0), 1)
		for k in posts + 1:
			var at := a2.lerp(b2, float(k) / posts)
			for sgn: float in [-1.0, 1.0]:
				_box(acc, WOOD_DARK, at + side2 * sgn * 1.05, Vector2(0.35, 0.35), 0.0, SEA_FLOOR, 0.5)

	# échelles : un montant rouge contre le quai, du fond de l'eau au-dessus du bord
	for l: Array in plan.get("ladders", []):
		_box(acc, LADDER, Vector2(float(l[0]), float(l[1])), Vector2(0.7, 0.7), 0.0, -2.2, 0.45)

	# bâtiments
	var k2 := 0
	for b3: Dictionary in plan.get("buildings", []):
		var c2 := Vector2(float(b3["x"]), float(b3["y"]))
		var size := Vector2(float(b3["w"]), float(b3["d"]))
		var ang := float(b3["ang"])
		var base := _level_h(levels, c2)
		var mode := str(b3.get("mode", "maison"))
		var storeys := int(b3.get("storeys", 1))
		k2 += 1
		match mode:
			"tente":
				buildings.append(TownLandmarks.tent(root, b3, base, circles, extras))
			"comptoir":
				if int(b3.get("num", 0)) == 2:
					buildings.append(TownLandmarks.quest_board(root, b3, base, circles))
				elif int(b3.get("num", 0)) == 9:
					buildings.append(TownLandmarks.forge(root, b3, base, circles, extras))
				else:
					_counter(acc, circles, c2, size, ang, base)
			"cabanes":
				buildings.append(TownLandmarks.huts(root, b3, base))
			"jardin":
				_box(acc, Color("93c4a6"), c2, size, ang, base, base + 0.08)
				for j in 6:
					var off := Vector2(-size.x * 0.35 + size.x * 0.14 * j, (-1.0 if j % 2 == 0 else 1.0) * size.y * 0.2).rotated(ang)
					_box(acc, STONE, c2 + off, Vector2(0.6, 0.3), ang, base, base + 0.9)
					circles.append([c2.x + off.x, c2.y + off.y, 0.4])
			"halle":
				buildings.append(TownLandmarks.hall(root, b3, base, circles))
			"maison", "interieur":
				# 13/11 (étape 5) : de vraies maisons à la place des cubes ; on entre dans celles des services « intérieur »
				var house := TownHouse.build(root, b3, base, k2)
				buildings.append(house)
				if bool(house.get_meta("lit", false)):
					spills.append([c2 + Vector2(0.0, -size.y * 0.5 - 0.1).rotated(ang), size.x * 0.8, ang, base])
			_:
				var lm := TownLandmarks.build(root, b3, base, circles, extras)
				if lm != null:
					buildings.append(lm)
				else:
					var service := str(b3.get("kind", "")) == "service"
					var wall: Color = SERVICE if service else (LANDMARK if mode == "repere" else WALLS[k2 % WALLS.size()])
					buildings.append(_house(root, c2, size, ang, base, storeys, wall, ROOFS[k2 % ROOFS.size()], b3))
		if b3.has("name") and GameConfig.TOWN_LABELS:
			var top := base + (STOREY * storeys + 2.6 if mode in ["maison", "interieur", "repere", "cabanes"] else 4.2)
			_label(root, "%d. %s" % [int(b3.get("num", 0)), str(b3["name"])], _w(c2, top + 0.8))

	for col3: Color in acc:
		var mi := MeshInstance3D.new()
		mi.mesh = (acc[col3] as SurfaceTool).commit()
		mi.material_override = TownGround.material(plan) if col3 == GROUND else _mat(col3)
		mi.name = "decor_%s" % col3.to_html(false)
		root.add_child(mi)
	# lanternes : leur pied arrête comme un poteau
	var lamps: Array = []
	for lp: Vector2 in TownLights.lamp_points(plan):
		if _on_ramp(ramps, lp):
			continue
		lamps.append([lp, _level_h(levels, lp)])
		circles.append([lp.x, lp.y, 0.2])
	return {"root": root, "buildings": buildings, "circles": circles, "lamps": lamps, "spills": spills, "extras": extras}


# ------------------------------------------------------------------ bâtiments

## Une maison : murs et toit à deux pans, deux surfaces (le jeu les rend transparentes quand elles cachent le pirate).
static func _house(root: Node3D, c: Vector2, size: Vector2, ang: float, base: float, storeys: int, wall: Color, roof: Color, b: Dictionary) -> MeshInstance3D:
	var walls := SurfaceTool.new()
	walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := STOREY * storeys
	var num := int(b.get("num", 0))
	_raw_box(walls, c, size, ang, base, base + h)
	if num == 11:      # église : le clocher, au nord
		_raw_box(walls, c + Vector2(0.0, size.y * 0.5 - 2.4).rotated(ang), Vector2(4.6, 4.6), ang, base + h, base + 17.0)
	elif num == 14:    # phare
		_raw_box(walls, c, size * 0.7, ang, base + h, base + 19.0)
	elif num == 13:    # moulin : les ailes, côté sud
		for a: float in [0.0, PI * 0.5]:
			_raw_box(walls, c + Vector2(0.0, -size.y * 0.5 - 0.3).rotated(ang), Vector2(0.5, 0.2), ang, base + 1.5, base + h + 6.0, a)
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	if num == 15:      # batterie : toit plat (parapet)
		_raw_box(top, c, size + Vector2(0.4, 0.4), ang, base + h, base + h + 0.4)
	else:
		_raw_gable(top, c, size + Vector2(0.6, 0.6), ang, base + h, 1.7 if size.x < 12.0 else 2.3)
	var mesh := ArrayMesh.new()
	walls.commit(mesh)
	top.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "bldg_%s" % str(b.get("id", "x"))
	mi.set_meta("colors", [wall, roof])
	mi.set_surface_override_material(0, _mat(wall))
	mi.set_surface_override_material(1, _mat(roof))
	root.add_child(mi)
	return mi


## Une halle (marché, chantier naval) : des poteaux, un toit, pas de murs. On passe dessous.
static func _hall(root: Node3D, circles: Array, c: Vector2, size: Vector2, ang: float, base: float, _name: String) -> MeshInstance3D:
	var posts := SurfaceTool.new()
	posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sx: float in [-1.0, 0.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var p := c + Vector2(sx * (size.x * 0.5 - 0.3), sy * (size.y * 0.5 - 0.3)).rotated(ang)
			_raw_box(posts, p, Vector2(0.4, 0.4), ang, base, base + 4.0)
			circles.append([p.x, p.y, 0.3])
	var top := SurfaceTool.new()
	top.begin(Mesh.PRIMITIVE_TRIANGLES)
	_raw_gable(top, c, size + Vector2(1.0, 1.0), ang, base + 4.0, 2.2)
	var mesh := ArrayMesh.new()
	posts.commit(mesh)
	top.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "bldg_halle"
	mi.set_meta("colors", [WOOD_DARK, SERVICE])
	mi.set_surface_override_material(0, _mat(WOOD_DARK))
	mi.set_surface_override_material(1, _mat(SERVICE))
	root.add_child(mi)
	return mi


## Une grande tente ouverte sur la rue (côté sud) : quatre poteaux, une toile en pente vers le fond, un comptoir au fond.
## On voit dedans sans entrer.
static func _tent(acc: Dictionary, circles: Array, c: Vector2, size: Vector2, ang: float, base: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var front := 3.4
	var back := 2.2
	for sx: float in [-1.0, 1.0]:
		for sy: float in [-1.0, 1.0]:
			var p := c + Vector2(sx * hx, sy * hy).rotated(ang)
			_box(acc, WOOD_DARK, p, Vector2(0.22, 0.22), ang, base, base + (front if sy < 0.0 else back))
			circles.append([p.x, p.y, 0.22])
	var q: Array[Vector2] = []
	for v: Vector2 in [Vector2(-hx - 0.3, -hy - 0.5), Vector2(hx + 0.3, -hy - 0.5), Vector2(hx + 0.3, hy + 0.3), Vector2(-hx - 0.3, hy + 0.3)]:
		q.append(c + v.rotated(ang))
	_quad(acc, SERVICE, _w(q[0], base + front), _w(q[1], base + front), _w(q[2], base + back), _w(q[3], base + back), Vector3.UP)
	# le fond de toile et le comptoir
	_quad(acc, SERVICE.darkened(0.2), _w(q[3], base), _w(q[2], base), _w(q[2], base + back), _w(q[3], base + back), Vector3.ZERO)
	var counter := c + Vector2(0.0, hy * 0.35).rotated(ang)
	_box(acc, WOOD, counter, Vector2(size.x * 0.6, 0.7), ang, base, base + 1.0)
	for t: float in [-0.25, 0.0, 0.25]:
		var cp := counter + Vector2(size.x * t, 0.0).rotated(ang)
		circles.append([cp.x, cp.y, 0.5])


## Un comptoir ou un panneau sur la rue (tableau des quêtes, forge en plein air).
static func _counter(acc: Dictionary, circles: Array, c: Vector2, size: Vector2, ang: float, base: float) -> void:
	_box(acc, WOOD, c, Vector2(size.x, minf(size.y, 0.9)), ang, base, base + 1.1)
	_box(acc, SERVICE, c + Vector2(0.0, size.y * 0.25).rotated(ang), Vector2(size.x, 0.15), ang, base + 1.1, base + 2.6)
	var n := maxi(int(size.x / 0.9), 1)
	for k in n + 1:
		var p := c + Vector2(-size.x * 0.5 + size.x * float(k) / n, 0.0).rotated(ang)
		circles.append([p.x, p.y, 0.5])


static func _label(root: Node3D, text: String, at: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40
	l.pixel_size = 0.012
	l.modulate = Color(1.0, 0.95, 0.8)
	l.outline_size = 8
	l.outline_modulate = Color(0.11, 0.09, 0.15)
	l.no_depth_test = true
	l.render_priority = 5
	l.position = at
	root.add_child(l)


# ------------------------------------------------------------------ géométrie

static func _w(p: Vector2, h: float) -> Vector3:
	return Vector3(p.x, h, -p.y)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := ProcKit.flat(c)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _st(acc: Dictionary, c: Color) -> SurfaceTool:
	if not acc.has(c):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		acc[c] = st
	return acc[c]


## Un quadrilatère a, b, c, d ; `n` : la normale voulue (ZERO : calculée, pour une paroi).
static func _raw_quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	var g := (c - a).cross(b - a)   # la normale de la face avant pour l'ordre a, b, c (Godot : sens horaire vu de face)
	var nn := n
	if nn == Vector3.ZERO:
		nn = g.normalized() if g.length() > 0.000001 else Vector3.UP
		if nn.y < -0.001:
			nn = -nn   # (un pan de toit regarde toujours vers le haut)
	var order: Array[Vector3] = [a, b, c, a, c, d]
	if g.dot(nn) < 0.0:
		order = [a, d, c, a, c, b]
	for v: Vector3 in order:
		st.set_normal(nn)
		st.add_vertex(v)


static func _quad(acc: Dictionary, col: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_raw_quad(_st(acc, col), a, b, c, d, n)


## Une boîte tournée de `ang` autour de la verticale (`roll` : tournée aussi dans son plan de façade, pour les ailes du moulin).
static func _raw_box(st: SurfaceTool, c: Vector2, size: Vector2, ang: float, y0: float, y1: float, roll: float = 0.0) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var corners: Array[Vector2] = []
	for v: Vector2 in [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]:
		corners.append(c + v.rotated(ang))
	if roll != 0.0:   # une pale : on échange largeur et hauteur
		var mid := (y0 + y1) * 0.5
		var half := (y1 - y0) * 0.5
		corners.clear()
		for v: Vector2 in [Vector2(-half, -hy), Vector2(half, -hy), Vector2(half, hy), Vector2(-half, hy)]:
			corners.append(c + v.rotated(ang))
		y0 = mid - hx
		y1 = mid + hx
	for i in 4:
		var a := corners[i]
		var b := corners[(i + 1) % 4]
		var out := Vector2(b.y - a.y, -(b.x - a.x)).normalized()
		_raw_quad(st, _w(a, y0), _w(b, y0), _w(b, y1), _w(a, y1), Vector3(out.x, 0.0, -out.y))
	_raw_quad(st, _w(corners[0], y1), _w(corners[1], y1), _w(corners[2], y1), _w(corners[3], y1), Vector3.UP)


static func _box(acc: Dictionary, col: Color, c: Vector2, size: Vector2, ang: float, y0: float, y1: float) -> void:
	_raw_box(_st(acc, col), c, size, ang, y0, y1)


## Un toit à deux pans, faîtage dans le sens de la longueur.
static func _raw_gable(st: SurfaceTool, c: Vector2, size: Vector2, ang: float, y: float, rise: float) -> void:
	var hx := size.x * 0.5
	var hy := size.y * 0.5
	var along_x := size.x >= size.y
	var p: Array[Vector2] = []
	for v: Vector2 in [Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)]:
		p.append(c + v.rotated(ang))
	var r0: Vector2
	var r1: Vector2
	if along_x:
		r0 = c + Vector2(-hx, 0.0).rotated(ang)
		r1 = c + Vector2(hx, 0.0).rotated(ang)
		_raw_quad(st, _w(p[0], y), _w(p[1], y), _w(r1, y + rise), _w(r0, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[2], y), _w(p[3], y), _w(r0, y + rise), _w(r1, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[1], y), _w(p[2], y), _w(r1, y + rise), _w(r1, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[3], y), _w(p[0], y), _w(r0, y + rise), _w(r0, y + rise), Vector3.ZERO)
	else:
		r0 = c + Vector2(0.0, -hy).rotated(ang)
		r1 = c + Vector2(0.0, hy).rotated(ang)
		_raw_quad(st, _w(p[1], y), _w(p[2], y), _w(r1, y + rise), _w(r0, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[3], y), _w(p[0], y), _w(r0, y + rise), _w(r1, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[0], y), _w(p[1], y), _w(r0, y + rise), _w(r0, y + rise), Vector3.ZERO)
		_raw_quad(st, _w(p[2], y), _w(p[3], y), _w(r1, y + rise), _w(r1, y + rise), Vector3.ZERO)


## Le dessus d'un polygone, à la hauteur y.
static func _fill(acc: Dictionary, col: Color, poly: PackedVector2Array, y: float) -> void:
	var idx := Geometry2D.triangulate_polygon(poly)
	var st := _st(acc, col)
	for k in range(0, idx.size(), 3):
		_raw_tri_up(st, _w(poly[idx[k]], y), _w(poly[idx[k + 1]], y), _w(poly[idx[k + 2]], y))


## Un triangle à plat, face vers le haut quel que soit l'ordre de ses sommets.
static func _raw_tri_up(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var order: Array[Vector3] = [a, b, c]
	if (c - a).cross(b - a).y < 0.0:
		order = [a, c, b]
	for v: Vector3 in order:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


## Les parois d'un polygone, de y1 (haut) à y0 (bas).
static func _skirt(acc: Dictionary, col: Color, poly: PackedVector2Array, y1: float, y0: float) -> void:
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var out := Vector2(b.y - a.y, -(b.x - a.x)).normalized()
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + out * 0.05, poly):
			out = -out   # (vers l'extérieur du polygone)
		_quad(acc, col, _w(a, y0), _w(b, y0), _w(b, y1), _w(a, y1), Vector3(out.x, 0.0, -out.y))


static func _prism(acc: Dictionary, col: Color, poly: PackedVector2Array, y0: float, y1: float) -> void:
	_fill(acc, col, poly, y1)
	_skirt(acc, col.darkened(0.25), poly, y1, y0)


static func _disc(acc: Dictionary, col: Color, c: Vector2, rx: float, ry: float, y: float) -> void:
	var st := _st(acc, col)
	var n := 20
	for k in n:
		var a0 := TAU * k / n
		var a1 := TAU * (k + 1) / n
		_raw_tri_up(st, _w(c, y), _w(c + Vector2(cos(a0) * rx, sin(a0) * ry), y), _w(c + Vector2(cos(a1) * rx, sin(a1) * ry), y))


## L'emprise d'une rampe : a côté gauche, b côté gauche, b côté droit, a côté droit (élargie de `grow`).
static func _ramp_quad(r: Dictionary, grow: float) -> PackedVector2Array:
	var a := Vector2(float(r["a"][0]), float(r["a"][1]))
	var b := Vector2(float(r["b"][0]), float(r["b"][1]))
	var side := (b - a).normalized().orthogonal() * (float(r["width"]) * 0.5 + grow)
	return PackedVector2Array([a + side, b + side, b - side, a - side])


static func _on_ramp(ramps: Array, m: Vector2) -> bool:
	for r: Dictionary in ramps:
		if Geometry2D.is_point_in_polygon(m, _ramp_quad(r, 0.0)):
			return true
	return false


## Hauteur du sol au point m : celle de la terrasse qui le contient, sinon 0.
static func _level_h(levels: Array, m: Vector2) -> float:
	for lvl: Dictionary in levels:
		if Geometry2D.is_point_in_polygon(m, Land._poly(lvl["poly"])):
			return float(lvl["h"])
	return 0.0
