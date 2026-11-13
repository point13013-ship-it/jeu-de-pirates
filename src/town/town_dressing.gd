class_name TownDressing
extends RefCounted
## L'habillage de la ville v3 (13/11/2026, niveau 2) : ce qui fait qu'une ville n'a pas l'air d'une maquette. Arbres dans les
## jardins et les creux, palmiers près du rivage, bittes d'amarrage le long du quai, caisses et tonneaux au pied des pontons,
## bancs sur les places. Tout est tiré au sort une fois pour toutes (même graine : la même ville chez tous les joueurs) et rien
## ne se pose sur une rue, une place, une maison, une rampe ou le bord d'une terrasse. Ce qui est posé arrête le pirate.

const TRUNK := Color("6a4532")
const LEAVES: Array[Color] = [Color("2d6444"), Color("5a9440"), Color("3f7a42"), Color("7fa84e")]
const PALM := Color("5a9440")
const CRATE := Color("9c6a43")
const BARREL := Color("7a4a2e")


## Renvoie [centre, rayon] de ce qui fait une ombre de contact au sol (les arbres).
static func add(root: Node3D, acc: Dictionary, circles: Array, plan: Dictionary, land: PackedVector2Array, levels: Array) -> Array:
	var shades: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261113
	var segs: Array = []      # [a, b, demi-largeur]
	for s: Dictionary in plan.get("streets", []) + plan.get("paths", []):
		var pts := Land._poly(s["pts"])
		for i in pts.size() - 1:
			segs.append([pts[i], pts[i + 1], float(s["width"]) * 0.5])
	var solids: Array = []    # [centre, rayon]
	for b: Dictionary in plan.get("buildings", []):
		solids.append([Vector2(float(b["x"]), float(b["y"])), Vector2(float(b["w"]), float(b["d"])).length() * 0.5 + 1.0])
	for pl: Dictionary in plan.get("plazas", []):
		solids.append([Vector2(float(pl["x"]), float(pl["y"])), maxf(float(pl["rx"]), float(pl["ry"])) + 0.5])
	var ramps: Array = plan.get("ramps", [])
	var sand := Land._poly(plan.get("sand", []))
	var lo := land[0]
	var hi := land[0]
	for p: Vector2 in land:
		lo = lo.min(p)
		hi = hi.max(p)

	# arbres et palmiers
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 12
	ball.rings = 7
	var leaf_mats: Array = []
	for c: Color in LEAVES:
		leaf_mats.append(ProcKit.flat(c))
	var placed: Array[Vector2] = []
	var tries := 0
	while placed.size() < GameConfig.TOWN_TREES and tries < 6000:
		tries += 1
		var p2 := Vector2(rng.randf_range(lo.x, hi.x), rng.randf_range(lo.y, hi.y))
		var ok := true
		var h := TownGreybox._level_h(levels, p2)
		for off: Vector2 in [Vector2.ZERO, Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)]:
			if not Geometry2D.is_point_in_polygon(p2 + off, land) or TownGreybox._level_h(levels, p2 + off) != h or TownGreybox._on_ramp(ramps, p2 + off):
				ok = false
		if not ok or _busy(p2, segs, solids, 1.9):
			continue
		# 13/11 (Jimmy : « des arbres directement sur de la pierre ») : rien ne pousse sur le cap pavé de la batterie
		for lvl: Dictionary in levels:
			if str(lvl.get("id", "")) == "cap" and Geometry2D.is_point_in_polygon(p2, Land._poly(lvl["poly"])):
				ok = false
		if not ok:
			continue
		for q: Vector2 in placed:
			if q.distance_to(p2) < 3.4:
				ok = false
		if not ok:
			continue
		placed.append(p2)
		circles.append([p2.x, p2.y, 0.32])
		shades.append([p2, 2.3])
		if (sand.size() >= 3 and Geometry2D.is_point_in_polygon(p2, sand)) or p2.y < 16.0:
			# 13/11 (Jimmy : « le modèle du palmier est vraiment moche », puis le choix du lot nature de Quaternius, CC0) : quatre
			# vrais modèles de palmiers (assets/models/nature/PalmTree_1 à 4, recolorés dans la palette), tirés au sort, tournés
			# et agrandis ; le palmier des îles sert de secours si un fichier manque
			var scene := load("res://assets/models/nature/PalmTree_%d.glb" % (1 + rng.randi() % 4)) as PackedScene
			if scene != null:
				var palm := scene.instantiate() as Node3D
				palm.position = Vector3(p2.x, h, -p2.y)
				palm.rotation.y = rng.randf() * TAU
				palm.scale = Vector3.ONE * rng.randf_range(1.45, 1.9)
				root.add_child(palm)
			else:
				var spare := IslandDecor.make(root, "palm", Vector2(p2.x, -p2.y), rng.randf() * TAU, rng.randi() % 100000, {}, h)
				spare.scale = Vector3.ONE * rng.randf_range(1.25, 1.6)
		else:
			# 13/11 (choix de Jimmy) : les arbres de la ville sont ceux du lot nature de Quaternius (cinq feuillus et deux saules),
			# tirés au sort, tournés et agrandis ; l'arbre fabriqué sert de secours
			var tk := rng.randi() % 7
			var tscene := load("res://assets/models/nature/%s.glb" % ("CommonTree_%d" % (tk + 1) if tk < 5 else "Willow_%d" % (tk - 4))) as PackedScene
			if tscene != null:
				var tree := tscene.instantiate() as Node3D
				tree.position = Vector3(p2.x, h, -p2.y)
				tree.rotation.y = rng.randf() * TAU
				tree.scale = Vector3.ONE * rng.randf_range(1.7, 2.3)
				root.add_child(tree)
			else:
				_tree(root, acc, p2, h, rng, ball, leaf_mats)

	# bittes d'amarrage : le long du quai, tous les 7 m, à 60 cm du bord
	var quay := Vector2(INF, -INF)
	for s2: Dictionary in plan.get("streets", []):
		if str(s2["id"]) == "quai":
			for q2: Vector2 in Land._poly(s2["pts"]):
				quay = Vector2(minf(quay.x, q2.x), maxf(quay.y, q2.x))
	var run := 3.0
	for i in land.size() - 1:
		var a := land[i]
		var b2 := land[i + 1]
		if minf(a.x, b2.x) < quay.x - 1.0 or maxf(a.x, b2.x) > quay.y + 1.0 or maxf(a.y, b2.y) >= 12.0:
			continue
		var len := a.distance_to(b2)
		var inward := (b2 - a).normalized().orthogonal()
		if not Geometry2D.is_point_in_polygon((a + b2) * 0.5 + inward, land):
			inward = -inward
		while run < len:
			var at := a.lerp(b2, run / len) + inward * 0.6
			run += 7.0
			var free := true
			for l: Array in plan.get("ladders", []):
				if Vector2(float(l[0]), float(l[1])).distance_to(at) < 1.6:
					free = false
			if free:
				TownGreybox._box(acc, TownGreybox.STONE_DARK, at, Vector2(0.34, 0.34), 0.0, 0.0, 0.52)
				TownGreybox._box(acc, TownGreybox.STONE_DARK, at, Vector2(0.48, 0.48), 0.0, 0.52, 0.64)
				circles.append([at.x, at.y, 0.26])
		run -= len

	# caisses et tonneaux : un tas de chaque côté du pied de chaque ponton
	for pt: Dictionary in plan.get("pontoons", []):
		var pa := Vector2(float(pt["a"][0]), float(pt["a"][1]))
		var pb := Vector2(float(pt["b"][0]), float(pt["b"][1]))
		var back := (pa - pb).normalized()
		var side := back.orthogonal()
		for sgn: float in [-1.0, 1.0]:
			var c2 := pa + side * sgn * (float(pt["width"]) * 0.5 + 1.5) + back * 2.4
			if not Geometry2D.is_point_in_polygon(c2, land):
				continue
			var ang := rng.randf() * TAU
			if sgn < 0.0:
				TownGreybox._box(acc, CRATE, c2, Vector2(0.85, 0.85), ang, 0.0, 0.8)
				TownGreybox._box(acc, CRATE.darkened(0.12), c2 + Vector2(0.75, 0.2).rotated(ang), Vector2(0.7, 0.7), ang + 0.4, 0.0, 0.65)
				TownGreybox._box(acc, CRATE.lightened(0.08), c2 + Vector2(0.1, 0.05).rotated(ang), Vector2(0.6, 0.6), ang + 0.9, 0.8, 1.35)
				circles.append([c2.x, c2.y, 0.75])
				var c3 := c2 + Vector2(0.75, 0.2).rotated(ang)
				circles.append([c3.x, c3.y, 0.5])
			else:
				for k in 3:
					var bp := c2 + Vector2(0.55, 0.0).rotated(TAU * k / 3.0 + ang)
					var barrel := ProcKit.cyl(root, 0.36, 0.9, ProcKit.w(bp.x, bp.y, 0.45), ProcKit.flat(BARREL))
					barrel.scale = Vector3(1.0, 1.0, 1.0)
					ProcKit.cyl(root, 0.375, 0.07, ProcKit.w(bp.x, bp.y, 0.22), ProcKit.flat(TownGreybox.STONE_DARK))
					ProcKit.cyl(root, 0.375, 0.07, ProcKit.w(bp.x, bp.y, 0.68), ProcKit.flat(TownGreybox.STONE_DARK))
					circles.append([bp.x, bp.y, 0.42])

	# bancs : deux par place, tournés vers son centre
	for pl2: Dictionary in plan.get("plazas", []):
		var c4 := Vector2(float(pl2["x"]), float(pl2["y"]))
		var hb := TownGreybox._level_h(levels, c4)
		for k2 in 2:
			var a2 := 2.2 + PI * k2 + rng.randf_range(-0.3, 0.3)
			var bp2 := c4 + Vector2(cos(a2) * (float(pl2["rx"]) - 1.4), sin(a2) * (float(pl2["ry"]) - 1.4))
			# 13/11 (Jimmy : « un banc bloque le tableau d'information ») : pas de banc devant un étal, une tente ou un comptoir
			for turn in 6:
				var clear := true
				for bd: Dictionary in plan.get("buildings", []):
					if str(bd.get("mode", "")) in ["tente", "comptoir", "halle"] \
							and bp2.distance_to(Vector2(float(bd["x"]), float(bd["y"]))) < maxf(float(bd["w"]), float(bd["d"])) * 0.5 + 3.5:
						clear = false
				if clear:
					break
				a2 += PI / 3.0
				bp2 = c4 + Vector2(cos(a2) * (float(pl2["rx"]) - 1.4), sin(a2) * (float(pl2["ry"]) - 1.4))
			TownGreybox._box(acc, CRATE, bp2, Vector2(1.7, 0.5), a2 + PI * 0.5, hb + 0.38, hb + 0.48)
			TownGreybox._box(acc, CRATE, bp2 + Vector2(cos(a2), sin(a2)) * 0.26, Vector2(1.7, 0.08), a2 + PI * 0.5, hb + 0.48, hb + 0.95)
			for e: float in [-0.7, 0.7]:
				TownGreybox._box(acc, TownGreybox.WOOD_DARK, bp2 + Vector2(e, 0.0).rotated(a2 + PI * 0.5), Vector2(0.1, 0.45), a2 + PI * 0.5, hb, hb + 0.38)
			for e2: float in [-0.5, 0.5]:
				var cp := bp2 + Vector2(e2, 0.0).rotated(a2 + PI * 0.5)
				circles.append([cp.x, cp.y, 0.45])
	return shades


## Vrai si `p` est sur une rue (à `margin` m près), une place ou une maison.
static func _busy(p: Vector2, segs: Array, solids: Array, margin: float) -> bool:
	for s: Array in segs:
		if Geometry2D.get_closest_point_to_segment(p, s[0], s[1]).distance_to(p) < float(s[2]) + margin:
			return true
	for o: Array in solids:
		if (o[0] as Vector2).distance_to(p) < float(o[1]) + margin:
			return true
	return false


## Un arbre feuillu : un tronc, trois boules de feuillage de tailles et de verts différents.
static func _tree(root: Node3D, acc: Dictionary, p: Vector2, h: float, rng: RandomNumberGenerator, ball: Mesh, mats: Array) -> void:
	# 13/11 (Jimmy : « les arbres sont trop basiques ») : trois essences. Chacune a un tronc en deux tronçons qui s'affine, des
	# branches, et un feuillage fait de plusieurs masses de deux tons (le dessous plus sombre, le dessus plus clair).
	var kind := rng.randi() % 5   # 0-2 : feuillu rond, 3 : arbre haut et étroit, 4 : arbre en fleurs
	var th := rng.randf_range(1.6, 2.6) * (1.35 if kind == 3 else 1.0)
	var turn := rng.randf() * TAU
	TownGreybox._box(acc, TRUNK, p, Vector2(0.42, 0.42), turn, h, h + th * 0.55)
	TownGreybox._box(acc, TRUNK.lightened(0.08), p, Vector2(0.3, 0.3), turn + 0.6, h + th * 0.55, h + th + 0.5)
	for b in 3:   # les branches maîtresses
		var bd := Vector2.from_angle(turn + TAU * b / 3.0) * 0.45
		TownGreybox._box(acc, TRUNK.lightened(0.05), p + bd, Vector2(0.75, 0.14), bd.angle(), h + th * 0.8, h + th * 0.8 + 0.16)
	var size := rng.randf_range(1.3, 2.0)
	var dark: Material = mats[0]
	var blobs: Array = []   # [décalage (x, z), hauteur, rayon, écrasement, matière]
	if kind == 3:
		for k in 4:
			blobs.append([Vector2.ZERO, th + 0.4 + k * size * 0.62, size * (0.85 - 0.17 * k), 1.25, mats[(k + 1) % mats.size()]])
	else:
		blobs.append([Vector2.ZERO, th + size * 0.5, size, 0.8, dark])
		for k in 5:
			var a := turn + TAU * k / 5.0 + rng.randf_range(-0.3, 0.3)
			blobs.append([Vector2.from_angle(a) * size * rng.randf_range(0.5, 0.75), th + size * rng.randf_range(0.45, 0.95),
					size * rng.randf_range(0.5, 0.68), 0.85, mats[1 + rng.randi() % (mats.size() - 1)]])
		blobs.append([Vector2(rng.randf_range(-0.3, 0.3), rng.randf_range(-0.3, 0.3)), th + size * 1.15, size * 0.62, 0.8, mats[mats.size() - 1]])
	for bl: Array in blobs:
		var mi := MeshInstance3D.new()
		mi.mesh = ball
		mi.material_override = bl[4]
		var r := float(bl[2])
		mi.scale = Vector3(r, r * float(bl[3]), r)
		var off: Vector2 = bl[0]
		mi.position = Vector3(p.x + off.x, h + float(bl[1]), -(p.y + off.y))
		root.add_child(mi)
	if kind == 4:   # des fleurs : de petites touches claires posées sur le feuillage
		var bloom := ProcKit.flat([Color("ffd9e6"), Color("ffb35c"), Color("efe4cc")][rng.randi() % 3])
		for k2 in 14:
			var a2 := rng.randf() * TAU
			var up := rng.randf_range(0.25, 1.0)
			var fl := MeshInstance3D.new()
			fl.mesh = ball
			fl.material_override = bloom
			fl.scale = Vector3.ONE * rng.randf_range(0.12, 0.2)
			fl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var rad := size * sqrt(maxf(1.0 - up * up * 0.6, 0.05)) * rng.randf_range(0.85, 1.05)
			fl.position = Vector3(p.x + cos(a2) * rad, h + th + size * (0.45 + up * 0.75), -(p.y + sin(a2) * rad))
			root.add_child(fl)


## Un palmier : un tronc qui penche, en trois tronçons, et six palmes qui retombent.
static func _palm(acc: Dictionary, p: Vector2, h: float, rng: RandomNumberGenerator) -> void:
	# 13/11 (retour : « les palmiers sont mal faits », le tronc était en trois morceaux qui ne se touchaient pas) : un tronc
	# d'un seul tenant, en sept anneaux qui se recouvrent et s'incurvent, huit palmes en trois pans qui retombent, des noix.
	var lean := Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.5, 1.1)
	var th := rng.randf_range(3.4, 4.8)
	var turn := rng.randf() * TAU
	for k in 7:
		var t0 := float(k) / 7.0
		var w := 0.36 - 0.022 * k
		TownGreybox._box(acc, TRUNK.lightened(0.12 if k % 2 == 0 else 0.02), p + lean * t0 * t0, Vector2(w, w), turn + 0.5 * k,
				h + th * t0 - 0.03, h + th * (t0 + 1.0 / 7.0) + 0.05)
	var top := p + lean * (36.0 / 49.0)
	var y := h + th
	for n in 3:   # les noix, sous la couronne
		var nd := Vector2.from_angle(turn + TAU * n / 3.0) * 0.22
		TownGreybox._box(acc, TRUNK.darkened(0.25), top + nd, Vector2(0.2, 0.2), turn, y - 0.28, y - 0.08)
	var start := rng.randf() * TAU
	for k2 in 8:
		var dir := Vector2.from_angle(start + TAU * k2 / 8.0 + rng.randf_range(-0.12, 0.12))
		var side := dir.orthogonal() * 0.46
		var reach := rng.randf_range(2.3, 3.0)
		var a := top + dir * reach * 0.36
		var b := top + dir * reach * 0.72
		var tip := top + dir * reach
		var col := PALM if k2 % 2 == 0 else PALM.darkened(0.16)
		var lift := 0.3 if k2 % 2 == 0 else 0.5
		TownGreybox._quad(acc, col, TownGreybox._w(top - side * 0.3, y), TownGreybox._w(top + side * 0.3, y),
				TownGreybox._w(a + side, y + lift), TownGreybox._w(a - side, y + lift), Vector3.UP)
		TownGreybox._quad(acc, col.lightened(0.06), TownGreybox._w(a - side, y + lift), TownGreybox._w(a + side, y + lift),
				TownGreybox._w(b + side * 0.7, y + lift - 0.35), TownGreybox._w(b - side * 0.7, y + lift - 0.35), Vector3.UP)
		TownGreybox._quad(acc, col.darkened(0.08), TownGreybox._w(b - side * 0.7, y + lift - 0.35), TownGreybox._w(b + side * 0.7, y + lift - 0.35),
				TownGreybox._w(tip + side * 0.1, y + lift - 1.25), TownGreybox._w(tip - side * 0.1, y + lift - 1.25), Vector3.UP)
