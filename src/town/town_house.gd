class_name TownHouse
extends RefCounted
## Une maison de la ville v3, fabriquée sur mesure à partir de son emprise dans data/town_plan.json (13/11/2026, étape 5 de
## design/ville-v3/conception.md : « kit de bâtiments »). Chaque maison a sa largeur, sa profondeur, son angle et ses étages :
## plutôt qu'un jeu de modèles figés, le kit est une recette. Soubassement de pierre, murs enduits aux couleurs du port
## caribéen (palette v1), bandeau entre les étages, porte, fenêtres à volets, toit de tuiles à débord, cheminée.
## Les surfaces portent les matières peintes de shaders/surface.gdshader (kind : 0 enduit, 1 tuiles, 2 bois, 3 pierre, 4 uni).
## La dernière surface est celle des vitres : le jeu l'allume la nuit.
## Repère local d'une maison : u = le long de la façade (est), v = vers le fond (nord), la façade principale est au sud.

const FACADES: Array[Color] = [Color("d68a6e"), Color("dcae5c"), Color("5f8fb0"), Color("93c4a6"), Color("d9a0a8"), Color("efe4cc"), Color("e8c9a0")]
const ROOFS: Array[Color] = [Color("b25a3e"), Color("9a4a3a"), Color("c8744e"), Color("7a3530")]
const SHUTTERS: Array[Color] = [Color("3a5f7a"), Color("6a4532"), Color("2d6444"), Color("7a3530"), Color("efe4cc")]
const STONE := Color("7d7488")
const TRIM := Color("efe4cc")
const WOOD_DARK := Color("3a2630")
const GLASS := Color("ffe2a0")
const STOREY := 2.7
const PLINTH := 0.45

enum { S_PLASTER, S_ROOF, S_WOOD, S_STONE, S_TRIM, S_GLASS }
const KINDS := [0, 1, 2, 3, 4, 4]


## Construit la maison `b` (entrée « buildings » du plan), posée à la hauteur `base`. `seed` fixe ses couleurs et ses détails.
static func build(root: Node3D, b: Dictionary, base: float, seed: int) -> MeshInstance3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var c := Vector2(float(b["x"]), float(b["y"]))
	var ang := float(b["ang"])
	var w := float(b["w"])
	var d := float(b["d"])
	var storeys := int(b.get("storeys", 1))
	var service := str(b.get("kind", "")) == "service"
	var top := PLINTH + STOREY * storeys
	var st: Array[SurfaceTool] = []
	for k in KINDS.size():
		var s := SurfaceTool.new()
		s.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.append(s)
	var f := {"c": c, "ang": ang, "base": base}
	var facade: Color = FACADES[rng.randi() % FACADES.size()]
	var roof: Color = ROOFS[rng.randi() % ROOFS.size()]
	var shutter: Color = SHUTTERS[rng.randi() % SHUTTERS.size()]

	# soubassement, murs, bandeaux d'étage, chaînes d'angle
	_box(st[S_STONE], f, Vector3(0, 0, PLINTH * 0.5), Vector3(w + 0.16, d + 0.16, PLINTH))
	_box(st[S_PLASTER], f, Vector3(0, 0, (PLINTH + top) * 0.5), Vector3(w, d, top - PLINTH))
	for k in range(1, storeys):
		_box(st[S_TRIM], f, Vector3(0, 0, PLINTH + STOREY * k), Vector3(w + 0.1, d + 0.1, 0.14))
	_box(st[S_TRIM], f, Vector3(0, 0, top - 0.09), Vector3(w + 0.14, d + 0.14, 0.18))   # corniche sous le toit
	for su: float in [-1.0, 1.0]:
		_box(st[S_TRIM], f, Vector3(su * (w * 0.5 - 0.14), -d * 0.5 - 0.02, (PLINTH + top) * 0.5), Vector3(0.3, 0.06, top - PLINTH))

	# façade sud : la porte, puis les fenêtres de chaque étage
	var slots := maxi(int((w - 1.0) / 2.1), 1)
	var door_slot := rng.randi() % slots
	var lamp_at := Vector3.INF
	var fixed_door := b.has("door_u")   # (un service où l'on entre : la porte est là où l'intérieur l'attend)
	if fixed_door:
		door_slot = -1
		_door(st, f, float(b["door_u"]), -d * 0.5, service, not bool(b.get("terrace", false)))
		# une lanterne à gauche de la porte, sur sa potence de fer
		var lu := float(b["door_u"]) - 1.45
		_box(st[S_STONE], f, Vector3(lu, -d * 0.5 - 0.22, PLINTH + 2.62), Vector3(0.06, 0.44, 0.06))
		_box(st[S_TRIM], f, Vector3(lu, -d * 0.5 - 0.4, PLINTH + 2.36), Vector3(0.24, 0.24, 0.34))
		_box(st[S_STONE], f, Vector3(lu, -d * 0.5 - 0.4, PLINTH + 2.56), Vector3(0.3, 0.3, 0.06))
		lamp_at = _p(f, Vector3(lu, -d * 0.5 - 0.75, PLINTH + 2.2))
	for k in slots:
		var u := -w * 0.5 + w * (float(k) + 0.5) / slots
		for s2 in storeys:
			var z0 := PLINTH + STOREY * s2
			if s2 == 0 and k == door_slot:
				_door(st, f, u, -d * 0.5, service, true)
			elif s2 == 0 and fixed_door and absf(u - float(b["door_u"])) < 1.7:
				continue
			else:
				_window(st, f, Vector2(u, -d * 0.5), Vector2(0, -1), z0 + 1.0, rng.randf() < 0.85)
	# côtés est et ouest, fond : moins de fenêtres, sans volets au fond
	var side_slots := maxi(int((d - 1.2) / 2.6), 1)
	for su2: float in [-1.0, 1.0]:
		for k in side_slots:
			var v := -d * 0.5 + d * (float(k) + 0.5) / side_slots
			for s3 in storeys:
				if rng.randf() < 0.7:
					_window(st, f, Vector2(su2 * w * 0.5, v), Vector2(su2, 0), PLINTH + STOREY * s3 + 1.0, rng.randf() < 0.6)
	for k in maxi(slots - 1, 1):
		if rng.randf() < 0.5:
			_window(st, f, Vector2(-w * 0.5 + w * (float(k) + 0.75) / slots, d * 0.5), Vector2(0, 1), PLINTH + STOREY * (storeys - 1) + 1.0, false)

	# balcon de bois sous les fenêtres du premier (une maison à étage sur trois)
	if storeys >= 2 and w >= 7.0 and rng.randf() < 0.4:
		var bz := PLINTH + STOREY
		_box(st[S_WOOD], f, Vector3(0, -d * 0.5 - 0.45, bz + 0.02), Vector3(w * 0.7, 0.9, 0.1))
		_box(st[S_WOOD], f, Vector3(0, -d * 0.5 - 0.86, bz + 0.95), Vector3(w * 0.7, 0.08, 0.08))
		var posts := maxi(int(w * 0.7 / 0.7), 2)
		for k in posts + 1:
			_box(st[S_WOOD], f, Vector3(-w * 0.35 + w * 0.7 * float(k) / posts, -d * 0.5 - 0.86, bz + 0.5), Vector3(0.07, 0.07, 0.9))

	# toit de tuiles à deux pans, débord, pignons enduits, cheminée
	var rise := clampf(minf(w, d) * 0.28, 1.5, 2.4)
	_roof(st, f, w, d, top, rise)
	var along_u := w >= d
	var chim := Vector3(w * 0.28, 0.0, top + rise * 0.5 + 0.55) if along_u else Vector3(0.0, d * 0.28, top + rise * 0.5 + 0.55)
	_box(st[S_STONE], f, chim, Vector3(0.62, 0.62, rise + 1.0))
	_box(st[S_TRIM], f, chim + Vector3(0, 0, rise * 0.5 + 0.55), Vector3(0.76, 0.76, 0.12))

	var mesh := ArrayMesh.new()
	for s4: SurfaceTool in st:
		s4.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "bldg_%s" % str(b.get("id", "x"))
	mi.set_meta("colors", [facade, roof, shutter, STONE, TRIM, GLASS])
	mi.set_meta("kinds", KINDS)
	mi.set_meta("glass", S_GLASS)
	if lamp_at.is_finite():
		mi.set_meta("door_lamp", lamp_at)
	mi.set_meta("see_through", b.has("interior"))   # (on entre dans ce bâtiment : ses vitres laissent voir l'intérieur)
	mi.set_meta("lit", rng.randf() < 0.7)   # (la nuit, sept maisons sur dix ont de la lumière)
	root.add_child(mi)
	return mi


## Une porte en bois avec son seuil de pierre et son linteau ; un service a une porte double et une enseigne.
static func _door(st: Array[SurfaceTool], f: Dictionary, u: float, v: float, service: bool, steps: bool = true) -> void:
	var dw := 1.7 if service else 1.15
	_box(st[S_TRIM], f, Vector3(u, v - 0.03, PLINTH + 1.15), Vector3(dw + 0.3, 0.08, 2.4))
	_box(st[S_WOOD], f, Vector3(u, v - 0.06, PLINTH + 1.08), Vector3(dw, 0.1, 2.16))
	if steps:
		_box(st[S_STONE], f, Vector3(u, v - 0.4, PLINTH * 0.5), Vector3(dw + 0.5, 0.8, PLINTH))
		_box(st[S_STONE], f, Vector3(u, v - 1.0, PLINTH * 0.25), Vector3(dw + 0.5, 0.4, PLINTH * 0.5))
	if service:   # la potence de l'enseigne
		_box(st[S_WOOD], f, Vector3(u + dw * 0.5 + 0.5, v - 0.5, PLINTH + 2.9), Vector3(0.08, 1.0, 0.08))
		_box(st[S_WOOD], f, Vector3(u + dw * 0.5 + 0.5, v - 0.85, PLINTH + 2.45), Vector3(0.06, 0.7, 0.7))


## Une fenêtre sur le mur dont la normale (dans le repère de la maison) est `n`, au point `p` du mur, l'appui à la hauteur `z`.
static func _window(st: Array[SurfaceTool], f: Dictionary, p: Vector2, n: Vector2, z: float, shutters: bool) -> void:
	var t := Vector2(-n.y, n.x)     # le long du mur
	var out := p + n * 0.02
	_obox(st[S_TRIM], f, out, t, n, z + 0.62, Vector3(1.1, 0.07, 1.44))
	_obox(st[S_GLASS], f, p + n * 0.05, t, n, z + 0.62, Vector3(0.86, 0.06, 1.2))
	_obox(st[S_TRIM], f, p + n * 0.09, t, n, z + 0.62, Vector3(0.06, 0.03, 1.2))      # le meneau
	_obox(st[S_TRIM], f, p + n * 0.09, t, n, z + 0.62, Vector3(0.86, 0.03, 0.06))     # la traverse
	_obox(st[S_STONE], f, p + n * 0.1, t, n, z - 0.08, Vector3(1.24, 0.22, 0.1))      # l'appui
	if shutters:
		for s: float in [-1.0, 1.0]:
			_obox(st[S_WOOD], f, p + n * 0.04 + t * s * 0.78, t, n, z + 0.62, Vector3(0.44, 0.06, 1.3))


## Le toit : deux pans de tuiles qui débordent, et les deux pignons en enduit.
static func _roof(st: Array[SurfaceTool], f: Dictionary, w: float, d: float, y: float, rise: float) -> void:
	var over := 0.5
	var along_u := w >= d
	var hu := w * 0.5
	var hv := d * 0.5
	var drop := rise * over / (hv if along_u else hu)   # le débord descend dans le prolongement de la pente
	if along_u:
		var e0 := _p(f, Vector3(-hu - 0.35, -hv - over, y - drop))
		var e1 := _p(f, Vector3(hu + 0.35, -hv - over, y - drop))
		var r0 := _p(f, Vector3(-hu - 0.35, 0, y + rise))
		var r1 := _p(f, Vector3(hu + 0.35, 0, y + rise))
		var n0 := _p(f, Vector3(-hu - 0.35, hv + over, y - drop))
		var n1 := _p(f, Vector3(hu + 0.35, hv + over, y - drop))
		TownGreybox._raw_quad(st[S_ROOF], e0, e1, r1, r0, Vector3.ZERO)
		TownGreybox._raw_quad(st[S_ROOF], n1, n0, r0, r1, Vector3.ZERO)
		for su: float in [-1.0, 1.0]:   # pignons
			var out := _dir(f, Vector3(su, 0, 0))
			TownGreybox._raw_quad(st[S_PLASTER], _p(f, Vector3(su * hu, -hv, y)), _p(f, Vector3(su * hu, hv, y)),
					_p(f, Vector3(su * hu, 0, y + rise)), _p(f, Vector3(su * hu, 0, y + rise)), out)
	else:
		var e0b := _p(f, Vector3(-hu - over, -hv - 0.35, y - drop))
		var e1b := _p(f, Vector3(-hu - over, hv + 0.35, y - drop))
		var r0b := _p(f, Vector3(0, -hv - 0.35, y + rise))
		var r1b := _p(f, Vector3(0, hv + 0.35, y + rise))
		var n0b := _p(f, Vector3(hu + over, -hv - 0.35, y - drop))
		var n1b := _p(f, Vector3(hu + over, hv + 0.35, y - drop))
		TownGreybox._raw_quad(st[S_ROOF], e0b, e1b, r1b, r0b, Vector3.ZERO)
		TownGreybox._raw_quad(st[S_ROOF], n1b, n0b, r0b, r1b, Vector3.ZERO)
		for sv: float in [-1.0, 1.0]:
			var out2 := _dir(f, Vector3(0, sv, 0))
			TownGreybox._raw_quad(st[S_PLASTER], _p(f, Vector3(-hu, sv * hv, y)), _p(f, Vector3(hu, sv * hv, y)),
					_p(f, Vector3(0, sv * hv, y + rise)), _p(f, Vector3(0, sv * hv, y + rise)), out2)


# ------------------------------------------------------------------ géométrie dans le repère de la maison

## Point monde d'un point local (u, v, hauteur).
static func _p(f: Dictionary, l: Vector3) -> Vector3:
	var q: Vector2 = (f["c"] as Vector2) + Vector2(l.x, l.y).rotated(float(f["ang"]))
	return Vector3(q.x, float(f["base"]) + l.z, -q.y)


## Direction monde d'une direction locale (u, v, hauteur).
static func _dir(f: Dictionary, l: Vector3) -> Vector3:
	var q := Vector2(l.x, l.y).rotated(float(f["ang"]))
	return Vector3(q.x, l.z, -q.y).normalized()


## Une boîte alignée sur la maison : centre et taille en (u, v, hauteur).
static func _box(st: SurfaceTool, f: Dictionary, c: Vector3, s: Vector3) -> void:
	_obox(st, f, Vector2(c.x, c.y), Vector2(1, 0), Vector2(0, 1), c.z, s)


## Une boîte dont la largeur suit `t` et l'épaisseur `n` (vecteurs unitaires du repère de la maison) : taille (largeur, épaisseur,
## hauteur), centrée en `p` à la hauteur `z`.
static func _obox(st: SurfaceTool, f: Dictionary, p: Vector2, t: Vector2, n: Vector2, z: float, s: Vector3) -> void:
	var ht := t * s.x * 0.5
	var hn := n * s.y * 0.5
	var z0 := z - s.z * 0.5
	var z1 := z + s.z * 0.5
	var c: Array[Vector2] = [p - ht - hn, p + ht - hn, p + ht + hn, p - ht + hn]
	var normals: Array[Vector2] = [-n, t, n, -t]
	for i in 4:
		var a := c[i]
		var b := c[(i + 1) % 4]
		TownGreybox._raw_quad(st, _p(f, Vector3(a.x, a.y, z0)), _p(f, Vector3(b.x, b.y, z0)), _p(f, Vector3(b.x, b.y, z1)), _p(f, Vector3(a.x, a.y, z1)),
				_dir(f, Vector3(normals[i].x, normals[i].y, 0)))
	TownGreybox._raw_quad(st, _p(f, Vector3(c[0].x, c[0].y, z1)), _p(f, Vector3(c[1].x, c[1].y, z1)), _p(f, Vector3(c[2].x, c[2].y, z1)), _p(f, Vector3(c[3].x, c[3].y, z1)), Vector3.UP)
